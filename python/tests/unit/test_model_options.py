"""
Unit tests for the BoxModelOptions class.
"""
from acom_music_box.model_options import BoxModelOptions


class TestBoxModelOptions:

    def test_serialize_round_trips_through_from_config(self):
        options = BoxModelOptions(
            chem_step_time=2.0,
            output_step_time=6.0,
            simulation_length=60.0,
            grid="box",
            max_iterations=100,
        )

        serialized = options.serialize()
        assert serialized == {
            'grid': 'box',
            'chemistry time step [sec]': 2.0,
            'output time step [sec]': 6.0,
            'simulation length [sec]': 60.0,
            'max iterations': 100,
        }

        reloaded = BoxModelOptions.from_config({'box model options': serialized})
        assert reloaded.grid == options.grid
        assert reloaded.chem_step_time == options.chem_step_time
        assert reloaded.output_step_time == options.output_step_time
        assert reloaded.simulation_length == options.simulation_length
        assert reloaded.max_iterations == options.max_iterations

    def test_serialize_uses_constructor_defaults(self):
        options = BoxModelOptions(chem_step_time=1.0, output_step_time=1.0, simulation_length=10.0)

        serialized = options.serialize()
        assert serialized['grid'] == 'box'
        assert serialized['max iterations'] == 1000
