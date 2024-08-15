class Species:
    """
    Represents a species with various attributes such as name, absolute tolerance, phase, molecular weight

    Attributes:
        name (str): The name of the species.
        absolute_tolerance (float): The absolute tolerance of the species.
        phase (str): The phase of the species.
        molecular_weight (float): The molecular weight of the species in kg mol^-1.
    """

    def __init__(
            self,
            name=None,
            absolute_tolerance=None,
            phase=None,
            molecular_weight=None,
            tracer_type=None,
            diffusion_coefficient=None):
        """
        Initializes a new instance of the Species class.

        Args:
            name (str): The name of the species.
            absolute_tolerance (float): The absolute tolerance of the species.
            phase (str): The phase of the species.
            molecular_weight (float): The molecular weight of the species in kg mol^-1.
            tracer_type (str): The type of the tracer. Default is None. Other options are THIRD_BODY or CONSTANT
            diffusion_coefficient (float): The diffusion coefficient of the species in m^2 s^-1. Default is None.
        """
        self.name = name
        self.absolute_tolerance = absolute_tolerance
        self.phase = phase
        self.molecular_weight = molecular_weight
        self.tracer_type = tracer_type
        self.diffusion_coefficient = diffusion_coefficient

    def __repr__(self):
        return (
            f"Species(name={self.name!r}, absolute_tolerance={self.absolute_tolerance!r}, "
            f"phase={self.phase!r}, molecular_weight={self.molecular_weight!r}, "
            f"tracer_type={self.tracer_type!r}, diffusion_coefficient={self.diffusion_coefficient!r})")

    def __str__(self):
        return (f"Species: {self.name}, Phase: {self.phase}, "
                f"Molecular Weight: {self.molecular_weight} kg/mol, "
                f"Tolerance: {self.absolute_tolerance}, "
                f"Tracer Type: {self.tracer_type}, "
                f"Diffusion Coefficient: {self.diffusion_coefficient} m^2/s")
