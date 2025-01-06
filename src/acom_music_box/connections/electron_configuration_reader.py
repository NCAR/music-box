from ..conditions import Conditions
from ..model_options import BoxModelOptions
from ..species_list import SpeciesList
from ..reaction_list import ReactionList
from ..evolving_conditions import EvolvingConditions
import json


class ElectronConfiguraitonReader:
    """ Reads configuration information from the electron applicant to create a box model simulation.
    """

    def __init__(self):
        self.box_model_options = None
        self.species_list = None
        self.reaction_list = None
        self.initial_conditions = None
        self.evolving_conditions = None

    def read_electron_configuration(self):
        with open(self.electron_configuration_file_path, 'r') as file:
            for line in file:
                element, configuration = line.strip().split(' ')
                self.electron_configuration[element] = configuration

    def get_electron_configuration(self, element):
        return self.electron_configuration[element]

    def readFromUIJson(self, path_to_json):
        """
        Reads and parses a JSON file from the MusicBox Interactive UI to set up the box model simulation.

        This function takes the path to a JSON file, reads the file, and parses the JSON
        to set up the box model simulation.

        Args:
            path_to_json (str): The path to the JSON file from the UI.

        Returns:
            None

        Raises:
            ValueError: If the JSON file cannot be read or parsed.
        """

        with open(path_to_json, 'r') as json_file:
            data = json.load(json_file)

            # Set box model options
            self.box_model_options = BoxModelOptions.from_UI_JSON(data)

            # Set species list
            self.species_list = SpeciesList.from_UI_JSON(data)

            # Set reaction list
            self.reaction_list = ReactionList.from_UI_JSON(
                data, self.species_list)

            # Set initial conditions
            self.initial_conditions = Conditions.from_UI_JSON(
                data, self.species_list, self.reaction_list)

            # Set evolving conditions
            self.evolving_conditions = EvolvingConditions.from_UI_JSON(
                data, self.species_list, self.reaction_list)

    def readFromUIJsonString(self, data):
        """
        Reads and parses a JSON string from the MusicBox Interactive UI to set up the box model simulation.

        Args:
            json_string (str): The JSON string from the UI.

        Returns:
            None

        Raises:
            ValueError: If the JSON string cannot be parsed.
        """

        # Set box model options
        self.box_model_options = BoxModelOptions.from_UI_JSON(data)

        # Set species list
        self.species_list = SpeciesList.from_UI_JSON(data)

        # Set reaction list
        self.reaction_list = ReactionList.from_UI_JSON(data, self.species_list)

        # Set initial conditions
        self.initial_conditions = Conditions.from_UI_JSON(
            data, self.species_list, self.reaction_list)

        # Set evolving conditions
        self.evolving_conditions = EvolvingConditions.from_UI_JSON(
            data, self.species_list, self.reaction_list)
