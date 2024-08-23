from .utils import convert_time, convert_pressure, convert_temperature, convert_concentration
from .species_concentration import SpeciesConcentration
from .species import Species
from .reaction_rate import ReactionRate
from typing import List
import csv
import os
from typing import List
from .reaction_rate import ReactionRate
from .species import Species
from .species_concentration import SpeciesConcentration
from .utils import convert_time, convert_pressure, convert_temperature, convert_concentration

import logging
logger = logging.getLogger(__name__)


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

    def __init__(
            self,
            pressure=None,
            temperature=None,
            species_concentrations=None,
            reaction_rates=None):
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

    def __repr__(self):
        return f"Conditions(pressure={self.pressure}, temperature={self.temperature}, species_concentrations={self.species_concentrations}, reaction_rates={self.reaction_rates})"

    def __str__(self):
        return f"Pressure: {self.pressure}, Temperature: {self.temperature}, Species Concentrations: {self.species_concentrations}, Reaction Rates: {self.reaction_rates}"

    @classmethod
    def from_UI_JSON(cls, UI_JSON, species_list, reaction_list):
        """
        Creates an instance of the class from a UI JSON object.

        This class method takes a UI JSON object, a species list, and a reaction list,
        and uses them to create a new instance of the class.

        Args:
            UI_JSON (dict): The UI JSON object containing the initial conditions and settings.
            species_list (SpeciesList): A SpeciesList containing the species involved in the simulation.
            reaction_list (ReactionList): A ReactionList containing the reactions involved in the simulation.

        Returns:
            object: An instance of the Conditions class with the settings from the UI JSON object.
        """
        pressure = convert_pressure(
            UI_JSON['conditions']['environmental conditions']['pressure'],
            'initial value')

        temperature = convert_temperature(
            UI_JSON['conditions']['environmental conditions']['temperature'],
            'initial value')

        # Set initial species concentrations
        species_concentrations = []
        for chem_spec in UI_JSON['conditions']['chemical species']:
            match = filter(lambda x: x.name == chem_spec, species_list.species)
            species = next(match, None)

            concentration = convert_concentration(
                UI_JSON['conditions']['chemical species'][chem_spec], 'initial value')

            species_concentrations.append(
                SpeciesConcentration(
                    species, concentration))

        for species in species_list.species:
            if not any(conc.species.name ==
                       species.name for conc in species_concentrations):
                species_concentrations.append(SpeciesConcentration(species, 0))

        # Set initial reaction rates
        reaction_rates = []

        for reaction in UI_JSON['conditions']['initial conditions']:
            match = filter(
                lambda x: x.name == reaction.split('.')[1],
                reaction_list.reactions)
            reaction_from_list = next(match, None)

            rate = UI_JSON['conditions']['initial conditions'][reaction]

            reaction_rates.append(ReactionRate(reaction_from_list, rate))

        return cls(
            pressure,
            temperature,
            species_concentrations,
            reaction_rates)

    @classmethod
    def from_config_JSON(
            cls,
            path_to_json,
            config_JSON,
            species_list,
            reaction_list):
        """
        Creates an instance of the class from a configuration JSON object.

        This class method takes a path to a JSON file, a configuration JSON object, a species list,
        and a reaction list, and uses them to create a new instance of the class.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            config_JSON (dict): The configuration JSON object containing the initial conditions and settings.
            species_list (SpeciesList): A SpeciesList containing the species involved in the simulation.
            reaction_list (ReactionList): A ReactionList containing the reactions involved in the simulation.

        Returns:
            object: An instance of the Conditions class with the settings from the configuration JSON object.
        """
        pressure = convert_pressure(
            config_JSON['environmental conditions']['pressure'],
            'initial value')

        temperature = convert_temperature(
            config_JSON['environmental conditions']['temperature'],
            'initial value')

        # Set initial species concentrations
        species_concentrations = []
        reaction_rates = []

        # reads initial conditions from csv if it is given
        if 'initial conditions' in config_JSON and len(
                list(config_JSON['initial conditions'].keys())) > 0:

            initial_conditions_path = os.path.dirname(
                path_to_json) + "/" + list(config_JSON['initial conditions'].keys())[0]
            reaction_rates = Conditions.read_initial_rates_from_file(
                initial_conditions_path, reaction_list)

        # reads from config file directly if present
        if 'chemical species' in config_JSON:
            for chem_spec in config_JSON['chemical species']:
                species = Species(name=chem_spec)
                concentration = convert_concentration(
                    config_JSON['chemical species'][chem_spec], 'initial value')

                species_concentrations.append(
                    SpeciesConcentration(
                        species, concentration))

        for species in species_list.species:
            if species.tracer_type == 'THIRD_BODY':
                continue
            if not any(conc.species.name ==
                       species.name for conc in species_concentrations):
                species_concentrations.append(SpeciesConcentration(species, 0))

        # Set initial reaction rates
        for reaction in reaction_list.reactions:
            if (reaction.name is None):
                continue
            reaction_exists = False
            for rate in reaction_rates:
                if rate.reaction.name == reaction.name:
                    reaction_exists = True
                    break

            if not reaction_exists:
                reaction_rates.append(ReactionRate(reaction, 0))

        return cls(
            pressure,
            temperature,
            species_concentrations,
            reaction_rates)

    @classmethod
    def read_initial_rates_from_file(cls, file_path, reaction_list):
        """
        Reads initial reaction rates from a file.

        This class method takes a file path and a ReactionList, reads the file, and
        sets the initial reaction rates based on the contents of the file.

        Args:
            file_path (str): The path to the file containing the initial reaction rates.
            reaction_list (ReactionList): A ReactionList containing the reactions involved in the simulation.

        Returns:
            list: A list where each element represents the initial rate of a reaction.
        """

        reaction_rates = []

        with open(file_path, 'r') as csv_file:
            initial_conditions = list(csv.reader(csv_file))

            if (len(initial_conditions) > 1):
                # The first row of the CSV contains headers
                headers = initial_conditions[0]

                # The second row of the CSV contains rates
                rates = initial_conditions[1]

                for reaction_rate, rate in zip(headers, rates):
                    type, name, *rest = reaction_rate.split('.')
                    for reaction in reaction_list.reactions:
                        if reaction.name == name and reaction.short_type() == type:
                            reaction_rates.append(ReactionRate(reaction, rate))

        return reaction_rates

    def add_species_concentration(self, species_concentration):
        """
        Add a SpeciesConcentration instance to the list of species concentrations.

        Args:
            species_concentration (SpeciesConcentration): The SpeciesConcentration instance to be added.
        """
        self.species_concentrations.append(species_concentration)

    def add_reaction_rate(self, reaction_rate):
        """
        Add a ReactionRate instance to the list of reaction rates.

        Args:
            reaction_rate (ReactionRate): The ReactionRate instance to be added.
        """
        self.reaction_rates.append(reaction_rate)

    def get_concentration_array(self):
        """
        Retrieves an array of concentrations from the species_concentrations list.

        Returns:
            list: An array containing concentrations of each species.

        Notes:
            This function extracts the concentration attribute from each SpeciesConcentration object in
            the species_concentrations list and returns them as a single array to be used by the micm solver.
        """
        concentration_array = []
        for species_concentration in self.species_concentrations:
            concentration_array.append(species_concentration.concentration)

        return concentration_array

    def get_reaction_rate_array(self):
        """
        Retrieves an array of reaction rates from the reaction_rates list.

        Returns:
            list: An array containing reaction rates for each reaction.

        Notes:
            This function extracts the rate attribute from each ReactionRate object in
            the reaction_rates list and returns them as a single array to be used by the micm solver.
        """
        rate_array = []
        for reaction_rate in self.reaction_rates:
            rate_array.append(reaction_rate.rate)

        return rate_array

    def update_conditions(self, new_conditions):
        """
        Updates the conditions with new conditions when evolving conditions are present.

        Args:
            new_conditions (Conditions): The new conditions to be updated.
        """
        if new_conditions.pressure is not None:
            self.pressure = new_conditions.pressure
        if new_conditions.temperature is not None:
            self.temperature = new_conditions.temperature
        for conc in new_conditions.species_concentrations:
            match = filter(
                lambda x: x.species.name == conc.species.name,
                self.species_concentrations)
            for item in list(match):
                item.concentration = conc.concentration

        for rate in new_conditions.reaction_rates:

            match = filter(
                lambda x: x.reaction.name == rate.reaction.name,
                self.reaction_rates)

            for item in list(match):
                item.rate = rate.rate
