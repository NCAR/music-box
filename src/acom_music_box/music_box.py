import musica
from .conditions import Conditions
from .model_options import BoxModelOptions
from .species_list import SpeciesList
from .reaction_list import ReactionList
from .evolving_conditions import EvolvingConditions
import json
import os
import pandas as pd

import logging
logger = logging.getLogger(__name__)


class MusicBox:
    """
    Represents a box model with attributes such as box model options, species list, reaction list,
    initial conditions, and evolving conditions.

    Attributes:
        boxModelOptions (BoxModelOptions): Options for the box model simulation.
        speciesList (SpeciesList): A list of species.
        reactionList (ReactionList): A list of reactions.
        initialConditions (Conditions): Initial conditions for the simulation.
        evolvingConditions (List[EvolvingConditions]): List of evolving conditions over time.
    """

    def __init__(
            self,
            box_model_options=None,
            species_list=None,
            reaction_list=None,
            initial_conditions=None,
            evolving_conditions=None,
            config_file=None):
        """
        Initializes a new instance of the BoxModel class.

        Args:
            box_model_options (BoxModelOptions): Options for the box model simulation.
            species_list (SpeciesList): A list of species.
            reaction_list (ReactionList): A list of reactions.
            initial_conditions (Conditions): Initial conditions for the simulation.
            evolving_conditions (List[EvolvingConditions]): List of evolving conditions over time.
            config_file (String): File path for the configuration file to be located. Default is "camp_data/config.json".
        """
        self.box_model_options = box_model_options if box_model_options is not None else BoxModelOptions()
        self.species_list = species_list if species_list is not None else SpeciesList()
        self.reaction_list = reaction_list if reaction_list is not None else ReactionList()
        self.initial_conditions = initial_conditions if initial_conditions is not None else Conditions()
        self.evolving_conditions = evolving_conditions if evolving_conditions is not None else EvolvingConditions([
        ], [])
        self.config_file = config_file if config_file is not None else "camp_data/config.json"

        self.solver = None

    def add_evolving_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition.
            conditions (Conditions): The associated conditions at the given time point.
        """
        evolving_condition = EvolvingConditions(
            time=[time_point], conditions=[conditions])
        self.evolvingConditions.append(evolving_condition)

    def create_solver(
            self,
            path_to_config,
            solver_type=musica.micmsolver.rosenbrock,
            number_of_grid_cells=1):
        """
        Creates a micm solver object using the CAMP configuration files.

        Args:
            path_to_config (str): The path to CAMP configuration directory.

        Returns:
            None
        """
        # Create a solver object using the configuration file
        self.solver = musica.create_solver(
            path_to_config,
            solver_type,
            number_of_grid_cells)

    def solve(self, output_path=None):
        """
        Solves the box model simulation and optionally writes the output to a file.

        This function runs the box model simulation using the current settings and
        conditions. If a path is provided, it writes the output of the simulation to
        the specified file.

        Args:
            path_to_output (str, optional): The path to the file where the output will
            be written. If None, no output file is created. Defaults to None.

        Returns:
            list: A 2D list where each inner list represents the results of the simulation
            at a specific time step.
        """

        # sets up initial conditions to be current conditions
        curr_conditions = self.initial_conditions

        # sets up next condition if evolving conditions is not empty
        next_conditions = None
        next_conditions_time = 0
        next_conditions_index = 0
        if (len(self.evolving_conditions) != 0):
            if (self.evolving_conditions.times[0] != 0):
                next_conditions_index = 0
                next_conditions = self.evolving_conditions.conditions[0]
                next_conditions_time = self.evolving_conditions.times[0]
            elif (len(self.evolving_conditions) > 1):
                next_conditions_index = 1
                next_conditions = self.evolving_conditions.conditions[1]
                next_conditions_time = self.evolving_conditions.times[1]

        # initalizes output headers
        output_array = []

        headers = []
        headers.append("time")
        headers.append("ENV.temperature")
        headers.append("ENV.pressure")
        headers.append("ENV.number_density_air")

        if (self.solver is None):
            raise Exception("Error: MusicBox object {} has no solver."
                            .format(self))
        rate_constant_ordering = musica.user_defined_reaction_rates(
            self.solver)

        species_constant_ordering = musica.species_ordering(self.solver)

        # adds species headers to output
        ordered_species_headers = [
            k for k,
            v in sorted(
                species_constant_ordering.items(),
                key=lambda item: item[1])]
        for spec in ordered_species_headers:
            headers.append("CONC." + spec)

        ordered_concentrations = self.order_species_concentrations(
            curr_conditions, species_constant_ordering)
        ordered_rate_constants = self.order_reaction_rates(
            curr_conditions, rate_constant_ordering)

        output_array.append(headers)

        curr_time = 0
        next_output_time = curr_time
        # runs the simulation at each timestep

        while (curr_time <= self.box_model_options.simulation_length):

            # iterates evolving  conditions if enough time has elapsed
            while (
                    next_conditions is not None and next_conditions_time <= curr_time):

                curr_conditions.update_conditions(next_conditions)
                ordered_rate_constants = self.order_reaction_rates(
                    curr_conditions, rate_constant_ordering)

                # iterates next_conditions if there are remaining evolving
                # conditions
                if (len(self.evolving_conditions) > next_conditions_index + 1):
                    next_conditions_index += 1
                    next_conditions = self.evolving_conditions.conditions[next_conditions_index]
                    next_conditions_time = self.evolving_conditions.times[next_conditions_index]
                else:
                    next_conditions = None

            #  calculate air density from the ideal gas law
            BOLTZMANN_CONSTANT = 1.380649e-23
            AVOGADRO_CONSTANT = 6.02214076e23
            GAS_CONSTANT = BOLTZMANN_CONSTANT * AVOGADRO_CONSTANT
            air_density = curr_conditions.pressure / \
                (GAS_CONSTANT * curr_conditions.temperature)

            # outputs to output_array if enough time has elapsed
            if (next_output_time <= curr_time):
                row = []
                row.append(next_output_time)
                row.append(curr_conditions.temperature)
                row.append(curr_conditions.pressure)
                row.append(air_density)
                for conc in ordered_concentrations:
                    row.append(conc)
                output_array.append(row)
                next_output_time += self.box_model_options.output_step_time

            # ensure the time step is not greater than the next update to the
            # evolving conditions or the next output time
            time_step = self.box_model_options.chem_step_time
            if (next_conditions is not None and next_conditions_time > curr_time):
                time_step = min(time_step, next_conditions_time - curr_time)
            if (next_output_time > curr_time):
                time_step = min(time_step, next_output_time - curr_time)

            # solves and updates concentration values in concentration array
            if (not ordered_concentrations):
                logger.info("Warning: ordered_concentrations list is empty.")
            musica.micm_solve(
                self.solver,
                time_step,
                curr_conditions.temperature,
                curr_conditions.pressure,
                air_density,
                ordered_concentrations,
                ordered_rate_constants)

            # increments time
            curr_time += time_step

        df = pd.DataFrame(output_array[1:], columns=output_array[0])
        # outputs to file if output is present
        if output_path is not None:

            # Check if the output_path is a full path or just a file name
            if os.path.dirname(output_path) == '':
                # If output_path is just a filename, use the current directory
                output_path = os.path.join(os.getcwd(), output_path)
            elif not os.path.basename(output_path):
                raise ValueError(f"Invalid output path: '{output_path}' does not contain a filename.")

            # Ensure the directory exists
            dir_path = os.path.dirname(output_path)
            if dir_path and not os.path.exists(dir_path):
                os.makedirs(dir_path, exist_ok=True)

            df.to_csv(output_path, index=False)

        return df

    def readConditionsFromJson(self, path_to_json):
        """
        Reads and parses a JSON file from the CAMP JSON file to set up the box model simulation.

        Args:
            path_to_json (str): The JSON path to the JSON file.

        Returns:
            None

        Raises:
            ValueError: If the JSON string cannot be parsed.
        """

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)
            # Set box model options
            self.box_model_options = BoxModelOptions.from_config_JSON(data)

            # Set species list
            self.species_list = SpeciesList.from_config_JSON(
                path_to_json, data)

            self.reaction_list = ReactionList.from_config_JSON(
                path_to_json, data, self.species_list)

            # Set initial conditions
            self.initial_conditions = Conditions.from_config_JSON(
                path_to_json, data, self.species_list, self.reaction_list)

            # Set initial conditions
            self.evolving_conditions = EvolvingConditions.from_config_JSON(
                path_to_json, data, self.species_list, self.reaction_list)

    def speciesOrdering(self):
        """
        Retrieves the ordering of species used in the solver.

        This function calls the `species_ordering` function from the `musica` module,
        passing the solver instance from the current object.

        Returns:
            dict: The ordered dictionary of species used in the solver.
        """
        return musica.species_ordering(self.solver)

    @classmethod
    def order_reaction_rates(self, curr_conditions, rate_constant_ordering):
        """
        Orders the reaction rates based on the provided ordering.

        This function takes the current conditions and a specified ordering for the rate constants,
        and reorders the reaction rates accordingly.

        Args:
            rate_constants (dict): A dictionary of rate constants.
            rate_constant_ordering (dict): A dictionary that maps rate constant keys to indices for ordering.

        Returns:
            list: An ordered list of rate constants.
        """
        rate_constants = {}
        for rate in curr_conditions.reaction_rates:

            if (rate.reaction.reaction_type == "PHOTOLYSIS"):
                key = "PHOTO." + rate.reaction.name
            elif (rate.reaction.reaction_type == "FIRST_ORDER_LOSS"):
                key = "LOSS." + rate.reaction.name
            elif (rate.reaction.reaction_type == "EMISSION"):
                key = "EMIS." + rate.reaction.name
            elif (rate.reaction.reaction_type == "USER_DEFINED"):
                key = "USER." + rate.reaction.name
            rate_constants[key] = rate.rate

        ordered_rate_constants = len(rate_constants.keys()) * [0.0]
        for key, value in rate_constants.items():
            ordered_rate_constants[rate_constant_ordering[key]] = float(value)
        return ordered_rate_constants

    @classmethod
    def order_species_concentrations(
            self,
            curr_conditions,
            species_constant_ordering):
        concentrations = {}

        for concentraton in curr_conditions.species_concentrations:
            concentrations[concentraton.species.name] = concentraton.concentration

        ordered_concentrations = len(concentrations.keys()) * [0.0]

        for key, value in concentrations.items():
            ordered_concentrations[species_constant_ordering[key]] = value
        return ordered_concentrations
