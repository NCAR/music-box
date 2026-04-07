from .utils import convert_time, convert_pressure, convert_temperature, convert_concentration


class BoxModelOptions:
    """
    Represents options for a box model simulation.

    Attributes:
        grid (str): The type of grid. Default is "box".
        chemStepTime (float): Time step for chemical reactions in the simulation in seconds.
        outputStepTime (float): Time step for output data in the simulation in hours.
        simulationLength (float): Length of the simulation in hours.
    """

    def __init__(
            self,
            chem_step_time=None,
            output_step_time=None,
            simulation_length=None,
            grid="box",
            max_iterations=1000):
        """
        Initializes a new instance of the BoxModelOptions class.

        Args:
            chem_step_time (float): Time step for chemical reactions in the simulation in seconds.
            output_step_time (float): Time step for output data in the simulation in hours.
            simulation_length (float): Length of the simulation in hours.
            grid (str): The type of grid. Default is "box".
            max_iterations (int): Maximum iterations for solver substeps. Default is 1000.
        """
        self.chem_step_time = chem_step_time
        self.output_step_time = output_step_time
        self.simulation_length = simulation_length
        self.grid = grid
        self.max_iterations = max_iterations

    def __repr__(self):
        return (
            "BoxModelOptions(chem_step_time={0}, output_step_time={1}, "
            "simulation_length={2}, grid={3}, max_iterations={4})"
        ).format(
            self.chem_step_time,
            self.output_step_time,
            self.simulation_length,
            self.grid,
            self.max_iterations
        )

    def __str__(self):
        return (
            "BoxModelOptions Time step: {0}, Output time step: {1}, "
            "Simulation length: {2}, Grid: {3}, Max iterations: {4}"
        ).format(
            self.chem_step_time,
            self.output_step_time,
            self.simulation_length,
            self.grid,
            self.max_iterations
        )

    @classmethod
    def from_config(cls, config_JSON):
        """
        Create a new instance of the BoxModelOptions class from a JSON object from a configuration JSON.

        Args:
            UI_JSON (dict): A JSON object representing box model options.

        Returns:
            BoxModelOptions: A new instance of the BoxModelOptions class.
        """

        chem_step_time = convert_time(
            config_JSON['box model options'],
            'chemistry time step')
        output_step_time = convert_time(
            config_JSON['box model options'],
            'output time step')
        simulation_length = convert_time(
            config_JSON['box model options'],
            'simulation length')

        grid = config_JSON['box model options']['grid']
        max_iterations = config_JSON['box model options'].get('max iterations', 1000)

        return cls(chem_step_time, output_step_time, simulation_length, grid, max_iterations)
