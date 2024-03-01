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

    def readFromJson(self):
        """
        TODO: Read the box model configuration from json and sets config
        """
        # TODO: Implement the logic to update the box model config using a json.
        pass

    
