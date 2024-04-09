class Species:
    """
    Represents a species with various attributes such as name, absolute tolerance, phase, molecular weight, and density.

    Attributes:
        name (str): The name of the species.
        absolute_tolerance (float): The absolute tolerance of the species.
        phase (str): The phase of the species.
        molecular_weight (float): The molecular weight of the species in kg mol^-1.
        density (float): The density of the species in kg m^-3.
    """

    def __init__(self, name=None, absolute_tolerance=None, phase=None, molecular_weight=None, density=None):
        """
        Initializes a new instance of the Species class.

        Args:
            name (str): The name of the species.
            absolute_tolerance (float): The absolute tolerance of the species.
            phase (str): The phase of the species.
            molecular_weight (float): The molecular weight of the species in kg mol^-1.
            density (float): The density of the species in kg m^-3.
        """
        self.name = name
        self.absolute_tolerance = absolute_tolerance
        self.phase = phase
        self.molecular_weight = molecular_weight
        self.density = density 
