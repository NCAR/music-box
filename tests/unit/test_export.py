import os
from acom_music_box import MusicBox, Examples, BoxModelOptions, Conditions, EvolvingConditions
import musica.mechanism_configuration as mc


def create_box_model_options(chem_step_time=1.0, output_step_time=1.0, simulation_length=400, grid="box"):
    return BoxModelOptions(chem_step_time, output_step_time, simulation_length, grid)


def create_condition():
    return Conditions(
        temperature=298.15, # Units: Kelvin (K)
        pressure=101325.0, # Units: Pascals (Pa)
        species_concentrations={ # Units: mol/m^3
            "X": 3.75,
            "Y": 5.0,
            "Z": 2.5,
        }
    )


def create_evolving_conditions():
    condition1 = Conditions(
        temperature=75, # Units: Kelvin (K)
        pressure=100100.0, # Units: Pascals (Pa)
    )
    condition2 = Conditions(
        temperature=150, # Units: Kelvin (K)
        pressure=100500.0, # Units: Pascals (Pa)
    ) 
    return EvolvingConditions(times=[100.0, 300.0], conditions=[condition1, condition2])


def create_mechanism():
    X = mc.Species(name="X")
    Y = mc.Species(name="Y")
    Z = mc.Species(name="Z")
    species = {"X": X, "Y": Y, "Z": Z}
    gas = mc.Phase(name="gas", species=list(species.values()))
    arr1 = mc.Arrhenius(name="X->Y", A=4.0e-3, C=50, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)
    arr2 = mc.Arrhenius(name="Y->Z", A=4.0e-3, C=50, reactants=[species["Y"]], products=[species["Z"]], gas_phase=gas)
    rxns = {"X->Y": arr1, "Y->Z": arr2}
    return mc.Mechanism(name="tutorial_mechanism", species=list(species.values()), phases=[gas], reactions=list(rxns.values()), version = mc.Version("1.0.1"))


def create_music_box():
    music_box = MusicBox(
        box_model_options=create_box_model_options(),
        initial_conditions=create_condition(),
        evolving_conditions=create_evolving_conditions()
    )
    music_box.load_mechanism(create_mechanism())
    return music_box


def test_model_options_to_dict():
    model_options = BoxModelOptions()
    mo_dict = model_options.to_dict()
    assert len(mo_dict) == 1
    model_options = BoxModelOptions(1, 1.0, 400, 'box')
    mo_dict = model_options.to_dict()
    assert len(mo_dict) == 4


def test_condtions_to_dict():
    condition = Conditions()
    condition_dict = condition.to_dict()
    assert len(condition_dict) == 0

    condition = Conditions(
        temperature=298.15, # Units: Kelvin (K)
        pressure=101325.0, # Units: Pascals (Pa)
        species_concentrations={ # Units: mol/m^3
            "X": 3.75,
            "Y": 5.0,
            "Z": 2.5,
        }
    )
    condition_dict = condition.to_dict()
    assert len(condition_dict) == 3


def test_evolving_conditions_to_dict():
    e_cond = EvolvingConditions()
    e_cond_dict = e_cond.to_dict()
    assert len(e_cond_dict) == 0

    condition1 = Conditions(
        temperature=298.15, # Units: Kelvin (K)
        pressure=101325.0, # Units: Pascals (Pa)
        species_concentrations={ # Units: mol/m^3
            "X": 3.75,
            "Y": 5.0,
            "Z": 2.5,
        }
    )
    condition2 = Conditions(
        temperature=75, # Units: Kelvin (K)
        pressure=100100.0, # Units: Pascals (Pa)
    )
    e_cond = EvolvingConditions(times=[0.0, 100.0], conditions=[condition1, condition2])
    e_cond_dict = e_cond.to_dict()
    assert len(e_cond_dict) == 2
    assert len(e_cond_dict['conditions']) == 2


def test_box_model_to_dict():
    music_box = MusicBox()
    music_box_dict = music_box.to_dict()
    assert len(music_box_dict) == 1
    music_box = create_music_box()
    music_box_dict = music_box.to_dict()
    assert len(music_box_dict) == 4


def test_box_model_export(tmp_path):
    music_box = create_music_box()
    file_path = f'{tmp_path}/music_box_config.json'
    assert not os.path.exists(file_path)
    music_box.export(file_path)
    assert os.path.exists(file_path)


def test_music_box_export_import_solutions(tmp_path):
    music_box = create_music_box()
    file_path = f'{tmp_path}/music_box_config.json'
    data = music_box.solve()
    print()
    print(data)
    
    music_box.export(file_path)
    music_box_2 = MusicBox()
    music_box_2.loadJson(file_path)
    # data_2 = music_box_2.solve()
    # print()
    # print(data_2)

    print()
    # print(music_box.to_dict(True))
    # print(music_box_2.to_dict(True))
    music_box_2.export(f'{tmp_path}/music_box_config_2.json')

    # assert data.equals(data_2)
    assert False

