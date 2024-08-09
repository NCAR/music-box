class Product:
    """
    Represents a product with attributes such as name and yield.

    Attributes:
        name (str): The name of the product.
        species (Species): An instance of the Species class representing the product.
        yield_value (float): The yield of the product.
    """

    def __init__(self, species, yield_value=None):
        """
        Initializes a new instance of the Product class.

        Args:
            species (Species): An instance of the Species class representing the product.
            yield_value (float): The yield of the product.
        """
        self.name = species.name
        self.species = species
        self.yield_value = yield_value
