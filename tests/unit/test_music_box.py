"""
Unit tests for the MusicBox class.
"""
import gc
import os
import musica.mechanism_configuration as mc

from acom_music_box import MusicBox


class TrackingWrapper:
    """Wraps an object and records when __del__ is called."""
    def __init__(self, obj, del_called):
        self._obj = obj
        self._del_called = del_called

    def __del__(self):
        self._del_called.append(True)


class TestMusicBoxSolverDeletion:
    """Tests that old solvers are properly deleted when loadJson or load_mechanism is called multiple times."""

    def _make_mechanism(self):
        """Create a minimal mechanism for testing."""
        A = mc.Species(name="A")
        B = mc.Species(name="B")
        gas = mc.Phase(name="gas", species=[A, B])
        arr = mc.Arrhenius(name="A->B", A=4.0e-3, C=50,
                           reactants=[A], products=[B], gas_phase=gas)
        return mc.Mechanism(name="test", species=[A, B], phases=[gas], reactions=[arr])

    def test_load_mechanism_deletes_old_solver(self):
        """Verify __del__ is called on the old solver when load_mechanism is called twice."""
        box_model = MusicBox()
        mechanism = self._make_mechanism()

        # Load a first solver
        box_model.load_mechanism(mechanism)
        first_solver = box_model.solver

        del_called = []

        # Assign a tracking wrapper so we can detect when it is garbage collected
        box_model.solver = TrackingWrapper(first_solver, del_called)

        # Load a second solver — the old one (TrackingWrapper) should be garbage collected
        box_model.load_mechanism(mechanism)

        # Force garbage collection
        gc.collect()

        assert del_called, "__del__ was not called on the old solver"

    def test_load_mechanism_nullifies_state_before_solver(self):
        """Verify that state is set to None before solver is replaced."""
        box_model = MusicBox()
        mechanism = self._make_mechanism()

        box_model.load_mechanism(mechanism)

        # Both solver and state should be set after load
        assert box_model.solver is not None
        assert box_model.state is not None

        # Load again — should still work correctly
        box_model.load_mechanism(mechanism)
        assert box_model.solver is not None
        assert box_model.state is not None

    def test_loadJson_deletes_old_solver(self):
        """Verify __del__ is called on the old solver when loadJson is called twice."""
        # Use the bundled analytical example config
        config_path = os.path.join(
            os.path.dirname(__file__), '..', '..', 'examples', 'analytical', 'my_config.json'
        )

        box_model = MusicBox()
        box_model.loadJson(str(config_path))
        first_solver = box_model.solver

        del_called = []

        # Replace solver with a tracking wrapper
        box_model.solver = TrackingWrapper(first_solver, del_called)

        # Load again — the old TrackingWrapper should be garbage collected
        box_model.loadJson(str(config_path))

        gc.collect()

        assert del_called, "__del__ was not called on the old solver"
