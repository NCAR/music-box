import musica
import csv
from .conditions import Conditions
from .model_options import BoxModelOptions
from .species_list import SpeciesList
from .reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
from .reaction_list import ReactionList
from .evolving_conditions import EvolvingConditions
import json
import os

import logging
logging.basicConfig(level=logging.DEBUG)
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

    def generateConfig(self, directory):
        """
        Generate configuration JSON for the box model simulation and writes it to files in the specified directory.

        Args:
            directory (str): The directory where the configuration files will be written.

        Returns:
            None
        """
        output_path = "./src/configs/" + directory

        # Check if directory exists and create it if it doesn't
        if not os.path.exists(output_path):
            os.makedirs(output_path)
            os.makedirs(output_path + "/camp_data")

        # Make camp_data config
        with open(output_path + "/camp_data/config.json", 'w') as camp_config_file:
            data = {
                "camp-files": [
                    "species.json",
                    "reactions.json"
                ]
            }

            camp_config_file.write(json.dumps(data, indent=4))

        # Make species and reactions configs
        with open(output_path + "/camp_data/species.json", 'w') as species_file:
            species_file.write(self.generateSpeciesConfig())

        with open(output_path + "/camp_data/reactions.json", 'w') as reactions_file:
            reactions_file.write(self.generateReactionConfig())

        # Make box model options config
        with open(output_path + "/" + directory + "_config.json", 'w') as config_file:
            data = {}

            data["box model options"] = {
                "grid": self.box_model_options.grid,
                "chemistry time step [sec]": self.box_model_options.chem_step_time,
                "output time step [sec]": self.box_model_options.output_step_time,
                "simulation length [sec]": self.box_model_options.simulation_length,
            }

            data["chemical species"] = {}

            if self.initial_conditions.species_concentrations is not None:
                for species_concentration in self.initial_conditions.species_concentrations:
                    data["chemical species"][species_concentration.species.name] = {
                        "initial value [mol m-3]": species_concentration.concentration}

            data["environmental conditions"] = {
                "pressure": {
                    "initial value [Pa]": self.initial_conditions.pressure,
                },
                "temperature": {
                    "initial value [K]": self.initial_conditions.temperature,
                },
            }

            data["evolving conditions"] = {
                "evolving_conditions.csv": {},
            }

            data["initial conditions"] = {
                "initial_conditions.csv": {}
            }

            data["model components"] = [
                {
                    "type": "CAMP",
                    "configuration file": "camp_data/config.json",
                    "override species": {
                        "M": {
                            "mixing ratio mol mol-1": 1
                        }
                    },
                    "suppress output": {
                        "M": {}
                    }
                }
            ]

            config_file.write(json.dumps(data, indent=4))

        # Make evolving conditions config
        with open(output_path + "/evolving_conditions.csv", 'w', newline='') as evolving_conditions_file:
            writer = csv.writer(evolving_conditions_file)
            writer.writerow(self.evolving_conditions.headers)

            for i in range(len(self.evolving_conditions.times)):
                row = [self.evolving_conditions.times[i]]

                for header in self.evolving_conditions.headers[1:]:
                    if header == "ENV.pressure.Pa":
                        row.append(
                            self.evolving_conditions.conditions[i].pressure)
                    elif header == "ENV.temperature.K":
                        row.append(
                            self.evolving_conditions.conditions[i].temperature)
                    elif header.startswith("CONC."):
                        species_name = header.split('.')[1]
                        species_concentration = next(
                            (x for x in self.evolving_conditions.conditions[i].species_concentrations if x.species.name == species_name), None)
                        row.append(species_concentration.concentration)
                    elif header.endswith(".s-1"):
                        reaction_name = header.split('.')

                        if reaction_name[0] == 'LOSS' or reaction_name[0] == 'EMIS':
                            reaction_name = reaction_name[0] + \
                                '_' + reaction_name[1]
                        else:
                            reaction_name = reaction_name[1]

                        reaction_rate = next(
                            (x for x in self.evolving_conditions.conditions[i].reaction_rates if x.reaction.name == reaction_name), None)
                        row.append(reaction_rate.rate)

                writer.writerow(row)

        reaction_names = []
        reaction_rates = []

        for reaction_rate in self.initial_conditions.reaction_rates:
            if reaction_rate.reaction.reaction_type == "PHOTOLYSIS":
                name = "PHOT." + reaction_rate.reaction.name + ".s-1"
            elif reaction_rate.reaction.reaction_type == "LOSS":
                name = "LOSS." + reaction_rate.reaction.name + ".s-1"
            elif reaction_rate.reaction.reaction_type == "EMISSION":
                name = "EMISSION." + reaction_rate.reaction.name + ".s-1"

            reaction_names.append(name)
            reaction_rates.append(reaction_rate.rate)
        # writes reaction rates inital conditions to file
        with open(output_path + "/initial_conditions.csv", 'w', newline='') as initial_conditions_file:
            writer = csv.writer(initial_conditions_file)
            writer.writerow(reaction_names)
            writer.writerow(reaction_rates)

    def generateSpeciesConfig(self):
        """
        Generate a JSON configuration for the species in the box model.

        Returns:
            str: A JSON-formatted string representing the species configuration.
        """

        speciesArray = []

        # Adds relative tolerance if value is set
        if (self.species_list.relative_tolerance is not None):
            relativeTolerance = {}
            relativeTolerance["type"] = "RELATIVE_TOLERANCE"
            relativeTolerance["value"] = self.species_list.relative_tolerance
            speciesArray.append(relativeTolerance)

        # Adds species to config
        for species in self.species_list.species:
            spec = {}

            # Add species name if value is set
            if (species.name is not None):
                spec["name"] = species.name

            spec["type"] = "CHEM_SPEC"

            # Add species absoluate tolerance if value is set
            if (species.absolute_tolerance is not None):
                spec["absolute tolerance"] = species.absolute_tolerance

            # Add species phase if value is set
            if (species.phase is not None):
                spec["phase"] = species.phase

            # Add species molecular weight if value is set
            if (species.molecular_weight is not None):
                spec["molecular weight [kg mol-1]"] = species.molecular_weight

            # Add species density if value is set
            if (species.density is not None):
                spec["density [kg m-3]"] = species.density

            speciesArray.append(spec)

        species_json = {
            "camp-data": speciesArray
        }

        return json.dumps(species_json, indent=4)

    def generateReactionConfig(self):
        """
        Generate a JSON configuration for the reactions in the box model.

        Returns:
            str: A JSON-formatted string representing the reaction configuration.
        """
        reacList = {}

        # Add mechanism name if value is set
        if self.reaction_list.name is not None:
            reacList["name"] = self.reaction_list.name

        reacList["type"] = "MECHANISM"

        reactionsArray = []

        # Adds reaction to config
        for reaction in self.reaction_list.reactions:
            reac = {}

            # Adds reaction name if value is set
            if (reaction.reaction_type is not None):
                reac["type"] = reaction.reaction_type

            reactants = {}

            # Adds reactants
            for reactant in reaction.reactants:
                quantity = {}

                # Adds reactant quantity if value is set
                if reactant.quantity is not None:
                    quantity["qty"] = reactant.quantity
                reactants[reactant.name] = quantity

            reac["reactants"] = reactants

            if not isinstance(reaction, Branched):
                products = {}

                # Adds products
                for product in reaction.products:
                    yield_value = {}

                    # Adds product yield if value is set
                    if product.yield_value is not None:
                        yield_value["yield"] = product.yield_value
                    products[product.name] = yield_value

                reac["products"] = products

            # Add reaction parameters if necessary
            if isinstance(reaction, Branched):
                alkoxy_products = {}

                # Adds alkoxy products
                for alkoxy_product in reaction.alkoxy_products:
                    yield_value = {}

                    # Adds alkoxy product yield if value is set
                    if alkoxy_product.yield_value is not None:
                        yield_value["yield"] = alkoxy_product.yield_value
                    alkoxy_products[alkoxy_product.name] = yield_value

                reac["alkoxy products"] = alkoxy_products

                nitrate_products = {}

                # Adds nitrate products
                for nitrate_product in reaction.nitrate_products:
                    yield_value = {}

                    # Adds nitrate product yield if value is set
                    if nitrate_product.yield_value is not None:
                        yield_value["yield"] = nitrate_product.yield_value
                    nitrate_products[nitrate_product.name] = yield_value

                reac["nitrate products"] = nitrate_products

                # Adds parameters for the reaction
                if reaction.X is not None:
                    reac["X"] = reaction.X
                if reaction.Y is not None:
                    reac["Y"] = reaction.Y
                if reaction.a0 is not None:
                    reac["a0"] = reaction.a0
                if reaction.n is not None:
                    reac["n"] = reaction.n

            elif isinstance(reaction, Arrhenius):
                # Adds parameters for the reaction
                if reaction.A is not None:
                    reac["A"] = reaction.A
                if reaction.B is not None:
                    reac["B"] = reaction.B
                if reaction.D is not None:
                    reac["D"] = reaction.D
                if reaction.E is not None:
                    reac["E"] = reaction.E
                if reaction.Ea is not None:
                    reac["Ea"] = reaction.Ea

            elif isinstance(reaction, Tunneling):
                # Adds parameters for the reaction
                if reaction.A is not None:
                    reac["A"] = reaction.A
                if reaction.B is not None:
                    reac["B"] = reaction.B
                if reaction.C is not None:
                    reac["C"] = reaction.C

            elif isinstance(reaction, Troe_Ternary):
                # Adds parameters for the reaction
                if reaction.k0_A is not None:
                    reac["k0_A"] = reaction.k0_A
                if reaction.k0_B is not None:
                    reac["k0_B"] = reaction.k0_B
                if reaction.k0_C is not None:
                    reac["k0_C"] = reaction.k0_C
                if reaction.kinf_A is not None:
                    reac["kinf_A"] = reaction.kinf_A
                if reaction.kinf_B is not None:
                    reac["kinf_B"] = reaction.kinf_B
                if reaction.kinf_C is not None:
                    reac["kinf_C"] = reaction.kinf_C
                if reaction.Fc is not None:
                    reac["Fc"] = reaction.Fc
                if reaction.N is not None:
                    reac["N"] = reaction.N

            # Adds reaction name if value is set
            if (reaction.name is not None):
                reac["MUSICA name"] = reaction.name

            if (reaction.scaling_factor is not None):
                reac["scaling factor"] = reaction.scaling_factor

            reactionsArray.append(reac)

        reacList["reactions"] = reactionsArray

        reactionsJson = {
            "camp-data": [reacList]
        }

        return json.dumps(reactionsJson, indent=4)

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
            musica.micmsolver.rosenbrock,
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

            # outputs to output_array if enough time has elapsed
            if (next_output_time <= curr_time):
                row = []
                row.append(next_output_time)
                row.append(curr_conditions.temperature)
                row.append(curr_conditions.pressure)
                for conc in ordered_concentrations:
                    row.append(conc)
                output_array.append(row)
                next_output_time += self.box_model_options.output_step_time

            # iterates evolving  conditions if enough time has elapsed
            while (
                    next_conditions is not None and next_conditions_time <= curr_time):

                curr_conditions.update_conditions(next_conditions)

                # iterates next_conditions if there are remaining evolving
                # conditions
                if (len(self.evolving_conditions) > next_conditions_index + 1):
                    next_conditions_index += 1
                    next_conditions = self.evolving_conditions.conditions[next_conditions_index]
                    next_conditions_time = self.evolving_conditions.times[next_conditions_index]

                    ordered_rate_constants = self.order_reaction_rates(
                        curr_conditions, rate_constant_ordering)

                else:
                    next_conditions = None

            #  calculate air density from the ideal gas law
            BOLTZMANN_CONSTANT = 1.380649e-23
            AVOGADRO_CONSTANT = 6.02214076e23
            GAS_CONSTANT = BOLTZMANN_CONSTANT * AVOGADRO_CONSTANT
            air_density = curr_conditions.pressure / \
                (GAS_CONSTANT * curr_conditions.temperature)

            # solves and updates concentration values in concentration array
            if (not ordered_concentrations):
                logger.info("Warning: ordered_concentrations list is empty.")
            musica.micm_solve(
                self.solver,
                self.box_model_options.chem_step_time,
                curr_conditions.temperature,
                curr_conditions.pressure,
                air_density,
                ordered_concentrations,
                ordered_rate_constants)

            # increments time
            curr_time += self.box_model_options.chem_step_time

        # outputs to file if output is present
        if (output_path is not None):
            logger.info("path_to_output = {}".format(output_path))
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'w', newline='') as output:
                writer = csv.writer(output)
                writer.writerows(output_array)

        # returns output_array
        return output_array

    def readFromUIJson(self, path_to_json):
        """
        Reads and parses a JSON file from the MusicBox Interactive UI to set up the box model simulation.

        This function takes the path to a JSON file, reads the file, and parses the JSON
        to set up the box model simulation.

        Args:
            path_to_json (str): The path to the JSON file from the UI.

        Returns:
            None

        Raises:
            ValueError: If the JSON file cannot be read or parsed.
        """

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)

            # Set box model options
            self.box_model_options = BoxModelOptions.from_UI_JSON(data)

            # Set species list
            self.species_list = SpeciesList.from_UI_JSON(data)

            # Set reaction list
            self.reaction_list = ReactionList.from_UI_JSON(
                data, self.species_list)

            # Set initial conditions
            self.initial_conditions = Conditions.from_UI_JSON(
                data, self.species_list, self.reaction_list)

            # Set evolving conditions
            self.evolving_conditions = EvolvingConditions.from_UI_JSON(
                data, self.species_list, self.reaction_list)

    def readFromUIJsonString(self, data):
        """
        Reads and parses a JSON string from the MusicBox Interactive UI to set up the box model simulation.

        Args:
            json_string (str): The JSON string from the UI.

        Returns:
            None

        Raises:
            ValueError: If the JSON string cannot be parsed.
        """

        # Set box model options
        self.box_model_options = BoxModelOptions.from_UI_JSON(data)

        # Set species list
        self.species_list = SpeciesList.from_UI_JSON(data)

        # Set reaction list
        self.reaction_list = ReactionList.from_UI_JSON(data, self.species_list)

        # Set initial conditions
        self.initial_conditions = Conditions.from_UI_JSON(
            data, self.species_list, self.reaction_list)

        # Set evolving conditions
        self.evolving_conditions = EvolvingConditions.from_UI_JSON(
            data, self.species_list, self.reaction_list)

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

    def userDefinedReactionRates(self):
        """
        Retrieves the user-defined reaction rates from the solver.

        This function calls the `user_defined_reaction_rates` function from the `musica` module,
        passing the solver instance from the current object.

        Returns:
            dict: The dictionary of user-defined reaction rates used in the solver.
        """
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
