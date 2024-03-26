import json

from music_box_evolving_conditions import EvolvingConditions
from music_box_reaction_list import ReactionList
from music_box_reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
from music_box_reactant import Reactant
from music_box_product import Product
from music_box_species_list import SpeciesList
from music_box_species import Species
from music_box_model_options import BoxModelOptions
from music_box_conditions import Conditions
from music_box_species_concentration import SpeciesConcentration
from music_box_reaction_rate import ReactionRate
import csv
import musica

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
        self.species_list = species_list if species_list is not None else []
        self.reaction_list = reaction_list if reaction_list is not None else []
        self.initial_conditions = initial_conditions
        self.evolving_conditions = evolving_conditions if evolving_conditions is not None else []
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

            if not isinstance(reaction, Branched):
                products = {}

                #Adds products
                for product in reaction.products:
                    yield_value = {}

                    #Adds product yield if value is set
                    if product.yield_value != None:
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
                    if alkoxy_product.yield_value != None:
                        yield_value["yield"] = alkoxy_product.yield_value
                    alkoxy_products[alkoxy_product.name] = yield_value
                
                reac["alkoxy products"] = alkoxy_products

                nitrate_products = {}

                # Adds nitrate products
                for nitrate_product in reaction.nitrate_products:
                    yield_value = {}

                    # Adds nitrate product yield if value is set
                    if nitrate_product.yield_value != None:
                        yield_value["yield"] = nitrate_product.yield_value
                    nitrate_products[nitrate_product.name] = yield_value
                
                reac["nitrate products"] = nitrate_products

                # Adds parameters for the reaction
                reac["X"] = reaction.X
                reac["Y"] = reaction.Y
                reac["a0"] = reaction.a0
                reac["n"] = reaction.n
            
            elif isinstance(reaction, Arrhenius):
                # Adds parameters for the reaction
                reac["A"] = reaction.A
                reac["B"] = reaction.B
                reac["D"] = reaction.D
                reac["E"] = reaction.E
                reac["Ea"] = reaction.Ea
            
            elif isinstance(reaction, Tunneling):
                # Adds parameters for the reaction
                reac["A"] = reaction.A
                reac["B"] = reaction.B
                reac["C"] = reaction.C
            
            elif isinstance(reaction, Troe_Ternary):
                # Adds parameters for the reaction
                reac["k0_A"] = reaction.k0_A
                reac["k0_B"] = reaction.k0_B
                reac["k0_C"] = reaction.k0_C
                reac["kinf_A"] = reaction.kinf_A
                reac["kinf_B"] = reaction.kinf_B
                reac["kinf_C"] = reaction.kinf_C
                reac["Fc"] = reaction.Fc
                reac["N"] = reaction.N
            
            #Adds reaction name if value is set
            if(reaction.name != None):
                reac["MUSICA name"] = reaction.name

            reactionsArray.append(reac)

        reacList["reactions"] = reactionsArray

        reactionsJson = {
            "camp-data" : [reacList]
        }

        return json.dumps(reactionsJson)
    
    def create_solver(self, path_to_config):
        """
        Creates a micm solver object using the CAMP configuration files.

        Args:
            path_to_config (str): The path to CAMP configuration directory.

        Returns:
            None
        """
        # Create a solver object using the configuration file
        self.solver = musica.create_micm(path_to_config)


    def solve(self, path_to_output = None):
        """
        TODO: Solve the box model simulation.
        """
        # TODO: Implement the logic to solve the box model simulation.
        # Update the internal state of the BoxModel instance to reflect the simulation results.

        #sets up initial conditions to be current conditions
        curr_conditions = self.initial_conditions

        #sets up initial concentraion values
        curr_concentrations = self.initial_conditions.get_concentration_array()

        #sets up next condition if evolving conditions is not empty
        next_conditions = None
        next_conditions_time = 0
        next_conditions_index = 0
        if(len(self.evolving_conditions) != 0):
            next_conditions_index = 0
            next_conditions = self.evolving_conditions.conditions[0]
            next_conditions_time = self.evolving_conditions.times[0]

        #initializes file headers if output file is present
        output_array = []
        if(path_to_output != None):
            headers = []
            headers.append("time")
            headers.append("ENV.temperature")
            headers.append("ENV.pressure")
            for spec in self.species_list:
                headers.append("CONC." + spec.name)
            
            output_array.append(headers)
        
        #runs the simulation at each timestep
        curr_time = 0
        while(curr_time <= self.box_model_options.simulation_length):

            #appends row to output if file is present
            if(path_to_output != None):
                row = []
                row.append(curr_time)
                row.append(curr_conditions.temperature)
                row.append(curr_conditions.pressure)
                for conc in curr_concentrations:
                    row.append(conc)
                output_array.append(row)

            #iterates evolvings conditons if enough time has elapsed
            if(next_conditions != None and next_conditions_time <= curr_time):
                curr_conditions = next_conditions

                #iterates next_conditions if there are remaining evolving conditions
                if(len(self.evolving_conditions) > next_conditions_index + 1):
                    next_conditions_index += 1
                    next_conditions = self.evolving_conditions.conditions[next_conditions_index]
                    next_conditions_time = self.evolving_conditions.times[next_conditions_index]

                    #overrides concentrations if specified by conditions
                    if(len(curr_conditions.get_concentration_array()) != 0):
                        curr_concentrations = curr_conditions.get_concentration_array()
                else:
                    next_conditions = None

            #solves and updates concentration values in concentration array
            musica.micm_solve(self.solver, self.box_model_options.chem_step_time, curr_conditions.temperature, curr_conditions.pressure, curr_concentrations)

            
                

            #increments time
            curr_time += self.box_model_options.chem_step_time  
        
        #outputs to file if output is present
        if(path_to_output != None):
            with open(path_to_output, 'w', newline='') as output:
                writer = csv.writer(output)
                writer.writerows(output_array)
        
    def readFromUIJson(self, path_to_json):
        """
        TODO: Read the box model configuration from json and sets config
        """
        # TODO: Implement the logic to update the box model config using a json.

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)

            # Set box model options
            self.box_model_options = BoxModelOptions.from_UI_JSON(data)

            # Set species list
            self.species_list = SpeciesList.from_UI_JSON(data)

            # Set reaction list
            self.reaction_list = ReactionList.from_UI_JSON(data, self.species_list)

            # Set initial conditions
            self.initial_conditions = Conditions.from_UI_JSON(data, self.species_list, self.reaction_list)

            # Set evolving conditions
            self.evolving_conditions = EvolvingConditions.from_UI_JSON(data, self.species_list, self.reaction_list)    

    def readConditionsFromJson(self, path_to_json):

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)
            # Set box model options
            self.box_model_options = BoxModelOptions.from_config_JSON(data)

            # Set initial conditions
            self.initial_conditions = Conditions.from_config_JSON(data)


# for testing purposes
def __main__():
    # Create a new instance of the BoxModel class.

    pass




if __name__ == "__main__":
    __main__()