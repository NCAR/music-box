import json

from music_box_evolving_conditions import EvolvingConditions
from music_box_reaction_list import ReactionList
from music_box_reaction import Reaction
from music_box_reactant import Reactant
from music_box_product import Product
from music_box_species_list import SpeciesList
from music_box_species import Species
from music_box_model_options import BoxModelOptions
from music_box_conditions import Conditions
from music_box_species_concentration import SpeciesConcentration

class BoxModel:
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

    def __init__(self, box_model_options=None, species_list=None, reaction_list=None,
             initial_conditions=None, evolving_conditions=None, config_file=None):
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
        self.box_model_options = box_model_options
        self.species_list = species_list
        self.reaction_list = reaction_list
        self.initial_conditions = initial_conditions
        self.evolving_conditions = evolving_conditions
        self.config_file = config_file if config_file is not None else "camp_data/config.json"


    def add_evolving_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition.
            conditions (Conditions): The associated conditions at the given time point.
        """
        evolving_condition = EvolvingConditions(time=[time_point], conditions=[conditions])
        self.evolvingConditions.append(evolving_condition)

    def generateConfig(self):
        """
        Generate configuration JSON for the box model simulation.

        Returns:
        tuple: A tuple containing the species configuration JSON and the reaction configuration JSON.
        """

        speciesConfig = self.generateSpeciesConfig()
        reactionConfig = self.generateReactionConfig()

        return speciesConfig, reactionConfig

    def generateSpeciesConfig(self):
        """
        Generate a JSON configuration for the species in the box model.

        Returns:
            str: A JSON-formatted string representing the species configuration.
        """

        speciesArray = []

        #Adds relative tolerance if value is set
        if(self.species_list.relative_tolerance != None):
            relativeTolerance = {}
            relativeTolerance["Type"] = "RELATIVE_TOLERANCE"
            relativeTolerance["value"] = self.species_list.relative_tolerance
            speciesArray.append(relativeTolerance)

        #Adds species to config
        for species in self.species_list.species:
            spec = {}

            #Add species name if value is set
            if(species.name != None):
                spec["name"] = species.name

            spec["type"] = "CHEM_SPEC"
            
            #Add species absoluate tolerance if value is set
            if(species.absolute_tolerance != None):
                spec["absolute tolerance"] = species.absolute_tolerance
            
            #Add species phase if value is set
            if(species.phase != None):
                spec["phase"] = species.phase            

            #Add species molecular weight if value is set
            if(species.molecular_weight != None):
                spec["molecular weight [kg mol-1]"] = species.molecular_weight
            
            #Add species density if value is set
            if(species.density != None):
                spec["density [kg m-3]"] = species.density

            speciesArray.append(spec)

        species_json = {
            "camp-data" : speciesArray
        }

        return json.dumps(species_json)
    
    
    def generateReactionConfig(self):
        """
        Generate a JSON configuration for the reactions in the box model.

        Returns:
            str: A JSON-formatted string representing the reaction configuration.
        """
        reacList = {}

        #Add mechanism name if value is set
        if self.reaction_list.name != None:
            reacList["name"] = self.reaction_list.name
        
        reacList["type"] = "MECHANISM"

        reactionsArray = []

        #Adds reaction to config
        for reaction in self.reaction_list.reactions:
            reac = {}

            #Adds reaction name if value is set
            if(reaction.reaction_type != None):
                reac["type"] = reaction.reaction_type

            reactants = {}

            #Adds reactants
            for reactant in reaction.reactants:
                quantity = {}

                #Adds reactant quantity if value is set
                if reactant.quantity != None:
                    quantity["quantity"] = reactant.quantity
                reactants[reactant.name] = quantity
            
            reac["reactants"] = reactants

            products = {}

            #Adds products
            for product in reaction.products:
                yield_value = {}

                 #Adds product yield if value is set
                if product.yield_value != None:
                    yield_value["yield"] = product.yield_value
                products[product.name] = yield_value
            
            reac["products"] = products
            
            # Add reaction parameters (A, B, D, E, Ea) if values are set
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
            
            #Adds reaction name if value is set
            if(reaction.name != None):
                reac["MUSICA name"] = reaction.name

            reactionsArray.append(reac)

        reacList["reactions"] = reactionsArray

        reactionsJson = {
            "camp-data" : [reacList]
        }

        return json.dumps(reactionsJson)
    
    def solve(self):
        """
        TODO: Solve the box model simulation.
        """
        # TODO: Implement the logic to solve the box model simulation.
        # Update the internal state of the BoxModel instance to reflect the simulation results.
        pass

    def readFromJson(self, path_to_json):
        """
        TODO: Read the box model configuration from json and sets config
        """
        # TODO: Implement the logic to update the box model config using a json.

        with open(path_to_json, 'r', encoding='utf-16') as json_file:
            data = json.load(json_file)

            # Set box model options
            # make sure to convert the time units to minutes
            chem_step_time = None
            if 'chemistry time step [sec]' in data['conditions']['box model options']:
                chem_step_time = float(data['conditions']['box model options']['chemistry time step [sec]']) / 60
            elif 'chemistry time step [min]' in data['conditions']['box model options']:
                chem_step_time = float(data['conditions']['box model options']['chemistry time step [min]'])
            elif 'chemistry time step [hour]' in data['conditions']['box model options']:
                chem_step_time = float(data['conditions']['box model options']['chemistry time step [hour]']) * 60
            elif 'chemistry time step [day]' in data['conditions']['box model options']:
                chem_step_time = float(data['conditions']['box model options']['chemistry time step [day]']) * 60 * 24

            # make sure to convert the time units to hours
            output_step_time = None
            if 'output time step [sec]' in data['conditions']['box model options']:
                output_step_time = float(data['conditions']['box model options']['output time step [sec]']) / 3600
            elif 'output time step [min]' in data['conditions']['box model options']:
                output_step_time = float(data['conditions']['box model options']['output time step [min]']) / 60
            elif 'output time step [hour]' in data['conditions']['box model options']:
                output_step_time = float(data['conditions']['box model options']['output time step [hour]'])
            elif 'output time step [day]' in data['conditions']['box model options']:
                output_step_time = float(data['conditions']['box model options']['output time step [day]']) * 24

            # make sure to convert the time units to hours
            simulation_length = None
            if 'simulation length [sec]' in data['conditions']['box model options']:
                simulation_length = float(data['conditions']['box model options']['simulation length [sec]']) / 3600
            elif 'simulation length [min]' in data['conditions']['box model options']:
                simulation_length = float(data['conditions']['box model options']['simulation length [min]']) / 60
            elif 'simulation length [hour]' in data['conditions']['box model options']:
                simulation_length = float(data['conditions']['box model options']['simulation length [hour]'])
            elif 'simulation length [day]' in data['conditions']['box model options']:
                simulation_length = float(data['conditions']['box model options']['simulation length [day]']) * 24

            grid = data['conditions']['box model options']['grid']

            self.box_model_options = BoxModelOptions(chem_step_time, output_step_time, simulation_length, grid)

            # Set species list
            species_from_json = []

            for species in data['mechanism']['species']['camp-data']:
                name = species['name']
                absolute_tolerance = species['absolute tolerance'] if 'absolute tolerance' in species else None
                molecular_weight = species['molecular weight [kg mol-1]'] if 'molecular weight [kg mol-1]' in species else None

                # TODO: Add phase and density to species

                species_from_json.append(Species(name, absolute_tolerance, None, molecular_weight, None))

            self.species_list = SpeciesList(species)

            # Set reaction list
            reactions = []

            for reaction in data['mechanism']['reactions']['camp-data'][0]['reactions']:
                name = reaction['MUSICA name'] if 'MUSICA name' in reaction else None
                reaction_type = reaction['type']
                A = reaction['A'] if 'A' in reaction else None
                B = reaction['B'] if 'B' in reaction else None
                D = reaction['D'] if 'D' in reaction else None
                E = reaction['E'] if 'E' in reaction else None
                Ea = reaction['Ea'] if 'Ea' in reaction else None

                reactants = []

                for reactant, reactant_info in reaction['reactants'].items():
                    match = filter(lambda x: x.name == reactant, species_from_json)
                    species = next(match, None)
                    quantity = reactant_info['qty'] if 'qty' in reactant_info else None

                    reactants.append(Reactant(species, quantity))

                products = []

                for product, product_info in reaction['products'].items():
                    match = filter(lambda x: x.name == product, species_from_json)
                    species = next(match, None)
                    yield_value = product_info['yield'] if 'yield' in product_info else None

                    products.append(Product(species, yield_value))

                reactions.append(Reaction(name, reaction_type, reactants, products, A, B, D, E, Ea))

            # Set initial conditions
            # make sure to convert the pressure units to atm
            pressure = 0
            if 'initial value [Pa]' in data['conditions']['environmental conditions']['pressure']:
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [Pa]']) / 101325
            elif 'initial value [atm]' in data['conditions']['environmental conditions']['pressure']:
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [atm]'])
            elif 'initial value [bar]' in data['conditions']['environmental conditions']['pressure']:
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [bar]']) * 0.986923
            elif 'initial value [kPa]' in data['conditions']['environmental conditions']['pressure']: 
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [kPa]']) / 101.325
            elif 'initial value [hPa]' in data['conditions']['environmental conditions']['pressure']:
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [hPa]']) / 1013.25
            elif 'initial value [mbar]' in data['conditions']['environmental conditions']['pressure']:
                pressure = float(data['conditions']['environmental conditions']['pressure']['initial value [mbar]']) / 1013.25

            # make sure to convert the temperature units to K
            temperature = 0
            if 'initial value [K]' in data['conditions']['environmental conditions']['temperature']:
                temperature = float(data['conditions']['environmental conditions']['temperature']['initial value [K]'])
            elif 'initial value [C]' in data['conditions']['environmental conditions']['temperature']:
                temperature = float(data['conditions']['environmental conditions']['temperature']['initial value [C]']) + 273.15
            elif 'initial value [F]' in data['conditions']['environmental conditions']['temperature']:
                temperature = (float(data['conditions']['environmental conditions']['temperature']['initial value [F]']) - 32) * 5/9 + 273.15

            species_concentrations = []
            for chem_spec, chem_spec_info in data['conditions']['chemical species'].items():
                match = filter(lambda x: x.name == chem_spec, species_from_json)
                species = next(match, None)

                # make sure to convert the concentration units to mol m-3
                concentration = 0
                if 'initial value [mol m-3]' in data['conditions']['chemical species'][chem_spec]:
                    concentration = float(chem_spec_info['initial value [mol m-3]'])
                elif 'initial value [mol cm-3]' in data['conditions']['chemical species'][chem_spec]:
                    concentration = float(chem_spec_info['initial value [mol cm-3]']) * 1e3
                elif 'initial value [molec m-3]' in data['conditions']['chemical species'][chem_spec]:
                    concentration = float(chem_spec_info['initial value [molec m-3]']) / 6.02214076e23
                elif 'initial value [molec cm-3]' in data['conditions']['chemical species'][chem_spec]:
                    concentration = float(chem_spec_info['initial value [molec cm-3]']) * 1e3 / 6.02214076e23

                species_concentrations.append(SpeciesConcentration(species, concentration))

            # TODO: Add reaction rates
            reaction_rates = []


            self.initial_conditions = Conditions(pressure, temperature, species_concentrations, reaction_rates)

            # Set evolving conditions
            time = []
            conditions = []

            headers = data['conditions']['evolving conditions'][0]

            evol_from_json = data['conditions']['evolving conditions']
            for i in range(1, len(evol_from_json)):
                time.append(evol_from_json[i][0])

                # TODO: Add species concentrations and reaction rates

# for testing purposes
def __main__():
    # Create a new instance of the BoxModel class.
    box_model = BoxModel()

    box_model.readFromJson("./pretty_json.json")

if __name__ == "__main__":
    __main__()