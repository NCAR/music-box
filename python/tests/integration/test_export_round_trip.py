"""
Round-trip export test: build a MusicBox entirely in code with every possible
option, run it, export to a v1 JSON file via export(), reload with loadJson(),
run again, and assert the two result DataFrames are exactly equal.

"Every possible option" covers:
  - All five BoxModelOptions fields (grid, chem_step_time, output_step_time,
    simulation_length, max_iterations)
  - Four reaction types: Arrhenius (all A/B/C/D/E params), Photolysis, Emission,
    FirstOrderLoss
  - Initial conditions at t=0: temperature, pressure, concentrations for all
    species, and all rate-parameter types (PHOTO, EMIS, LOSS)
  - Evolving conditions at t=30: temperature, pressure, concentration reset,
    and updated rate parameters
"""

import json

import pandas as pd

import musica.mechanism_configuration as mc
from acom_music_box import MusicBox


def _build_model():
    """Return a fully-configured MusicBox using only the in-code API."""
    A = mc.Species(name="A")
    B = mc.Species(name="B")
    C = mc.Species(name="C")
    D = mc.Species(name="D")
    E = mc.Species(name="E")
    species_list = [A, B, C, D, E]
    gas = mc.Phase(name="gas", species=species_list)

    # Arrhenius: all five parameters set
    arr1 = mc.Arrhenius(
        name="A->B", A=4.0e-3, B=0.0, C=50.0, D=300.0, E=0.0,
        reactants=[A], products=[B], gas_phase=gas,
    )
    arr2 = mc.Arrhenius(
        name="B->C", A=1.2e-4, B=2.5, C=75.0, D=50.0, E=0.5,
        reactants=[B], products=[C], gas_phase=gas,
    )
    # Photolysis: requires PHOTO rate parameter
    photo = mc.Photolysis(
        name="photo_D", scaling_factor=1.0,
        reactants=[D], products=[E], gas_phase=gas,
    )
    # Emission: requires EMIS rate parameter
    emis = mc.Emission(
        name="emis_A", scaling_factor=1.0,
        products=[A], gas_phase=gas,
    )
    # FirstOrderLoss: requires LOSS rate parameter
    loss = mc.FirstOrderLoss(
        name="loss_E", scaling_factor=1.0,
        reactants=[E], gas_phase=gas,
    )

    mechanism = mc.Mechanism(
        name="all_options_test",
        species=species_list,
        phases=[gas],
        reactions=[arr1, arr2, photo, emis, loss],
    )

    box = MusicBox()
    box.load_mechanism(mechanism)

    # All five BoxModelOptions fields
    box.box_model_options.grid = "box"
    box.box_model_options.chem_step_time = 2.0
    box.box_model_options.output_step_time = 6.0
    box.box_model_options.simulation_length = 60.0
    box.box_model_options.max_iterations = 100

    # Initial conditions (t=0): temperature, pressure, all species,
    # and all rate-parameter types
    (box
        .set_condition(
            time=0.0,
            temperature=298.15,
            pressure=101325.0,
            concentrations={"A": 1.0, "B": 0.0, "C": 0.0, "D": 0.5, "E": 0.0},
            rate_parameters={
                "PHOTO.photo_D.s-1": 1.0e-4,
                "EMIS.emis_A.mol m-3 s-1": 1.0e-8,
                "LOSS.loss_E.s-1": 1.0e-3,
            },
        )
        # Evolving conditions (t=30): temperature, pressure, concentration reset,
        # and updated rate parameters
        .set_condition(
            time=30.0,
            temperature=300.0,
            pressure=101000.0,
            concentrations={"D": 0.3},
            rate_parameters={
                "PHOTO.photo_D.s-1": 2.0e-4,
                "EMIS.emis_A.mol m-3 s-1": 5.0e-9,
                "LOSS.loss_E.s-1": 2.0e-3,
            },
        ))

    return box


class TestExportRoundTrip:

    def test_export_file_structure(self, tmp_path):
        """export() writes a well-formed v1 JSON file."""
        box = _build_model()
        config_file = tmp_path / "config.json"
        box.export(str(config_file))
        with open(config_file) as f:
            config = json.load(f)

        assert "box model options" in config
        assert "mechanism" in config
        assert "conditions" in config

        opts = config["box model options"]
        assert opts["grid"] == "box"
        assert opts["chemistry time step [sec]"] == 2.0
        assert opts["output time step [sec]"] == 6.0
        assert opts["simulation length [sec]"] == 60.0
        assert opts["max iterations"] == 100

        mech = config["mechanism"]
        assert mech["version"] == "1.0.0"
        reaction_types = {r["type"] for r in mech["reactions"]}
        assert reaction_types == {"ARRHENIUS", "PHOTOLYSIS", "EMISSION", "FIRST_ORDER_LOSS"}

        conds = config["conditions"]
        assert "data" in conds
        # Two time points → two data blocks
        assert len(conds["data"]) == 2

        # t=0 block must contain all condition types
        t0_block = conds["data"][0]
        assert "CONC.A.mol m-3" in t0_block["headers"]
        assert "CONC.D.mol m-3" in t0_block["headers"]
        assert "ENV.temperature.K" in t0_block["headers"]
        assert "ENV.pressure.Pa" in t0_block["headers"]
        assert "PHOTO.photo_D.s-1" in t0_block["headers"]
        assert "EMIS.emis_A.mol m-3 s-1" in t0_block["headers"]
        assert "LOSS.loss_E.s-1" in t0_block["headers"]

        # t=30 block must contain updated evolving conditions
        t30_block = conds["data"][1]
        assert "ENV.temperature.K" in t30_block["headers"]
        assert "CONC.D.mol m-3" in t30_block["headers"]
        assert "PHOTO.photo_D.s-1" in t30_block["headers"]

    def test_round_trip_results_exactly_equal(self, tmp_path):
        """
        Solve in code, export to file, reload via loadJson(), solve again.
        Both result DataFrames must be exactly equal (bit-for-bit).
        """
        # --- Step 1: build and solve in code ---
        box1 = _build_model()
        df1 = box1.solve()

        # --- Step 2: export to JSON file ---
        config_file = tmp_path / "config.json"
        box1.export(str(config_file))

        # --- Step 3: reload from exported file ---
        box2 = MusicBox()
        box2.loadJson(str(config_file))
        df2 = box2.solve()

        # --- Step 4: compare exactly equal ---
        assert df1.shape == df2.shape, (
            f"Result shapes differ: {df1.shape} vs {df2.shape}"
        )

        # Sort columns so ordering differences don't cause false failures
        df1_sorted = df1.reindex(sorted(df1.columns), axis=1)
        df2_sorted = df2.reindex(sorted(df2.columns), axis=1)

        pd.testing.assert_frame_equal(
            df1_sorted, df2_sorted,
            check_exact=True,
            obj="solve() results after export/reload round-trip",
        )
