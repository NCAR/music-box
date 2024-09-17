import csv
import os
from typing import List
from .conditions import Conditions
from .species_concentration import SpeciesConcentration
from .reaction_rate import ReactionRate


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

    @classmethod
    def from_config_JSON(
            cls,
            path_to_json,
            config_JSON,
            species_list,
            reaction_list):
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
        if 'evolving conditions' in config_JSON:
            if len(config_JSON['evolving conditions'].keys()) > 0:
                # Construct the path to the evolving conditions file

                evolving_conditions_path = os.path.join(
                    os.path.dirname(path_to_json),
                    list(config_JSON['evolving conditions'].keys())[0])

                evolving_conditions = EvolvingConditions.read_conditions_from_file(
                    evolving_conditions_path, species_list, reaction_list)

        return evolving_conditions

    def add_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition.
            conditions (Conditions): The associated conditions at the given time point.
        """
        self.time.append(time_point)
        self.conditions.append(conditions)

    @classmethod
    def read_conditions_from_file(cls, file_path, species_list, reaction_list):
        """
        TODO: Read conditions from a file and update the evolving conditions.

        Args:
            file_path (str): The path to the file containing conditions UI_JSON.
        """

        times = []
        conditions = []

        # Open the evolving conditions file and read it as a CSV
        with open(file_path, 'r') as csv_file:
            evolving_conditions = list(csv.reader(csv_file))

            if (len(evolving_conditions) > 1):
                # The first row of the CSV contains headers
                headers = evolving_conditions[0]

                # Iterate over the remaining rows of the CSV
                for i in range(1, len(evolving_conditions)):
                    # The first column of each row is a time value
                    times.append(float(evolving_conditions[i][0]))

                    # Initialize pressure and temperature as None
                    pressure = None
                    temperature = None

                    # If pressure and temperature headers are present in the
                    # CSV, extract their values
                    if 'ENV.pressure.Pa' in headers:
                        pressure = float(
                            evolving_conditions[i][headers.index('ENV.pressure.Pa')])
                    if 'ENV.temperature.K' in headers:
                        temperature = float(
                            evolving_conditions[i][headers.index('ENV.temperature.K')])

                    # Initialize concentrations list and extract concentration
                    # headers
                    concentrations = []
                    concentration_headers = list(
                        filter(lambda x: 'CONC' in x, headers))

                    # For each concentration header, find the matching species
                    # and append its concentration to the list
                    for j in range(len(concentration_headers)):
                        match = filter(
                            lambda x: x.name == concentration_headers[j].split('.')[1],
                            species_list.species)
                        species = next(match, None)
                        concentration = float(
                            evolving_conditions[i][headers.index(concentration_headers[j])])

                        concentrations.append(
                            SpeciesConcentration(
                                species, concentration))

                    # Initialize rates list and extract rate headers
                    rates = []
                    rate_headers = list(filter(lambda x: 's-1' in x, headers))

                    # For each rate header, find the matching reaction and
                    # append its rate to the list
                    for k in range(len(rate_headers)):
                        name_to_match = rate_headers[k].split('.')

                        if name_to_match[0] == 'LOSS' or name_to_match[0] == 'EMIS':
                            name_to_match = name_to_match[0] + \
                                '_' + name_to_match[1]
                        else:
                            name_to_match = name_to_match[1]
                        match = filter(
                            lambda x: x.name == name_to_match,
                            reaction_list.reactions)
                        reaction = next(match, None)
                        rate = float(
                            evolving_conditions[i][headers.index(rate_headers[k])])
                        rates.append(ReactionRate(reaction, rate))

                    # Append the conditions for this time point to the
                    # conditions list
                    conditions.append(
                        Conditions(
                            pressure,
                            temperature,
                            concentrations,
                            rates))

        # Return a new instance of the class with the times and conditions

        return cls(times=times, conditions=conditions)

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
