import pandas as pd
import os
import re
from .conditions import Conditions

import logging
logger = logging.getLogger(__name__)


class EvolvingConditions:
    """
    Represents evolving conditions with attributes such as time and associated conditions.

    Attributes:
        time (List[float]): A list of time points.
        conditions (List[Conditions]): A list of associated conditions.
    """

    def __init__(self, headers=None, times=None, conditions=None):
        """
        Initializes an instance of the EvolvingConditions class.

        Args:
            headers (list, optional): A list of headers for the data. Defaults to None.
            times (list, optional): A list of times at which the conditions are recorded. Defaults to None.
            conditions (list, optional): A list of conditions at each time point. Defaults to None.
        """
        self.headers = headers if headers is not None else []
        self.times = times if times is not None else []
        self.conditions = conditions if conditions is not None else []

    @classmethod
    def from_UI_JSON(cls, UI_JSON, species_list, reaction_list):
        """
        Create a new instance of the EvolvingConditions class from a JSON object.

        Args:
        UI_JSON (dict): A JSON object representing the evolving conditions.

        Returns:
            EvolvingConditions: A new instance of the EvolvingConditions class.
        """
        times = []
        conditions = []

        headers = UI_JSON['conditions']['evolving conditions'][0]

        evol_from_json = UI_JSON['conditions']['evolving conditions']
        for i in range(1, len(evol_from_json)):
            times.append(float(evol_from_json[i][0]))

            pressure = None
            if 'ENV.pressure.Pa' in headers:
                pressure = float(
                    evol_from_json[i][headers.index('ENV.pressure.Pa')])

            temperature = None
            if 'ENV.temperature.K' in headers:
                temperature = float(
                    evol_from_json[i][headers.index('ENV.temperature.K')])

            concentrations = []
            concentration_headers = list(
                filter(lambda x: 'CONC' in x, headers))
            for j in range(len(concentration_headers)):
                match = filter(
                    lambda x: x.name == concentration_headers[j].split('.')[1],
                    species_list.species)
                species = next(match, None)

                concentration = float(
                    evol_from_json[i][headers.index(concentration_headers[j])])
                concentrations.append(
                    SpeciesConcentration(
                        species, concentration))

            rates = []
            rate_headers = list(filter(lambda x: 's-1' in x, headers))
            for k in range(len(rate_headers)):
                name_to_match = rate_headers[k].split('.')

                if name_to_match[0] == 'LOSS' or name_to_match[0] == 'EMIS':
                    name_to_match = name_to_match[0] + '_' + name_to_match[1]
                else:
                    name_to_match = name_to_match[1]

                match = filter(
                    lambda x: x.name == name_to_match,
                    reaction_list.reactions)
                reaction = next(match, None)

                rate = float(evol_from_json[i][headers.index(rate_headers[k])])
                rates.append(ReactionRate(reaction, rate))

            conditions.append(
                Conditions(
                    pressure,
                    temperature,
                    concentrations,
                    rates))

        return cls(headers, times, conditions)

    @staticmethod
    def from_config_JSON(
            path_to_json,
            config_JSON):
        """
        Creates an instance of the EvolvingConditions class from a configuration JSON object.

        This class method takes a path to a JSON file, a configuration JSON object, a SpeciesList,
        and a ReactionList, and uses them to create a new instance of the EvolvingConditions class.

        Args:
            path_to_json (str): The path to the JSON file containing the initial conditions and settings.
            config_JSON (dict): The configuration JSON object containing the initial conditions and settings.
            species_list (SpeciesList): A SpeciesList containing the species involved in the simulation.
            reaction_list (ReactionList): A ReactionList containing the reactions involved in the simulation.

        Returns:
            EvolvingConditions: An instance of the EvolvingConditions class with the settings from the configuration JSON object.
        """

        evolving_conditions = EvolvingConditions()

        # Check if 'evolving conditions' is a key in the JSON config
        if (not 'evolving conditions' in config_JSON):
            return (evolving_conditions)
        if (len(list(config_JSON['evolving conditions'].keys())) == 0):
            return (evolving_conditions)

        evolveCond = config_JSON['evolving conditions']
        logger.debug(f"evolveCond: {evolveCond}")
        if 'filepaths' in evolveCond:
            file_paths = evolveCond['filepaths']

            # loop through the CSV files
            allReactions = set()        # provide warning for duplicates that will override
            for file_path in file_paths:
                # read initial conditions from CSV file
                evolving_conditions_path = os.path.join(
                    os.path.dirname(path_to_json), file_path)

                fileReactions = evolving_conditions.read_conditions_from_file(
                    evolving_conditions_path)
                logger.debug(f"evolving_conditions.times = {evolving_conditions.times}")
                logger.debug(f"evolving_conditions.conditions = {evolving_conditions.conditions}")

                # any duplicate conditions?
                overrideSet = allReactions.intersection(fileReactions)
                if (len(overrideSet) > 0):
                    logger.warning("File {} will override earlier conditions {}"
                                   .format(file_path, sorted(overrideSet)))
                allReactions = allReactions.union(fileReactions)

        return evolving_conditions

    def add_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.
        Keep the two lists sorted in order by time.
        New arrivals will probably come at the end of the list.

        Args:
            time_point (float): The time point for the evolving condition.
            conditions (Conditions): The associated conditions at the given time point.
        """
        # Work backward from end of list, looking for first time <= this new time.
        timeIndex = len(self.times)
        while (timeIndex > 0
               and self.times[timeIndex - 1] > time_point):
            timeIndex -= 1

        self.times.insert(timeIndex, time_point)
        self.conditions.insert(timeIndex, conditions)

    def read_conditions_from_file(self, file_path):
        """
        Read conditions from a file and update the evolving conditions.

        Args:
            file_path (str): The path to the file containing conditions UI_JSON.

        Returns:
            set: the headers read from the CSV file;
                used for warning about condition overrides
        """

        df = pd.read_csv(file_path, skipinitialspace=True)
        header_set = set(df.columns)

        # if present these columns must use these names
        pressure_key = 'ENV.pressure.Pa'
        temperature_key = 'ENV.temperature.K'
        time_key = 'time.s'

        header_set.remove(time_key)

        time_and_environment_keys = [pressure_key, temperature_key, time_key]
        # other keys will depend on the species names and reaction labels configured in the mechanism
        other_keys = [key for key in df.columns if key not in time_and_environment_keys]

        for _, row in df.iterrows():
            pressure = row[pressure_key] if pressure_key in row else None
            temperature = row[temperature_key] if temperature_key in row else None
            time = row[time_key]

            reaction_rates = {}
            species_concentrations = {}

            for key in other_keys:
                parts = key.split('.')
                condition_type, label, unit = None, None, None
                if len(parts) == 3:
                    condition_type, label, unit = parts
                elif len(parts) == 2:
                    condition_type, label = parts
                else:
                    error = f"Unexpected format in key: {key}"
                    logger.error(error)
                    raise ValueError(error)

                if condition_type == 'CONC':
                    species_concentrations[label] = row[key]
                else:
                    reaction_rates[f'{condition_type}.{label}'] = row[key]

            self.add_condition(time,
                               Conditions(
                                   pressure,
                                   temperature,
                                   species_concentrations,
                                   reaction_rates
                               )
                               )

        return (header_set)

    # allows len overload for this class

    def __len__(self):
        """
        Returns the number of time points in the EvolvingConditions instance.

        This method is a part of Python's data model methods and allows the built-in
        `len()` function to work with an instance of the EvolvingConditions class.
        It should return the number of time points for which conditions are recorded.

        Returns:
            int: The number of time points in the EvolvingConditions instance.
        """
        return len(self.times)
