from typing import List
from music_box_conditions import Conditions
from music_box_species_concentration import SpeciesConcentration
from music_box_reaction_rate import ReactionRate

class EvolvingConditions:
    """
    Represents evolving conditions with attributes such as time and associated conditions.

    Attributes:
        time (List[float]): A list of time points.
        conditions (List[Conditions]): A list of associated conditions.
    """

    def __init__(self, time=None, conditions=None):
        """
        Initializes a new instance of the EvolvingConditions class.

        Args:
            time (List[float]): A list of time points. Default is an empty list.
            conditions (List[Conditions]): A list of associated conditions. Default is an empty list.
        """
        self.time = time if time is not None else []
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
        time = []
        conditions = []

        headers = UI_JSON['conditions']['evolving conditions'][0]

        evol_from_json = UI_JSON['conditions']['evolving conditions']
        for i in range(1, len(evol_from_json)):
            time.append(evol_from_json[i][0])

            pressure = None
            if 'ENV.pressure.Pa' in headers:
                pressure = float(evol_from_json[i][headers.index('ENV.pressure.Pa')]) / 101325

            temperature = None
            if 'ENV.temperature.K' in headers:
                temperature = float(evol_from_json[i][headers.index('ENV.temperature.K')])

            concentrations = []
            concentration_headers = list(filter(lambda x: 'CONC' in x, headers))
            for j in range(len(concentration_headers)):
                match = filter(lambda x: x.name == concentration_headers[j].split('.')[1], species_list.species)
                species = next(match, None)

                concentration = float(evol_from_json[i][headers.index(concentration_headers[j])])
                concentrations.append(SpeciesConcentration(species, concentration))

            rates = []
            rate_headers = list(filter(lambda x: 's-1' in x, headers))
            for k in range(len(rate_headers)):
                name_to_match = rate_headers[k].split('.')

                if name_to_match[0] == 'LOSS' or name_to_match[0] == 'EMIS':
                    name_to_match = name_to_match[0] + '_' + name_to_match[1]
                else:
                    name_to_match = name_to_match[1]

                match = filter(lambda x: x.name == name_to_match, reaction_list.reactions)
                reaction = next(match, None)

                rate = float(evol_from_json[i][headers.index(rate_headers[k])])
                rates.append(ReactionRate(reaction, rate))

            conditions.append(Conditions(pressure, temperature, concentrations, rates))

        return cls(time, conditions)

    def add_condition(self, time_point, conditions):
        """
        Add an evolving condition at a specific time point.

        Args:
            time_point (float): The time point for the evolving condition.
            conditions (Conditions): The associated conditions at the given time point.
        """
        self.time.append(time_point)
        self.conditions.append(conditions)
    
    def read_conditions_from_file(self, file_path):
        """
        TODO: Read conditions from a file and update the evolving conditions.

        Args:
            file_path (str): The path to the file containing conditions UI_JSON.
        """
        # TODO: Implement the logic to read conditions from the specified file.
        # This method is a placeholder, and the actual implementation is required.
        pass
