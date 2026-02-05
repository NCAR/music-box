import musica
from musica.micm.solver_result import SolverState
from .conditions_manager import ConditionsManager
from .model_options import BoxModelOptions
import json
import os
import atexit
import pandas as pd
import numpy as np
import musica.mechanism_configuration as mc

from tqdm import tqdm

import logging
import tempfile
logger = logging.getLogger(__name__)


class MusicBox:
    """
    Represents a box model with attributes such as box model options, conditions,
    solver, and state.

    Attributes:
        box_model_options (BoxModelOptions): Options for the box model simulation.
        solver: The solver used for the box model simulation.
        state: The current state of the box model simulation.
    """

    def __init__(self, box_model_options=None):
        """
        Initializes a new instance of the MusicBox class.

        Args:
            box_model_options (BoxModelOptions): Options for the box model simulation.
        """
        self.box_model_options = box_model_options if box_model_options is not None else BoxModelOptions()
        self._conditions_manager = ConditionsManager()
        self.solver = None
        self.state = None
        self.__mechanism = None

    # -------------------------------------------------------------------------
    # New Conditions API
    # -------------------------------------------------------------------------

    def set_condition(
        self,
        time: float,
        *,
        temperature: float = None,
        pressure: float = None,
        concentrations: dict = None,
        rate_parameters: dict = None
    ) -> 'MusicBox':
        """
        Set conditions at a specific time. Returns self for chaining.

        Args:
            time: The time point in seconds.
            temperature: Temperature in Kelvin (optional).
            pressure: Pressure in Pascals (optional).
            concentrations: Dictionary of species name to concentration in mol m-3.
            rate_parameters: Dictionary of rate parameter names to values.
                             Keys should be in format: PREFIX.name.unit

        Returns:
            self for method chaining.

        Example:
            box.set_condition(time=0, temperature=300, pressure=101325)
            box.set_condition(time=0, concentrations={"A": 1.0, "B": 0.0})
            box.set_condition(time=3600, temperature=310)
        """
        self._conditions_manager.set_condition(
            time=time,
            temperature=temperature,
            pressure=pressure,
            concentrations=concentrations,
            rate_parameters=rate_parameters
        )
        return self

    def set_conditions(self, df: pd.DataFrame) -> 'MusicBox':
        """
        Replace all conditions from DataFrame. Must have 'time.s' column.

        Args:
            df: DataFrame with conditions. Must have 'time.s' column.
                Column naming convention:
                - time.s: Time in seconds
                - ENV.temperature.K: Temperature in Kelvin
                - ENV.pressure.Pa: Pressure in Pascals
                - CONC.<species>.mol m-3: Species concentration
                - EMIS.<species>.mol m-3 s-1: Emission rate
                - PHOTO.<reaction>.s-1: Photolysis rate
                - LOSS.<species>.s-1: Loss rate
                - USER.<param>.<unit>: User-defined parameter

        Returns:
            self for method chaining.

        Example:
            df = pd.DataFrame({
                "time.s": [0, 3600],
                "ENV.temperature.K": [300, 310],
                "CONC.A.mol m-3": [1.0, None]
            })
            box.set_conditions(df)
        """
        self._conditions_manager.set_from_dataframe(df)
        return self

    def add_conditions(self, df: pd.DataFrame) -> 'MusicBox':
        """
        Merge DataFrame with existing conditions.

        Args:
            df: DataFrame with conditions to merge. Must have 'time.s' column.

        Returns:
            self for method chaining.
        """
        self._conditions_manager.add_from_dataframe(df)
        return self

    @property
    def conditions(self) -> pd.DataFrame:
        """
        Returns fully interpolated DataFrame at all simulation timesteps.

        Returns:
            DataFrame with interpolated conditions using step interpolation.

        Raises:
            ValueError: If simulation options are not set.
        """
        if self.box_model_options.simulation_length is None:
            raise ValueError("Simulation length must be set to access interpolated conditions")
        if self.box_model_options.output_step_time is None:
            raise ValueError("Output step time must be set to access interpolated conditions")

        return self._conditions_manager.get_interpolated(
            self.box_model_options.simulation_length,
            self.box_model_options.output_step_time
        )

    @property
    def conditions_raw(self) -> pd.DataFrame:
        """
        Returns the raw (sparse) conditions DataFrame with only user-specified times.
        Contains ENV.*, PHOTO.*, EMIS.*, etc. but NOT concentrations.

        Returns:
            DataFrame with raw conditions (no interpolation).
        """
        return self._conditions_manager.raw

    @property
    def concentration_events(self) -> dict:
        """
        Returns concentration events - species concentrations set at specific times.

        Concentrations are only applied at exact times specified, not interpolated.
        They represent "reset" points where chemistry is overridden.

        Returns:
            Dictionary mapping time -> {species: concentration}
            Example: {0.0: {"A": 1.0, "B": 0.5}, 300.0: {"D": 1.0}}
        """
        return self._conditions_manager.concentration_events

    def get_condition_template(self) -> pd.DataFrame:
        """
        Returns DataFrame with all possible columns from mechanism (all NaN).

        Returns:
            DataFrame template with time.s and all mechanism columns.
        """
        return self._conditions_manager.get_template()

    def solve(self) -> pd.DataFrame:
        """
        Solve the box model simulation.

        Returns:
            pd.DataFrame: Results with columns time.s, ENV.temperature.K,
            ENV.pressure.Pa, ENV.air number density.mol m-3, and
            CONC.<species>.mol m-3 for each species.
        """
        if self.solver is None:
            raise Exception(f"Error: MusicBox object {self} has no solver.")
        if self.state is None:
            raise Exception(f"Error: MusicBox object {self} has no state.")
        if not self._conditions_manager.has_conditions():
            raise Exception(f"Error: MusicBox object {self} has no conditions.")
        if self.box_model_options is None:
            raise Exception(f"Error: MusicBox object {self} has no time step parameters.")
        if self.box_model_options.simulation_length is None:
            raise Exception(f"Error: MusicBox object {self} has no simulation length.")
        if self.box_model_options.chem_step_time is None:
            raise Exception(f"Error: MusicBox object {self} has no chemistry step time.")
        if self.box_model_options.output_step_time is None:
            raise Exception(f"Error: MusicBox object {self} has no output step time.")

        simulation_length = self.box_model_options.simulation_length
        output_step_time = self.box_model_options.output_step_time
        chem_step_time = self.box_model_options.chem_step_time

        # Get concentration events (times where concentrations are explicitly set)
        # Normalize event times to floats to avoid type mismatches (e.g., 0 vs 0.0 or numpy floats)
        raw_concentration_events = self._conditions_manager.concentration_events
        concentration_events = {float(t): v for t, v in raw_concentration_events.items()}

        # Sort concentration event times once for efficient lookup
        sorted_event_times = sorted(concentration_events.keys())
        next_event_idx = 0  # Track index of next event to process

        # Get species names for output formatting
        species_names = list(self.state.get_concentrations().keys())

        # Get initial conditions and set them on the state
        curr_conds = self._conditions_manager.get_conditions_at_time(0.0)
        self.state.set_conditions(curr_conds["temperature"], curr_conds["pressure"])
        if 0.0 in concentration_events:
            self.state.set_concentrations(concentration_events[0.0])
            # Skip the initial event since we've already processed it
            if sorted_event_times and sorted_event_times[0] == 0.0:
                next_event_idx = 1
        self.state.set_user_defined_rate_parameters(
            self._normalize_rate_params(curr_conds["rate_parameters"])
        )

        # Run the simulation, collecting raw output
        curr_time = 0.0
        next_output_time = curr_time
        output_array = []

        with tqdm(total=simulation_length, desc="Simulation Progress", unit=f" [model integration steps ({chem_step_time} s)]", leave=False) as pbar:
            while curr_time <= simulation_length:

                # Collect output if enough time has elapsed
                if next_output_time <= curr_time:
                    output_array.append(self._collect_output_row(curr_time))
                    next_output_time += output_step_time

                    # Bail out mid-loop if we completed the final output step
                    if next_output_time > simulation_length:
                        break

                # Apply any concentration events we've crossed
                # Process events using index tracking (O(1) amortized per timestep)
                # When multiple events occur at same time, processes all of them (O(k) where k is events at that time)
                while next_event_idx < len(sorted_event_times):
                    next_event_time = sorted_event_times[next_event_idx]
                    if next_event_time <= curr_time:
                        self.state.set_concentrations(concentration_events[next_event_time])
                        next_event_idx += 1
                    else:
                        break  # No more events to process at this time

                # Look up conditions at current time (step interpolation for env/rate params)
                curr_conds = self._conditions_manager.get_conditions_at_time(curr_time)
                self.state.set_conditions(curr_conds["temperature"], curr_conds["pressure"])
                self.state.set_user_defined_rate_parameters(
                    self._normalize_rate_params(curr_conds["rate_parameters"])
                )

                # Solve for one chemistry step
                elapsed = 0
                while elapsed < chem_step_time:
                    remaining_time = chem_step_time - elapsed
                    result = self.solver.solve(self.state, remaining_time)
                    elapsed += result.stats.final_time
                    curr_time += result.stats.final_time
                    if result.state != SolverState.Converged:
                        print(f"Solver state: {result.state}, time: {curr_time}")

                pbar.update(chem_step_time)

        return self._format_output(output_array, species_names)

    def _collect_output_row(self, curr_time: float) -> list:
        """
        Collect a single row of output data from the current state.

        Args:
            curr_time: Current simulation time in seconds.

        Returns:
            List of [time, temperature, pressure, air_density, conc1, conc2, ...]
        """
        state_conditions = self.state.get_conditions()
        row = [
            curr_time,
            state_conditions["temperature"][0],
            state_conditions["pressure"][0],
            state_conditions["air_density"][0]
        ]
        for _, concentration in self.state.get_concentrations().items():
            row.append(concentration[0])
        return row

    def _format_output(self, output_array: list, species_names: list) -> pd.DataFrame:
        """
        Format raw output array into a DataFrame with proper column names.

        Args:
            output_array: List of rows, each containing
                          [time, temp, pressure, air_density, conc1, conc2, ...]
            species_names: List of species names in the same order as concentrations.

        Returns:
            DataFrame with properly named columns.
        """
        header = [
            "time.s",
            "ENV.temperature.K",
            "ENV.pressure.Pa",
            "ENV.air number density.mol m-3"
        ]
        for species in species_names:
            header.append(f"CONC.{species}.mol m-3")

        return pd.DataFrame(output_array, columns=header)

    def _normalize_rate_params(self, rate_params: dict) -> dict:
        """
        Normalize rate parameter keys for the solver.

        Converts from new format (e.g., "PHOTO.O3_1.s-1") to solver format (e.g., "PHOTO.O3_1").

        Args:
            rate_params: Dictionary of rate parameters in new format.

        Returns:
            Dictionary with normalized keys for the solver.
        """
        normalized = {}
        for key, value in rate_params.items():
            parts = key.split(".")
            if len(parts) >= 3:
                # Handle SURF specially - it has 4 parts: SURF.name.property.unit
                if parts[0] == "SURF" and len(parts) == 4:
                    # Keep format: SURF.name.property [unit]
                    normalized[f"{parts[0]}.{parts[1]}.{parts[2]} [{parts[3]}]"] = value
                else:
                    # Standard format: PREFIX.name.unit -> PREFIX.name
                    normalized[f"{parts[0]}.{parts[1]}"] = value
            else:
                normalized[key] = value
        return normalized

    def loadJson(self, path_to_json):
        """
        Reads and parses a JSON file and create a solver.

        Args:
            path_to_json (str): The JSON path to the JSON file.

        Returns:
            None

        Raises:
            ValueError: If the JSON string cannot be parsed.
        """

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)

            if "model components" in data and data["model components"]:
                # V0 mechanism configuration (already in separate file)
                camp_path = os.path.join(os.path.dirname(path_to_json), data['model components'][0]['configuration file'])
                try:
                    parser = mc.Parser()
                    self.__mechanism = parser.parse_and_convert_v0(camp_path)
                except Exception as e:
                    logger.warning(
                        f"Failed to parse V0 mechanism configuration from {camp_path}: {e}. This may affect downstream packages that depend on the mechanism property being set.")
                self.solver = musica.MICM(config_path=camp_path, solver_type=musica.SolverType.rosenbrock_standard_order)
            elif "mechanism" in data and data["mechanism"]:
                # V1 mechanism configuration (in the same file)
                mechanism_json = data['mechanism']
                with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp_mech_file:
                    tmp_mech_file.write(json.dumps(mechanism_json))
                    tmp_mech_file.flush()
                    tmp_mech_file_path = tmp_mech_file.name
                # Save mechanism
                parser = mc.Parser()
                self.__mechanism = parser.parse(tmp_mech_file_path)
                # Initialize the musica solver
                self.solver = musica.MICM(config_path=tmp_mech_file_path, solver_type=musica.SolverType.rosenbrock_standard_order)
                atexit.register(os.remove, tmp_mech_file_path)

            # Set box model options
            self.box_model_options = BoxModelOptions.from_config(data)

            # Load conditions using the new ConditionsManager
            self._conditions_manager = ConditionsManager.from_config(path_to_json, data)
            if self.__mechanism:
                self._conditions_manager.set_mechanism(self.__mechanism)

        # Create a state for the solver
        self.state = self.solver.create_state(1)

    def load_mechanism(self, mechanism, solver_type=musica.SolverType.rosenbrock_standard_order):
        """
        Creates a solver for the specified mechanism.

        Args:
            mechanism (Mechanism): The mechanism to be used for the solver.
            solver_type: The solver type to use.
        """
        self.__mechanism = mechanism
        self._conditions_manager.set_mechanism(mechanism)
        self.solver = musica.MICM(mechanism=mechanism, solver_type=solver_type)
        self.state = self.solver.create_state(1)

    @property
    def mechanism(self):
        if self.__mechanism is None:
            raise ValueError("Mechanism is not loaded.")
        return self.__mechanism
