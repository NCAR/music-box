"""
Round-trip export test: build a MusicBox entirely in code with every supported
option, run it, export to a v1 JSON file via export(), reload with loadJson(),
run again, and assert the two result DataFrames are exactly equal.

Covers all five BoxModelOptions fields and one of each supported reaction type:
  - Arrhenius       (all A/B/C/D/E params)
  - Troe            (k0_A/B/C, kinf_A/B/C, Fc, N)
  - Branched        (X, Y, a0, n)
  - TernaryChemicalActivation (same params as Troe)
  - Tunneling       (A, B, C)
  - Photolysis      (scaling_factor) — requires PHOTO rate parameter
  - Emission        (scaling_factor) — requires EMIS rate parameter
  - FirstOrderLoss  (scaling_factor) — requires LOSS rate parameter
  - UserDefined     (scaling_factor) — requires USER rate parameter
  - Surface         (reaction_probability) — requires SURF particle concentration
                                             and effective radius rate parameters

Initial conditions at t=0 set temperature, pressure, concentrations for every
species, and all user-defined rate-parameter types (PHOTO, EMIS, LOSS, USER, SURF).
Evolving conditions at t=30 reset temperature, pressure, one species concentration,
and all rate parameters to new values.
"""

import json

import pandas as pd

import musica.mechanism_configuration as mc
from acom_music_box import MusicBox


def _build_model():
    """Return a fully-configured MusicBox using only the in-code API."""
    # Surface-reactive species requires molecular weight and a diffusion
    # coefficient on the gas-phase entry.
    srf = mc.Species(name="Srf", molecular_weight_kg_mol=0.029)
    A = mc.Species(name="A")
    B = mc.Species(name="B")
    C = mc.Species(name="C")
    D = mc.Species(name="D")
    E = mc.Species(name="E")
    F = mc.Species(name="F")
    G = mc.Species(name="G")
    H = mc.Species(name="H")
    I = mc.Species(name="I")
    J = mc.Species(name="J")
    all_species = [srf, A, B, C, D, E, F, G, H, I, J]

    gas = mc.Phase(
        name="gas",
        species=[
            mc.PhaseSpecies(srf.name, diffusion_coefficient_m2_s=1e-5),
            A, B, C, D, E, F, G, H, I, J,
        ],
    )

    reactions = [
        # Arrhenius: all five kinetic parameters
        mc.Arrhenius(
            name="arr1", A=4.0e-3, B=0.5, C=50.0, D=300.0, E=0.1,
            reactants=[A], products=[B], gas_phase=gas,
        ),
        # Troe: pressure-dependent falloff
        mc.Troe(
            name="troe1",
            k0_A=1.0e-28, k0_B=-3.0, k0_C=0.0,
            kinf_A=1.0e-11, kinf_B=0.0, kinf_C=0.0,
            Fc=0.45, N=1.0,
            reactants=[B], products=[C], gas_phase=gas,
        ),
        # Branched: two product channels; n must be an integer
        mc.Branched(
            name="branched1", X=1.2e-3, Y=1.0, a0=0.15, n=9,
            reactants=[C],
            nitrate_products=[D],
            alkoxy_products=[E],
            gas_phase=gas,
        ),
        # TernaryChemicalActivation: three-body activation
        mc.TernaryChemicalActivation(
            name="tca1",
            k0_A=1.0e-28, k0_B=-3.0, k0_C=0.0,
            kinf_A=1.0e-11, kinf_B=0.0, kinf_C=0.0,
            Fc=0.45, N=1.0,
            reactants=[D], products=[F], gas_phase=gas,
        ),
        # Tunneling: quantum tunneling correction
        mc.Tunneling(
            name="tunnel1", A=1.0e-3, B=100.0, C=200.0,
            reactants=[E], products=[G], gas_phase=gas,
        ),
        # Photolysis: rate set by PHOTO.photo1 condition
        mc.Photolysis(
            name="photo1", scaling_factor=1.0,
            reactants=[F], products=[H], gas_phase=gas,
        ),
        # Emission: rate set by EMIS.emis1 condition
        mc.Emission(
            name="emis1", scaling_factor=1.0,
            products=[I], gas_phase=gas,
        ),
        # FirstOrderLoss: rate set by LOSS.loss1 condition
        mc.FirstOrderLoss(
            name="loss1", scaling_factor=1.0,
            reactants=[H], gas_phase=gas,
        ),
        # UserDefined: rate set by USER.ud1 condition
        mc.UserDefined(
            name="ud1", scaling_factor=1.0,
            reactants=[I], products=[J], gas_phase=gas,
        ),
        # Surface: heterogeneous reaction; rates set by SURF.surf1 conditions
        mc.Surface(
            name="surf1", reaction_probability=0.1,
            gas_phase_species=srf, gas_phase_products=[A], gas_phase=gas,
        ),
    ]

    mechanism = mc.Mechanism(
        name="all_options_test",
        species=all_species,
        phases=[gas],
        reactions=reactions,
    )

    box = MusicBox()
    box.load_mechanism(mechanism)

    # All five BoxModelOptions fields
    box.box_model_options.grid = "box"
    box.box_model_options.chem_step_time = 2.0
    box.box_model_options.output_step_time = 6.0
    box.box_model_options.simulation_length = 60.0
    box.box_model_options.max_iterations = 100

    # Initial conditions (t=0): temperature, pressure, all species
    # concentrations, and every user-defined rate-parameter type
    (box
        .set_condition(
            time=0.0,
            temperature=298.15,
            pressure=101325.0,
            concentrations={
                "Srf": 1.0,
                "A": 1.0, "B": 0.0, "C": 0.0, "D": 0.0,
                "E": 0.0, "F": 0.5, "G": 0.0, "H": 0.0,
                "I": 0.5, "J": 0.0,
            },
            rate_parameters={
                "PHOTO.photo1.s-1": 1.0e-4,
                "EMIS.emis1.mol m-3 s-1": 1.0e-8,
                "LOSS.loss1.s-1": 1.0e-3,
                "USER.ud1.s-1": 1.0e-5,
                "SURF.surf1.particle number concentration.# m-3": 1.0e12,
                "SURF.surf1.effective radius.m": 1.0e-7,
            },
        )
        # Evolving conditions (t=30): updated temperature, pressure,
        # concentration reset, and all rate parameters changed
        .set_condition(
            time=30.0,
            temperature=300.0,
            pressure=101000.0,
            concentrations={"A": 0.5},
            rate_parameters={
                "PHOTO.photo1.s-1": 2.0e-4,
                "EMIS.emis1.mol m-3 s-1": 5.0e-9,
                "LOSS.loss1.s-1": 2.0e-3,
                "USER.ud1.s-1": 2.0e-5,
                "SURF.surf1.particle number concentration.# m-3": 5.0e11,
                "SURF.surf1.effective radius.m": 2.0e-7,
            },
        ))

    return box


EXPECTED_REACTION_TYPES = {
    "ARRHENIUS", "TROE", "BRANCHED_NO_RO2", "TERNARY_CHEMICAL_ACTIVATION",
    "TUNNELING", "PHOTOLYSIS", "EMISSION", "FIRST_ORDER_LOSS",
    "USER_DEFINED", "SURFACE",
}


class TestExportRoundTrip:

    def test_export_file_structure(self, tmp_path):
        """export() writes a well-formed v1 JSON file with every option."""
        box = _build_model()
        config_file = tmp_path / "config.json"
        box.export(str(config_file))
        with open(config_file) as f:
            config = json.load(f)

        # Box model options
        opts = config["box model options"]
        assert opts["grid"] == "box"
        assert opts["chemistry time step [sec]"] == 2.0
        assert opts["output time step [sec]"] == 6.0
        assert opts["simulation length [sec]"] == 60.0
        assert opts["max iterations"] == 100

        # Mechanism contains every reaction type
        assert config["mechanism"]["version"] == "1.0.0"
        exported_types = {r["type"] for r in config["mechanism"]["reactions"]}
        assert exported_types == EXPECTED_REACTION_TYPES

        # Conditions: two time-point blocks
        blocks = config["conditions"]["data"]
        assert len(blocks) == 2

        # t=0 block: all condition types present
        t0_headers = set(blocks[0]["headers"])
        assert "ENV.temperature.K" in t0_headers
        assert "ENV.pressure.Pa" in t0_headers
        assert "CONC.Srf.mol m-3" in t0_headers
        assert "CONC.A.mol m-3" in t0_headers
        assert "PHOTO.photo1.s-1" in t0_headers
        assert "EMIS.emis1.mol m-3 s-1" in t0_headers
        assert "LOSS.loss1.s-1" in t0_headers
        assert "USER.ud1.s-1" in t0_headers
        assert "SURF.surf1.particle number concentration.# m-3" in t0_headers
        assert "SURF.surf1.effective radius.m" in t0_headers

        # t=30 block: all rate-parameter types updated
        t30_headers = set(blocks[1]["headers"])
        assert "ENV.temperature.K" in t30_headers
        assert "CONC.A.mol m-3" in t30_headers
        assert "PHOTO.photo1.s-1" in t30_headers
        assert "EMIS.emis1.mol m-3 s-1" in t30_headers
        assert "LOSS.loss1.s-1" in t30_headers
        assert "USER.ud1.s-1" in t30_headers
        assert "SURF.surf1.particle number concentration.# m-3" in t30_headers
        assert "SURF.surf1.effective radius.m" in t30_headers

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

        # Sort columns to handle any ordering differences
        df1_sorted = df1.reindex(sorted(df1.columns), axis=1)
        df2_sorted = df2.reindex(sorted(df2.columns), axis=1)

        pd.testing.assert_frame_equal(
            df1_sorted, df2_sorted,
            check_exact=True,
            obj="solve() results after export/reload round-trip",
        )
