class BoxModelOptions:
    """
    Represents options for a box model simulation.

    Attributes:
        grid (str): The type of grid. Default is "box".
        chemStepTime (float): Time step for chemical reactions in the simulation in minutes.
        outputStepTime (float): Time step for output data in the simulation in hours.
        simulationLength (float): Length of the simulation in hours.
    """

    def __init__(self, chem_step_time, output_step_time, simulation_length, grid="box"):
        """
        Initializes a new instance of the BoxModelOptions class.

        Args:
            chem_step_time (float): Time step for chemical reactions in the simulation in minutes.
            output_step_time (float): Time step for output data in the simulation in hours.
            simulation_length (float): Length of the simulation in hours.
            grid (str): The type of grid. Default is "box".
        """
        self.chem_step_time = chem_step_time
        self.output_step_time = output_step_time
        self.simulation_length = simulation_length
        self.grid = grid
