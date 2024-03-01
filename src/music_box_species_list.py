from typing import List

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

    def add_species(self, species):
        """
        Add a Species instance to the list of species.

        Args:
            species (Species): The Species instance to be added.
        """
        self.species.append(species)
