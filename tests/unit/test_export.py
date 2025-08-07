from acom_music_box import MusicBox, Examples, BoxModelOptions, Conditions, EvolvingConditions
import musica.mechanism_configuration as mc


# TODO: remove or assert tests

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
        temperature=298.15, # Units: Kelvin (K)
        pressure=101325.0, # Units: Pascals (Pa)
    ) 
    return EvolvingConditions(times=[100.0, 400.0], conditions=[condition1, condition2])


def create_music_box():
    return MusicBox(
        box_model_options=create_box_model_options(),
        initial_conditions=create_condition(),
        evolving_conditions=create_evolving_conditions()
    )


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
    

def test_model_options_to_dict():
    print()
    print('BoxModelOptions Test:')
    model_options = BoxModelOptions()
    mo_dict = model_options.to_dict()
    print(mo_dict)

    model_options = BoxModelOptions(1, 1.0, 400, 'box')
    mo_dict = model_options.to_dict()
    print(mo_dict)


def test_condtions_to_dict():
    print()
    print('Conditions Test:')
    condition = Conditions()
    cond_dict = condition.to_dict()
    print(cond_dict)

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
    print(condition_dict)


def test_evolving_conditions_to_dict():
    print()
    print('Evolving Conditions Test:')
    e_cond = EvolvingConditions()
    e_cond_dict = e_cond.to_dict()
    print(e_cond_dict)

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
    print(e_cond_dict)


def test_box_model_to_dict():
    print()
    print('MusicBox Test:')
    music_box = MusicBox()
    music_box_dict = music_box.to_dict()
    print(music_box_dict)
    music_box = create_music_box()
    music_box_dict = music_box.to_dict()
    print(music_box_dict)


def test_box_model_export(tmp_path):
    music_box = create_music_box()
    music_box.load_mechanism(create_mechanism())
    file_path = f'{tmp_path}/music_box_config.json'
    print(file_path)
    music_box.export(file_path)
