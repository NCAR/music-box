import os
from .reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
import json
import csv


class Configuration:

    def __init__(self):
        self.species_list = None
        self.reaction_list = None
        self.initial_conditions = None
        self.evolving_conditions = None
        self.box_model_options = None

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
                name = "EMIS." + reaction_rate.reaction.name + ".s-1"
            elif reaction_rate.reaction.reaction_type == "USER_DEFINED":
                name = "USER." + reaction_rate.reaction.name + ".s-1"

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
