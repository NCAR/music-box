import json
import os
from typing import List
from .music_box_species import Species

class SpeciesList:
    """
    Represents a list of species with a relative tolerance.

    Attributes:
        species (List[Species]): A list of Species instances.
        relativeTolerance (float): The relative tolerance for the species list.
    """

    def __init__(self, species=None, relative_tolerance=1.0e-4):
        """
        Initializes a new instance of the SpeciesList class.

        Args:
            species (List[Species]): A list of Species instances. Default is an empty list.
            relative_tolerance (float): The relative tolerance for the species list. Default is 1.0e-4.
        """
        self.species = species if species is not None else []
        self.relative_tolerance = relative_tolerance

    @classmethod
    def from_UI_JSON(cls, UI_JSON):
        """
        Create a new instance of the SpeciesList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object from MusicBox Interactive representing the species list.

        Returns:
            SpeciesList: A new instance of the SpeciesList class.
        """
        species_from_json = []

        for species in UI_JSON['mechanism']['species']['camp-data']:
            name = species['name']
            absolute_tolerance = species['absolute tolerance'] if 'absolute tolerance' in species else None
            molecular_weight = species['molecular weight'] if 'molecular weight' in species else None

            # TODO: Add phase and density to species

            species_from_json.append(Species(name, absolute_tolerance, None, molecular_weight, None))
        
        return cls(species_from_json)
    
    @classmethod
    def from_config_JSON(cls, path_to_json, config_JSON):
        """
        Create a new instance of the SpeciesList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object from a config JSON representing the species list.

        Returns:
            SpeciesList: A new instance of the SpeciesList class.
        """

        species_from_json = []

        #gets config file path
        config_file_path = os.path.dirname(path_to_json) + "/" + config_JSON['model components'][0]['configuration file']

        #opnens config path to read species file
        with open(config_file_path, 'r') as json_file:
            config = json.load(json_file)

            #assumes species file is first in the list
            if(len(config['camp-files']) > 0):
                species_file_path = os.path.dirname(config_file_path) + "/" + config['camp-files'][0]
                with open(species_file_path, 'r') as species_file:
                    species_data = json.load(species_file)
                    #loads species by names from camp files
                    for properties in species_data['camp-data']:
                        if properties.get('name') is not None:
                            name = properties.get('name')
                            species_from_json.append(Species(name, None, None, None, None))


        #chceks if species are in the config file and updates attributes accordingly
        for chem_spec in config_JSON['chemical species']:
            for species in species_from_json:
                if species.name == chem_spec:
                    # Add attributes to species
                    if 'absolute tolerance' in chem_spec:
                        species.absolute_tolerance = chem_spec['absolute tolerance']
                    if 'molecular weight' in chem_spec:
                        species.molecular_weight = chem_spec['molecular weight']
                    if 'density' in chem_spec:
                        species.density = chem_spec['density']
                    if 'phase' in chem_spec:
                        species.phase = chem_spec['phase']
                    


        return cls(species_from_json)


    def add_species(self, species):
        """
        Add a Species instance to the list of species.

        Args:
            species (Species): The Species instance to be added.
        """
        self.species.append(species)
