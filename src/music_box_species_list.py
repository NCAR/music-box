from typing import List
from music_box_species import Species

class SpeciesList:
    """
    Represents a list of species with a relative tolerance.

    Attributes:
        species (List[Species]): A list of Species instances.
        relativeTolerance (float): The relative tolerance for the species list.
    """

    def __init__(self, species=None, relative_tolerance=0.0):
        """
        Initializes a new instance of the SpeciesList class.

        Args:
            species (List[Species]): A list of Species instances. Default is an empty list.
            relative_tolerance (float): The relative tolerance for the species list. Default is 0.0.
        """
        self.species = species if species is not None else []
        self.relative_tolerance = relative_tolerance

    @classmethod
    def from_UI_JSON(cls, UI_JSON):
        """
        Create a new instance of the SpeciesList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object representing the species list.

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

    def add_species(self, species):
        """
        Add a Species instance to the list of species.

        Args:
            species (Species): The Species instance to be added.
        """
        self.species.append(species)
