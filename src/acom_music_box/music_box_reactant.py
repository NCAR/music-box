class Reactant:
    """
    Represents a reactant with attributes such as name and quantity.

    Attributes:
        name (str): The name of the reactant.
        quantity (float): The quantity of the reactant.
    """

    def __init__(self, species, quantity=None):
        """
        Initializes a new instance of the Reactant class.

        Args:
            species (Species): An instance of the Species class representing the reactant.
            quantity (float): The quantity of the reactant.
        """
        self.name = species.name
        self.species = species
        self.quantity = quantity
