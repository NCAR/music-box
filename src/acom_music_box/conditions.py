from .utils import convert_pressure, convert_temperature, convert_concentration
import pandas as pd
import numpy
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
        species_concentrations (dict[str, float]): A dictionary of species concentrations.
        rate_parameters (dict[str, float]): A dictionary of user-specified reaction rate parameters.
    """

    def __init__(
            self,
            pressure=None,
            temperature=None,
            species_concentrations=None,
            rate_parameters=None):
        """
        Initializes a new instance of the Conditions class.

        Args:
            pressure (float): The pressure of the conditions in atmospheres.
            temperature (float): The temperature of the conditions in Kelvin.
            species_concentrations (Dict[str, float]): A dictionary of species concentrations.
            rate_parameters (Dict[str, float]): A dictionary of user-specified reaction rate parameters.
        """
        self.pressure = pressure
        self.temperature = temperature
        self.species_concentrations = species_concentrations if species_concentrations is not None else {}
        self.rate_parameters = rate_parameters if rate_parameters is not None else {}

    def __repr__(self):
        return f"Conditions(pressure={self.pressure}, temperature={self.temperature}, species_concentrations={self.species_concentrations}, rate_parameters={self.rate_parameters})"

    def __str__(self):
        return f"Pressure: {self.pressure}, Temperature: {self.temperature}, Species Concentrations: {self.species_concentrations}, User-Defined Rate Parameters: {self.rate_parameters}"

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

            species_concentrations[species] = concentration

        for species in species_list.species:
            if not any(conc.species.name ==
                       species.name for conc in species_concentrations):
                species_concentrations[species] = 0

        # Set initial reaction rates
        rate_parameters = {}

        for reaction in UI_JSON['conditions']['initial conditions']:
            match = filter(
                lambda x: x.name == reaction.split('.')[1],
                reaction_list.reactions)
            reaction_from_list = next(match, None)

            rate_parameter = UI_JSON['conditions']['initial conditions'][reaction]

            rate_parameters[reaction_from_list] = rate_parameter

        return self(
            pressure,
            temperature,
            species_concentrations,
            rate_parameters)

    @classmethod
    def retrieve_initial_conditions_from_JSON(
            cls,
            path_to_json,
            json_object,
            reaction_types,
            preserve_type):
        """
        Retrieves initial conditions from CSV file and JSON structures.
        If both are present, JSON values will override the CSV values.

        This class method takes a path to a JSON file, a configuration JSON object,
        and a list of desired reaction types.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            json_object (dict): The configuration JSON object containing the initial conditions and settings.
            reaction_types: Use set like {"ENV"} for environmental conditions {"CONC"} for species concentrations, {"EMIS", "PHOTO"} for reaction rates.
            preserve_type: If True, keep the reaction type in the key name. If False, remove the reaction type from the key name.

        Returns:
            object: A dictionary of name:value pairs.
        """

        logger.debug(f"path_to_json: {path_to_json}   reaction_types: {reaction_types}")

        # look for that JSON section
        if (not 'initial conditions' in json_object):
            return ({})
        if (len(list(json_object['initial conditions'].keys())) == 0):
            return ({})

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

                file_initial_csv = Conditions.read_initial_conditions_from_file(
                    initial_conditions_path, reaction_types, preserve_type)
                logger.debug(f"file_initial_csv = {file_initial_csv}")

                # tranfer conditions from this file to the aggregated dictionary
                for one_csv in file_initial_csv:
                    # give warning if one file CSV overrides a prior CSV
                    if one_csv in initial_csv:
                        logger.warning(
                            "Value {}:{} in file {} will override prior value {}"
                            .format(one_csv, file_initial_csv[one_csv],
                                    initial_conditions_path, initial_csv[one_csv]))

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
            chem_name_alone = one_data.split(" [")[0]  # remove units
            if not preserve_type:
                chem_name_alone = chem_name_alone.split(".")[1]  # remove type prefix
            initial_csv[chem_name_alone] = initial_data[one_data]

        logger.debug(f"Overridden initial_csv = {initial_csv}")

        return (initial_csv)

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
        pressure = convert_pressure(
            json_object['environmental conditions']['pressure'],
            'initial value')

        temperature = convert_temperature(
            json_object['environmental conditions']['temperature'],
            'initial value')

        logger.debug(f"From original JSON temperature = {temperature}   pessure = {pressure}")

        # we will read environment, species concentrations, and reaction rates on three passes
        environmental_conditions = Conditions.retrieve_initial_conditions_from_JSON(
            path_to_json, json_object, {"ENV"}, False)
        species_concentrations = Conditions.retrieve_initial_conditions_from_JSON(
            path_to_json, json_object, {"CONC"}, False)
        rate_parameters = Conditions.retrieve_initial_conditions_from_JSON(
            path_to_json, json_object, {"EMIS", "PHOTO", "LOSS", "USER"}, True)

        # override presure and temperature
        if ("pressure" in environmental_conditions):
            pressure = environmental_conditions["pressure"]
        if ("temperature" in environmental_conditions):
            temperature = environmental_conditions["temperature"]

        logger.debug(f"Returning species_concentrations = {species_concentrations}")
        logger.debug(f"Returning user-defined rate parameters = {rate_parameters}")

        return self(
            pressure,
            temperature,
            species_concentrations,
            rate_parameters)

    @classmethod
    def read_initial_conditions_from_file(cls, file_path, react_types=None, preserve_type=False):
        """
        Reads initial user-defined rate parameters from a file.

        This class method takes a file path and a ReactionList, reads the file, and
        sets the initial rate parameters based on the contents of the file.

        Args:
            file_path (str): The path to the file containing the initial rate parameters.
            react_types = set of reaction types only to include, or None to include all.

        Returns:
            dict: A dictionary of initial user-defined rate parameters.
        """

        rate_parameters = {}

        df = pd.read_csv(file_path, skipinitialspace=True)
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
            parameter_name = f'{reaction_type}.{label}'
            if parameter_name in rate_parameters:
                raise ValueError(f"Duplicate user-defined rate parameter found: {parameter_name}")

            # are we looking for this type?
            if (react_types):
                if (reaction_type not in react_types):
                    continue

            # create key-value pair of chemical-concentration
            # initial concentration looks like this:        CONC.a-pinene [mol m-3]
            # reaction rate looks like this:                LOSS.SOA2 wall loss.s-1
            chem_name_alone = f"{reaction_type}.{label}" if preserve_type else label
            chem_name_alone = chem_name_alone.split(' [')[0]  # strip off [units] to get chemical
            rate_parameters[chem_name_alone] = df.at[0, key]  # retrieve (row, column)

        return rate_parameters

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

        # build the dictionary from the reaction columns
        header_row = data_json[0]
        value_row = data_json[1]
        data_values = {key: float(value) for key, value in zip(header_row, value_row)
                       if key.split('.')[0] in react_types}
        logger.debug(f"For {react_types} data_values = {data_values}")

        return data_values
