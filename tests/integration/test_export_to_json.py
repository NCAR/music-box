"""
Integration tests for MusicBox.export_to_json.

Tests:
  - In-code mechanism export and round-trip solve
  - v1 file-loaded mechanism (Chapman) export and round-trip solve
"""
import json
import math
import os
import tempfile

import pandas as pd
import pytest

import musica.mechanism_configuration as mc
from acom_music_box import MusicBox, Conditions, Examples


class TestExportToJsonInCode:
    """Export an in-code mechanism, reload from the exported file, and solve."""

    def _build_box_model(self):
        A = mc.Species(name="A")
        B = mc.Species(name="B")
        C = mc.Species(name="C")
        gas = mc.Phase(name="gas", species=[A, B, C])
        arr1 = mc.Arrhenius(
            name="A->B", A=4.0e-3, C=50, reactants=[A], products=[B], gas_phase=gas
        )
        arr2 = mc.Arrhenius(
            name="B->C", A=1.2e-4, B=2.5, C=75, D=50, E=0.5,
            reactants=[B], products=[C], gas_phase=gas
        )
        mechanism = mc.Mechanism(
            name="test", species=[A, B, C], phases=[gas], reactions=[arr1, arr2]
        )
        box_model = MusicBox()
        box_model.load_mechanism(mechanism)
        box_model.initial_conditions = Conditions(
            temperature=298.15,
            pressure=101325.0,
            species_concentrations={"A": 1.0, "B": 0.0, "C": 0.0},
        )
        box_model.box_model_options.simulation_length = 600.0
        box_model.box_model_options.chem_step_time = 2.0
        box_model.box_model_options.output_step_time = 6.0
        return box_model

    def test_export_creates_valid_json(self):
        box_model = self._build_box_model()
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "config.json")
            box_model.export_to_json(config_path)

            assert os.path.isfile(config_path)
            with open(config_path) as f:
                data = json.load(f)

            assert "box model options" in data
            assert "initial conditions" in data
            assert "environmental conditions" in data
            assert "evolving conditions" in data
            assert "mechanism" in data

            # Check mechanism has expected fields
            mech = data["mechanism"]
            assert mech["name"] == "test"
            assert any(s["name"] == "A" for s in mech["species"])
            assert any(r["type"] == "ARRHENIUS" for r in mech["reactions"])

            # Check box model options
            opts = data["box model options"]
            assert opts["chemistry time step [sec]"] == 2.0
            assert opts["output time step [sec]"] == 6.0
            assert opts["simulation length [sec]"] == 600.0

            # Check initial conditions inline data
            ic = data["initial conditions"]
            assert "data" in ic
            headers, values = ic["data"]
            assert "CONC.A [mol m-3]" in headers
            a_idx = headers.index("CONC.A [mol m-3]")
            assert math.isclose(values[a_idx], 1.0)

    def test_round_trip_solve_matches(self):
        """Exported config should produce the same solve results as the original."""
        box_model = self._build_box_model()
        original_results = box_model.solve()

        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "config.json")
            box_model.export_to_json(config_path)

            reloaded = MusicBox()
            reloaded.loadJson(config_path)
            reloaded_results = reloaded.solve()

        for col in ["CONC.A.mol m-3", "CONC.B.mol m-3", "CONC.C.mol m-3"]:
            for orig, relo in zip(
                original_results[col].values, reloaded_results[col].values
            ):
                assert math.isclose(orig, relo, rel_tol=1e-10, abs_tol=1e-20), (
                    f"Mismatch in {col}: {orig} vs {relo}"
                )

    def test_no_mechanism_raises(self):
        box_model = MusicBox()
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "config.json")
            with pytest.raises(ValueError, match="Mechanism is not loaded"):
                box_model.export_to_json(config_path)


class TestExportToJsonWithEvolvingConditions:
    """Export a model that has evolving conditions."""

    def _build_box_model(self):
        A = mc.Species(name="A")
        B = mc.Species(name="B")
        gas = mc.Phase(name="gas", species=[A, B])
        arr1 = mc.Arrhenius(
            name="A->B", A=4.0e-3, C=50, reactants=[A], products=[B], gas_phase=gas
        )
        mechanism = mc.Mechanism(
            name="evolving_test", species=[A, B], phases=[gas], reactions=[arr1]
        )
        box_model = MusicBox()
        box_model.load_mechanism(mechanism)
        box_model.initial_conditions = Conditions(
            temperature=298.15,
            pressure=101325.0,
            species_concentrations={"A": 1.0, "B": 0.0},
        )
        box_model.add_evolving_condition(
            300.0,
            Conditions(
                temperature=310.0,
                pressure=100000.0,
                species_concentrations={"A": 0.5, "B": 0.1},
            ),
        )
        box_model.box_model_options.simulation_length = 600.0
        box_model.box_model_options.chem_step_time = 2.0
        box_model.box_model_options.output_step_time = 60.0
        return box_model

    def test_export_writes_evolving_conditions_csv(self):
        box_model = self._build_box_model()
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "config.json")
            box_model.export_to_json(config_path)

            assert os.path.isfile(config_path)
            csv_path = os.path.join(tmpdir, "evolving_conditions.csv")
            assert os.path.isfile(csv_path), "evolving_conditions.csv should be written"

            df = pd.read_csv(csv_path)
            assert "time.s" in df.columns
            assert "ENV.temperature.K" in df.columns
            assert "ENV.pressure.Pa" in df.columns
            assert "CONC.A.mol m-3" in df.columns

    def test_round_trip_with_evolving_conditions(self):
        box_model = self._build_box_model()
        original_results = box_model.solve()

        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "config.json")
            box_model.export_to_json(config_path)

            reloaded = MusicBox()
            reloaded.loadJson(config_path)
            reloaded_results = reloaded.solve()

        for col in ["CONC.A.mol m-3", "CONC.B.mol m-3"]:
            for orig, relo in zip(
                original_results[col].values, reloaded_results[col].values
            ):
                assert math.isclose(orig, relo, rel_tol=1e-10, abs_tol=1e-20), (
                    f"Mismatch in {col}: {orig} vs {relo}"
                )


class TestExportToJsonChapmanV1:
    """Load the Chapman v1 config, export it, reload and verify results match."""

    def test_chapman_round_trip(self):
        current_dir = os.path.dirname(__file__)
        config_path = os.path.join(
            current_dir, "configs", "chapman", "chapman.v1.config.json"
        )

        box_model = MusicBox()
        box_model.loadJson(config_path)
        original_results = box_model.solve()

        with tempfile.TemporaryDirectory() as tmpdir:
            exported_path = os.path.join(tmpdir, "exported.json")
            box_model.export_to_json(exported_path)

            assert os.path.isfile(exported_path)
            evol_csv = os.path.join(tmpdir, "evolving_conditions.csv")
            assert os.path.isfile(evol_csv), "Evolving conditions CSV should be written"

            # Verify exported JSON structure
            with open(exported_path) as f:
                data = json.load(f)
            assert data["mechanism"]["name"] == "Chapman"
            assert data["environmental conditions"]["temperature"]["initial value [K]"] == pytest.approx(217.6)
            assert data["environmental conditions"]["pressure"]["initial value [Pa]"] == pytest.approx(1394.3)

            # Reload and solve
            reloaded = MusicBox()
            reloaded.loadJson(exported_path)
            reloaded_results = reloaded.solve()

        expected_path = os.path.join(current_dir, "expected_results/chapman_test.csv")
        expected = pd.read_csv(expected_path)
        concs_to_test = [c for c in expected.columns if "CONC" in c]

        for (_mi, _mr), (_ei, _er) in zip(
            reloaded_results.iterrows(), expected.iterrows()
        ):
            for col in concs_to_test:
                assert math.isclose(
                    _mr[col], _er[col], rel_tol=1e-10, abs_tol=1e-16
                ), f"Mismatch in {col} at row {_mi}"
