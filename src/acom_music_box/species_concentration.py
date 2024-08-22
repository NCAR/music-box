class SpeciesConcentration:
    """
    Represents a species concentration with attributes such as the associated species and concentration.

    Attributes:
        species (Species): The associated species.
        concentration (float): The concentration of the species.
    """

    def __init__(self, species, concentration):
        """
        Initializes a new instance of the SpeciesConcentration class.

        Args:
            species (Species): The associated species.
            concentration (float): The concentration of the species.
        """
        self.species = species
        self.concentration = concentration

    def __str__(self):
        return f"{self.species.name}: {self.concentration}"

    def __repr__(self):
        return f"{self.species.name}: {self.concentration}"
