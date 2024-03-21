from typing import List
from music_box_reaction_rate import ReactionRate
from music_box_species_concentration import SpeciesConcentration
import utils

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

    @classmethod
    def from_UI_JSON(cls, UI_JSON, species_list, reaction_list):
        """
        Create a new instance of the Conditions class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object representing the conditions.

        Returns:
            Conditions: A new instance of the Conditions class.
        """
        pressure = utils.convert_pressure(UI_JSON['conditions']['environmental conditions']['pressure'], 'initial value')

        temperature = utils.convert_temperature(UI_JSON['conditions']['environmental conditions']['temperature'], 'initial value')

        # Set initial species concentrations
        species_concentrations = []
        for chem_spec in UI_JSON['conditions']['chemical species']:
            match = filter(lambda x: x.name == chem_spec, species_list.species)
            species = next(match, None)

            concentration = utils.convert_concentration(UI_JSON['conditions']['chemical species'][chem_spec], 'initial value')

            species_concentrations.append(SpeciesConcentration(species, concentration))

        # Set initial reaction rates
        reaction_rates = []

        for reaction in UI_JSON['conditions']['initial conditions']:
            match = filter(lambda x: x.name == reaction.split('.')[1], reaction_list.reactions)
            reaction_from_list = next(match, None)

            rate = UI_JSON['conditions']['initial conditions'][reaction]

            reaction_rates.append(ReactionRate(reaction_from_list, rate))

        return cls(pressure, temperature, species_concentrations, reaction_rates)

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
