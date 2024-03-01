from typing import List

class Conditions:
    """
    Represents conditions for a simulation with attributes such as pressure, temperature, species concentrations,
    and reaction rates.

    Attributes:
        pressure (float): The pressure of the conditions in atmospheres.
        temperature (float): The temperature of the conditions in Kelvin.
        speciesConcentrations (List[SpeciesConcentration]): A list of species concentrations.
        reactionRates (List[ReactionRate]): A list of reaction rates.
    """

    def __init__(self, pressure, temperature, species_concentrations=None, reaction_rates=None):
        """
        Initializes a new instance of the Conditions class.

        Args:
            pressure (float): The pressure of the conditions in atmospheres.
            temperature (float): The temperature of the conditions in Kelvin.
            species_concentrations (List[SpeciesConcentration]): A list of species concentrations. Default is an empty list.
            reaction_rates (List[ReactionRate]): A list of reaction rates. Default is an empty list.
        """
        self.pressure = pressure
        self.temperature = temperature
        self.species_concentrations = species_concentrations if species_concentrations is not None else []
        self.reaction_rates = reaction_rates if reaction_rates is not None else []

    def add_species_concentration(self, species_concentration):
        """
        Add a SpeciesConcentration instance to the list of species concentrations.

        Args:
            species_concentration (SpeciesConcentration): The SpeciesConcentration instance to be added.
        """
        self.species_concentration.append(species_concentration)

    def add_reaction_rate(self, reaction_rate):
        """
        Add a ReactionRate instance to the list of reaction rates.

        Args:
            reaction_rate (ReactionRate): The ReactionRate instance to be added.
        """
        self.reaction_rates.append(reaction_rate)
