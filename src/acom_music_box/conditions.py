from .utils import convert_pressure, convert_temperature, convert_concentration
import pandas as pd
import os

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
            species_concentrations (Dict[Species, float]): A dictionary of species concentrations.
            reaction_rates (Dict[Reaction, float]): A dictionary of reaction rates.
        """
        self.pressure = pressure
        self.temperature = temperature
        self.species_concentrations = species_concentrations if species_concentrations is not None else {}
        self.reaction_rates = reaction_rates if reaction_rates is not None else {}

    def __repr__(self):
        return f"Conditions(pressure={self.pressure}, temperature={self.temperature}, species_concentrations={self.species_concentrations}, reaction_rates={self.reaction_rates})"

    def __str__(self):
        return f"Pressure: {self.pressure}, Temperature: {self.temperature}, Species Concentrations: {self.species_concentrations}, Reaction Rates: {self.reaction_rates}"

    @classmethod
    def from_UI_JSON(self, UI_JSON, species_list, reaction_list):
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

        return self(
            pressure,
            temperature,
            species_concentrations,
            reaction_rates)

    @classmethod
    def from_config_JSON(
            self,
            path_to_json,
            object):
        """
        Creates an instance of the class from a configuration JSON object.

        This class method takes a path to a JSON file, a configuration JSON object, a species list,
        and a reaction list, and uses them to create a new instance of the class.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            object (dict): The configuration JSON object containing the initial conditions and settings.

        Returns:
            object: An instance of the Conditions class with the settings from the configuration JSON object.
        """
        pressure = convert_pressure(
            object['environmental conditions']['pressure'],
            'initial value')

        temperature = convert_temperature(
            object['environmental conditions']['temperature'],
            'initial value')

        # Set initial species concentrations
        initial_concentrations = {}
        reaction_rates = {}

        # reads initial conditions from csv if it is given
        if 'initial conditions' in object and len(
                list(object['initial conditions'].keys())) > 0:

            initial_conditions_path = os.path.join(
                os.path.dirname(path_to_json),
                list(object['initial conditions'].keys())[0])

            reaction_rates = Conditions.read_initial_rates_from_file(
                initial_conditions_path)

        # reads from config file directly if present
        if 'chemical species' in object:
            initial_concentrations = {
                species: convert_concentration(
                    object['chemical species'][species], 'initial value', temperature, pressure
                )
                for species in object['chemical species']
            }

        return self(
            pressure,
            temperature,
            initial_concentrations,
            reaction_rates)

    @classmethod
    def read_initial_rates_from_file(cls, file_path):
        """
        Reads initial reaction rates from a file.

        This class method takes a file path and a ReactionList, reads the file, and
        sets the initial reaction rates based on the contents of the file.

        Args:
            file_path (str): The path to the file containing the initial reaction rates.

        Returns:
            dict: A dictionary of initial reaction rates.
        """

        reaction_rates = {}

        df = pd.read_csv(file_path)
        rows, _ = df.shape
        if rows > 1:
            raise ValueError(f'Initial conditions file ({file_path}) may only have one row of data. There are {rows} rows present.')
        for key in df.columns:
            parts = key.split('.')
            reaction_type, label = None, None
            if len(parts) == 3:
                reaction_type, label, units = parts
            elif len(parts) == 2:
                reaction_type, label = parts
            else:
                error = f"Unexpected format in key: {key}"
                logger.error(error)
                raise ValueError(error)
            rate_name = f'{reaction_type}.{label}'
            if rate_name in reaction_rates:
                raise ValueError(f"Duplicate reaction rate found: {rate_name}")
            reaction_rates[rate_name] = df.iloc[0][key]

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
        self.species_concentrations.update(new_conditions.species_concentrations)

        self.reaction_rates.update(new_conditions.reaction_rates)
