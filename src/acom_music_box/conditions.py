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
    def retrieve_initial_conditions_from_JSON(
            self,
            path_to_json,
            json_object,
            reaction_types):
        """
        Retrieves initial conditions from CSV file and JSON structures.
        If both are present, JSON values will override the CSV values.

        This class method takes a path to a JSON file, a configuration JSON object,
        and a list of desired reaction types.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            json_object (dict): The configuration JSON object containing the initial conditions and settings.
            reaction_types: Use set like {"ENV", "CONC"} for species concentrations, {"EMIS", "PHOTO"} for reaction rates.

        Returns:
            object: A dictionary of name:value pairs.
        """

        # look for that JSON section
        if (not 'initial conditions' in json_object):
            return({})
        if (len(list(json_object['initial conditions'].keys())) == 0):
            return({})

        # retrieve initial conditions from CSV and JSON
        initial_csv = {}
        initial_data = {}

        initCond = json_object['initial conditions']
        logger.debug(f"initCond: {initCond}")
        if 'filepaths' in initCond:
            file_paths = initCond['filepaths']

            # loop through the CSV files
            for file_path in file_paths:
                # read initial conditions from CSV file
                initial_conditions_path = os.path.join(
                    os.path.dirname(path_to_json), file_path)

                logger.debug(f"initial_conditions_path: {initial_conditions_path}")
                file_initial_csv = Conditions.read_initial_conditions_from_file(
                    initial_conditions_path, reaction_types)
                logger.debug(f"file_initial_csv = {file_initial_csv}")

                # tranfer conditions from this file to the aggregated dictionary
                for one_csv in file_initial_csv:
                    initial_csv[one_csv] = file_initial_csv[one_csv]

        logger.debug(f"initial_csv = {initial_csv}")

        if 'data' in initCond:
            # read initial conditions from in-place CSV (list of headers and list of values)
            dataConditions = initCond['data']
            initial_data = Conditions.read_data_values_from_table(dataConditions,
                reaction_types)
            logger.debug(f"initial_data = {initial_data}")

        # override the CSV species initial values with JSON data
        numCSV = len(initial_csv)
        numData = len(initial_data)
        if (numCSV > 0 and numData > 0):
            logger.warning(f"Initial data values ({numData}) from JSON will override initial values ({numCSV}) from CSV.")
        for one_data in initial_data:
            chem_name_alone = one_data.split(".")[1]        # remove reaction type
            chem_name_alone = chem_name_alone.split(" ")[0] # remove units
            initial_csv[chem_name_alone] = initial_data[one_data]

        logger.debug(f"Overridden initial_csv = {initial_csv}")

        return(initial_csv)


    @classmethod
    def from_config_JSON(
            self,
            path_to_json,
            json_object):
        """
        Creates an instance of the class from a configuration JSON object.

        This class method takes a path to a JSON file, a configuration JSON object, a species list,
        and a reaction list, and uses them to create a new instance of the class.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            json_object (dict): The configuration JSON object containing the initial conditions and settings.

        Returns:
            object: An instance of the Conditions class with the settings from the configuration JSON object.
        """
        logger.debug(f"path_to_json: {path_to_json}")
        pressure = convert_pressure(
            json_object['environmental conditions']['pressure'],
            'initial value')

        temperature = convert_temperature(
            json_object['environmental conditions']['temperature'],
            'initial value')

        # we will read species concentrations and reaction rates on two passes
        species_concentrations = Conditions.retrieve_initial_conditions_from_JSON(
            path_to_json, json_object, {"ENV", "CONC"})
        reaction_rates = Conditions.retrieve_initial_conditions_from_JSON(
            path_to_json, json_object, {"EMIS", "PHOTO", "LOSS"})

        # override presure and temperature
        if ("pressure" in species_concentrations):
            pressure = species_concentrations["pressure"]
        if ("temperature" in species_concentrations):
            temperature = species_concentrations["temperature"]

        logger.debug(f"Returning species_concentrations = {species_concentrations}")
        logger.debug(f"Returning reaction_rates = {reaction_rates}")

        return self(
            pressure,
            temperature,
            species_concentrations,
            reaction_rates)


    @classmethod
    def read_initial_conditions_from_file(cls, file_path, react_types=None):
        """
        Reads initial reaction rates from a file.

        This class method takes a file path and a ReactionList, reads the file, and
        sets the initial reaction rates based on the contents of the file.

        Args:
            file_path (str): The path to the file containing the initial reaction rates.
            react_types = set of reaction types only to include, or None to include all.

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

            # are we looking for this type?
            if (react_types):
                if (reaction_type not in react_types):
                    continue

            # create key-value pair of chemical-concentration
            chem_name_alone = label.split(' ')[0]           # strip off  [units]
            reaction_rates[chem_name_alone] = df.at[0, key] # retrieve (row, column)

        return reaction_rates

    @classmethod
    def read_data_values_from_table(cls, data_json, react_types=None):
        """
        Reads data values from a CSV-type table expressed in JSON.

        This class method takes a JSON element, reads two rows, and
        sets variable names and values to the header and value rows.
        Example of the data:
            "data": [
                ["ENV.temperature [K]", "ENV.pressure [Pa]", "CONC.A [mol m-3]", "CONC.B [mol m-3]"],
                [200, 70000, 0.67, 2.3e-9]
            ]

        Args:
            data_json (object): JSON list of two lists.
            react_types = set of reaction types only to include, or None to include all.

        Returns:
            dict: A dictionary of initial data values.
        """

        data_values = {}

        rows = len(data_json)
        if rows != 2:
            raise ValueError(f'Initial conditions data in JSON ({data_json}) should have only header and value rows. There are {rows} rows present.')

        # build the dictionary from the columns
        header_row = data_json[0]
        value_row = data_json[1]
        for header, value in zip(header_row, value_row):
            # are we looking for this type?
            if (react_types):
                header_type = header.split('.')[0]
                if (header_type not in react_types):
                    continue

            data_values[header] = float(value)

        return data_values

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
