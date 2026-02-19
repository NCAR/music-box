import musica
from .conditions import Conditions
from .model_options import BoxModelOptions
from .evolving_conditions import EvolvingConditions
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
    Represents a box model with attributes such as box model options, species list, reaction list,
    initial conditions, evolving conditions, solver, and state.

    Attributes:
        box_model_options (BoxModelOptions): Options for the box model simulation.
        initial_conditions (Conditions): Initial conditions for the simulation.
        evolving_conditions (List[EvolvingConditions]): List of evolving conditions over time.
        solver: The solver used for the box model simulation.
        state: The current state of the box model simulation.
    """

    def __init__(
            self,
            box_model_options=None,
            initial_conditions=None,
            evolving_conditions=None):
        """
        Initializes a new instance of the BoxModel class.

        Args:
            box_model_options (BoxModelOptions): Options for the box model simulation.
            initial_conditions (Conditions): Initial conditions for the simulation.
            evolving_conditions (List[EvolvingConditions]): List of evolving conditions over time.
        """
        self.box_model_options = box_model_options if box_model_options is not None else BoxModelOptions()
        self.initial_conditions = initial_conditions if initial_conditions is not None else Conditions()
        self.evolving_conditions = evolving_conditions if evolving_conditions is not None else EvolvingConditions([], [])
        self.solver = None
        self.state = None
        self.__mechanism = None

    def add_evolving_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition [s].
            conditions (Conditions): The associated conditions at the given time point.
        """
        self.evolving_conditions.add_condition(time_point, conditions)

    def solve(self, callback=None):
        """
        Solves the box model simulation and optionally writes the output to a file.

        This function runs the box model simulation using the current settings and
        conditions. If a path is provided, it writes the output of the simulation to
        the specified file.

        Args:
            callback (function, optional): A callback function that is called after each time step. Defaults to None.
            The callback will take the most recent results, the current time, conditions, and the total simulation time as arguments.

        Returns:
            list: A 2D list where each inner list represents the results of the simulation
            at a specific time step.
        """
        if self.solver is None:
            raise Exception(f"Error: MusicBox object {self} has no solver.")
        if self.state is None:
            raise Exception(f"Error: MusicBox object {self} has no state.")
        if self.initial_conditions is None:
            raise Exception(f"Error: MusicBox object {self} has no initial conditions.")
        if self.box_model_options is None:
            raise Exception(f"Error: MusicBox object {self} has no time step parameters.")
        if self.box_model_options.simulation_length is None:
            raise Exception(f"Error: MusicBox object {self} has no simulation length.")
        if self.box_model_options.chem_step_time is None:
            raise Exception(f"Error: MusicBox object {self} has no chemistry step time.")
        if self.box_model_options.output_step_time is None:
            raise Exception(f"Error: MusicBox object {self} has no output step time.")

        # sets up initial conditions to be current conditions
        curr_conditions = self.initial_conditions

        # sets up next condition if evolving conditions is not empty
        next_conditions_index = 0
        if (len(self.evolving_conditions) != 0):
            if (self.evolving_conditions.times[0] == 0):
                initial_concentration = curr_conditions.species_concentrations
                evolving_concentrations = self.evolving_conditions.conditions[0].species_concentrations
                initial_concentration.update({k: float(v) for k, v in evolving_concentrations.items() if k in initial_concentration})
                next_conditions_index += 1
        if (len(self.evolving_conditions) > next_conditions_index):
            next_conditions = self.evolving_conditions.conditions[next_conditions_index]
            next_conditions_time = self.evolving_conditions.times[next_conditions_index]
        else:
            next_conditions = None
            next_conditions_time = 0

        header = ["time.s", "ENV.temperature.K", "ENV.pressure.Pa", "ENV.air number density.mol m-3"]
        for species, _ in self.state.get_concentrations().items():
            header.append("CONC." + species + ".mol m-3")

        # set the initial conditions in the state
        self.state.set_conditions(curr_conditions.temperature, curr_conditions.pressure)  # air denisty will be calculated based on Ideal gas law
        self.state.set_concentrations(curr_conditions.species_concentrations)
        self.state.set_user_defined_rate_parameters(curr_conditions.rate_parameters)

        # runs the simulation at each timestep
        curr_time = 0.0
        next_output_time = curr_time
        simulation_length = self.box_model_options.simulation_length
        output_array = []
        with tqdm(total=simulation_length, desc="Simulation Progress", unit=f" [model integration steps ({self.box_model_options.chem_step_time} s)]", leave=False) as pbar:
            while curr_time <= simulation_length:

                # outputs to output_array if enough time has elapsed
                if (next_output_time <= curr_time):
                    row = []
                    row.append(curr_time)
                    conditions = self.state.get_conditions()
                    row.append(conditions["temperature"][0])
                    row.append(conditions["pressure"][0])
                    row.append(conditions["air_density"][0])
                    for _, concentration in self.state.get_concentrations().items():
                        row.append(concentration[0])
                    output_array.append(row)

                    next_output_time += self.box_model_options.output_step_time

                    # calls callback function if present
                    if callback is not None:
                        df = pd.DataFrame(output_array[:-1], columns=header)
                        callback(df, curr_time, curr_conditions, self.box_model_options.simulation_length)

                    # We want to output the initial state before the first solve().
                    # But we also want to avoid solving() beyond the last output.
                    # Solution is to bail out mid-loop if we completed the final output step.
                    if (next_output_time > simulation_length):
                        break

                # iterates evolving conditions if enough time has elapsed
                while (next_conditions is not None and next_conditions_time <= curr_time):
                    curr_conditions = next_conditions
                    # iterates next_conditions if there are remaining evolving
                    # conditions
                    if (len(self.evolving_conditions) > next_conditions_index + 1):
                        next_conditions_index += 1
                        next_conditions = self.evolving_conditions.conditions[next_conditions_index]
                        next_conditions_time = self.evolving_conditions.times[next_conditions_index]
                    else:
                        next_conditions = None
                    # set the current conditions in the state
                    self.state.set_conditions(curr_conditions.temperature, curr_conditions.pressure)  # air denisty will be calculated based on Ideal gas law
                    self.state.set_concentrations(curr_conditions.species_concentrations)
                    self.state.set_user_defined_rate_parameters(curr_conditions.rate_parameters)

                # ensure the time step is not greater than the next update to the
                # evolving conditions or the next output time
                time_step = self.box_model_options.chem_step_time
                if (next_conditions is not None and next_conditions_time > curr_time):
                    time_step = min(time_step, next_conditions_time - curr_time)
                if (next_output_time > curr_time):
                    time_step = min(time_step, next_output_time - curr_time)

                self.solver.solve(self.state, time_step)

                # increments time
                curr_time += time_step
                pbar.update(time_step)
        return pd.DataFrame(output_array, columns=header)

    def loadJson(self, path_to_json):
        """
        Reads and parses a JSON file and create a solver

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
                # Initalize the musica solver
                self.solver = musica.MICM(config_path=tmp_mech_file_path, solver_type=musica.SolverType.rosenbrock_standard_order)
                atexit.register(os.remove, tmp_mech_file_path)

            # Set box model options
            self.box_model_options = BoxModelOptions.from_config(data)

            # Set initial conditions
            self.initial_conditions = Conditions.from_config(path_to_json, data)

            # Set evolving conditions
            self.evolving_conditions = EvolvingConditions.from_config(path_to_json, data)

        # Create a state for the solver
        self.state = self.solver.create_state(1)

    def load_mechanism(self, mechanism, solver_type=musica.SolverType.rosenbrock_standard_order):
        """
        Creates a solver for the specified mechanism.

        Args:
            mechanism (Mechanism): The mechanism to be used for the solver.
        """
        self.__mechanism = mechanism
        self.solver = musica.MICM(mechanism=mechanism, solver_type=solver_type)
        self.state = self.solver.create_state(1)

    @property
    def mechanism(self):
        if self.__mechanism is None:
            raise ValueError("Mechanism is not loaded.")
        return self.__mechanism

    def export_to_json(self, path_to_json):
        """
        Export the MusicBox configuration to a JSON file.

        The initial conditions are embedded inline in the JSON. If evolving
        conditions are present they are written to a companion CSV file in the
        same directory as the JSON file.

        Args:
            path_to_json (str): Path to write the JSON config file.

        Raises:
            ValueError: If no mechanism is loaded.
        """
        config = {}

        # Box model options (all times stored internally in seconds)
        config["box model options"] = {
            "grid": self.box_model_options.grid,
            "chemistry time step [sec]": self.box_model_options.chem_step_time,
            "output time step [sec]": self.box_model_options.output_step_time,
            "simulation length [sec]": self.box_model_options.simulation_length,
        }

        # Initial conditions – embed as inline data
        headers = []
        values = []
        for species, conc in self.initial_conditions.species_concentrations.items():
            headers.append(f"CONC.{species} [mol m-3]")
            values.append(float(conc))
        for key, val in self.initial_conditions.rate_parameters.items():
            headers.append(key)
            values.append(float(val))

        config["initial conditions"] = {}
        if headers:
            config["initial conditions"]["data"] = [headers, values]

        # Environmental conditions
        config["environmental conditions"] = {
            "temperature": {
                "initial value [K]": self.initial_conditions.temperature
            },
            "pressure": {
                "initial value [Pa]": self.initial_conditions.pressure
            },
        }

        # Evolving conditions
        if len(self.evolving_conditions) > 0:
            evol_csv_name = "evolving_conditions.csv"
            evol_csv_path = os.path.join(
                os.path.dirname(os.path.abspath(path_to_json)), evol_csv_name
            )
            self._write_evolving_conditions_csv(evol_csv_path)
            config["evolving conditions"] = {"filepaths": [evol_csv_name]}
        else:
            config["evolving conditions"] = {}

        # Mechanism (v1 format)
        mechanism_dict = self.mechanism.serialize()
        mechanism_dict["version"] = "1.0.0"
        config["mechanism"] = mechanism_dict

        with open(path_to_json, "w") as f:
            json.dump(config, f, indent=2)

    def _write_evolving_conditions_csv(self, csv_path):
        """
        Write evolving conditions to a CSV file compatible with
        EvolvingConditions.read_conditions_from_file.

        Args:
            csv_path (str): Path to write the CSV file.
        """
        if len(self.evolving_conditions) == 0:
            return

        # Collect all species and rate-parameter keys across all time steps
        all_species = []
        all_rate_params = []
        seen_species = set()
        seen_rate_params = set()
        has_temperature = False
        has_pressure = False

        for cond in self.evolving_conditions.conditions:
            if cond.temperature is not None:
                has_temperature = True
            if cond.pressure is not None:
                has_pressure = True
            for s in cond.species_concentrations:
                if s not in seen_species:
                    seen_species.add(s)
                    all_species.append(s)
            for p in cond.rate_parameters:
                if p not in seen_rate_params:
                    seen_rate_params.add(p)
                    all_rate_params.append(p)

        # Build ordered header
        header = ["time.s"]
        if has_pressure:
            header.append("ENV.pressure.Pa")
        if has_temperature:
            header.append("ENV.temperature.K")
        for species in all_species:
            header.append(f"CONC.{species}.mol m-3")
        for param in all_rate_params:
            parts = param.split(".", 1)
            condition_type = parts[0]
            label = parts[1] if len(parts) > 1 else ""
            if condition_type in ("PHOTO", "LOSS"):
                header.append(f"{condition_type}.{label}.s-1")
            elif condition_type == "EMIS":
                header.append(f"{condition_type}.{label}.mol m-3 s-1")
            else:
                header.append(f"{param}.unitless")

        # Build rows
        rows = []
        for time, cond in zip(
            self.evolving_conditions.times, self.evolving_conditions.conditions
        ):
            row = [float(time)]
            if has_pressure:
                row.append(
                    float(cond.pressure) if cond.pressure is not None else ""
                )
            if has_temperature:
                row.append(
                    float(cond.temperature) if cond.temperature is not None else ""
                )
            for species in all_species:
                val = cond.species_concentrations.get(species)
                row.append(float(val) if val is not None else "")
            for param in all_rate_params:
                val = cond.rate_parameters.get(param)
                row.append(float(val) if val is not None else "")
            rows.append(row)

        df = pd.DataFrame(rows, columns=header)
        df.to_csv(csv_path, index=False)
