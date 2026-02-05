import musica.mechanism_configuration as mc
from acom_music_box import MusicBox
import numpy as np
import os
import pytest


def in_code_surface_reaction():
    A = mc.Species(name="A", molecular_weight_kg_mol=6)
    B = mc.Species(name="B")
    species = {s.name: s for s in [A, B]}
    gas = mc.Phase(name="gas", species=[mc.PhaseSpecies(A.name, diffusion_coefficient_m2_s=1e-9), B])
    surface = mc.Surface(name="surface", reaction_probability=1.0, gas_phase_species=A, gas_phase_products=[B], gas_phase=gas)
    mechanism = mc.Mechanism(name="test_mechanism", species=list(species.values()), phases=[gas], reactions=[surface])
    box_model = MusicBox()
    box_model.load_mechanism(mechanism)

    # Set conditions using new API
    (box_model
        .set_condition(
            time=0,
            temperature=300,
            pressure=101325,
            concentrations={
                "A": 1.0,
                "B": 0
            },
            rate_parameters={
                "SURF.surface.particle number concentration.# m-3": 1e12,
                "SURF.surface.effective radius.m": 1e-7
            }))

    box_model.box_model_options.simulation_length = 10
    box_model.box_model_options.chem_step_time = 1
    box_model.box_model_options.output_step_time = 1
    return box_model


def config_surface_reaction():
    box_model = MusicBox()
    current_dir = os.path.dirname(__file__)
    example = os.path.join(current_dir, "configs", "surface", "surface.v1.config.json")
    box_model.loadJson(example)
    return box_model


@pytest.mark.parametrize("box_model_func", [in_code_surface_reaction, config_surface_reaction])
def test_box_model(box_model_func):
    box_model = box_model_func()
    df = box_model.solve()

    # Check initial concentrations
    assert np.isclose(df["CONC.A.mol m-3"].iloc[0], 1.0), "Initial concentration of A should be 1.0"
    assert np.isclose(df["CONC.B.mol m-3"].iloc[0], 0.0), "Initial concentration of B should be 0.0"

    # Check concentration changes over time
    a_conc = df["CONC.A.mol m-3"]
    b_conc = df["CONC.B.mol m-3"]

    for i in range(1, len(df)):
        assert a_conc.iloc[i] < a_conc.iloc[i - 1], f"Concentration of A should decrease at step {i}"
        assert b_conc.iloc[i] > b_conc.iloc[i - 1], f"Concentration of B should increase at step {i}"
