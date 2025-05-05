import musica
from .conditions import Conditions
from .model_options import BoxModelOptions
from .evolving_conditions import EvolvingConditions
from .constants import GAS_CONSTANT
import json
import os
import pandas as pd
import numpy as np

from tqdm import tqdm

import logging
logger = logging.getLogger(__name__)


class MusicBox:
    """
    Represents a box model with attributes such as box model options, species list, reaction list,
    initial conditions, evolving conditions, solver, and state.

    Attributes:
        box_model_options (BoxModelOptions): Options for the box model simulation.
        initial_conditions (Conditions): Initial conditions for the simulation.
        evolving_conditions (List[EvolvingConditions]): List of evolving conditions over time.
        config_file (String): File path for the configuration file to be located. Default is "camp_data/config.json".
        solver: The solver used for the box model simulation.
        state: The current state of the box model simulation.
    """

    def __init__(
            self,
            box_model_options=None,
            initial_conditions=None,
            evolving_conditions=None,
            config_file=None):
        """
        Initializes a new instance of the BoxModel class.

        Args:
            box_model_options (BoxModelOptions): Options for the box model simulation.
            initial_conditions (Conditions): Initial conditions for the simulation.
            evolving_conditions (List[EvolvingConditions]): List of evolving conditions over time.
            config_file (String): File path for the configuration file to be located. Default is "camp_data/config.json".
        """
        self.box_model_options = box_model_options if box_model_options is not None else BoxModelOptions()
        self.initial_conditions = initial_conditions if initial_conditions is not None else Conditions()
        self.evolving_conditions = evolving_conditions if evolving_conditions is not None else EvolvingConditions([], [])
        self.config_file = config_file if config_file is not None else "camp_data/config.json"
        self.solver = None
        self.state = None

    def add_evolving_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition.
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
        if (self.solver is None):
            raise Exception("Error: MusicBox object {} has no solver."
                            .format(self))
        
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
            header.append("CONC."+species+".mol m-3")


        # set the initial conditions in the state
        self.state.set_conditions(curr_conditions.temperature, curr_conditions.pressure) # air denisty will be calculated based on Ideal gas law
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
                    self.state.set_conditions(curr_conditions.temperature, curr_conditions.pressure) # air denisty will be calculated based on Ideal gas law
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
            self.config_file = data['model components'][0]['configuration file']

            # Set box model options
            self.box_model_options = BoxModelOptions.from_config_JSON(data)

            # Set initial conditions
            self.initial_conditions = Conditions.from_config_JSON(path_to_json, data)

            # Set evolving conditions
            self.evolving_conditions = EvolvingConditions.from_config_JSON(path_to_json, data)

        camp_path = os.path.join(os.path.dirname(path_to_json), self.config_file)

        # Initalize the musica solver
        self.solver = musica.MICM(config_path = camp_path, solver_type=musica.SolverType.rosenbrock_standard_order)
        self.state = self.solver.create_state(1)

    @staticmethod
    def order_reaction_rates(curr_conditions, rate_constant_ordering):
        """
        Orders the reaction rates based on the provided ordering.

        This function takes the current conditions and a specified ordering for the rate constants,
        and reorders the reaction rates accordingly.

        Args:
            curr_conditions: A Condition with the current state information
            rate_constant_ordering: A dictionary which maps reaction names to their index in the reaction rates array

        Returns:
            list: An ordered list of rate constants.
        """
        ordered_rate_constants = np.zeros(len(rate_constant_ordering), dtype=np.float64)

        for rate_label, _ in rate_constant_ordering.items():
            if rate_label not in curr_conditions.reaction_rates:
                logger.warning(f"Reaction rate '{rate_label}' not found in current conditions.")
                continue
            else:
                ordered_rate_constants[rate_constant_ordering[rate_label]] = curr_conditions.reaction_rates[rate_label]

        return ordered_rate_constants

    @staticmethod
    def order_species_concentrations(curr_conditions, species_constant_ordering):
        """
        Orders the species concentrations based on the provided ordering.

        This function takes the current conditions and a specified ordering for the species,
        and reorders the species concentrations accordingly.

        Args:
            curr_conditions (Conditions): The current conditions.
            species_constant_ordering (dict): A dictionary that maps species keys to indices for ordering.

        Returns:
            list: An ordered list of species concentrations.
        """
        concentrations = np.zeros(len(species_constant_ordering), dtype=np.float64)

        for species, _ in species_constant_ordering.items():
            if species not in curr_conditions.species_concentrations:
                logger.warning(f"Species '{species}' not found in current conditions.")
                continue
            else:
                concentrations[species_constant_ordering[species]] = curr_conditions.species_concentrations[species]

        return concentrations
