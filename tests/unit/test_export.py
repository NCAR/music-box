from acom_music_box import MusicBox, Examples, BoxModelOptions, Conditions


# TODO:

def test_model_options_to_dict():
    model_options = BoxModelOptions()
    # assert default options in a dict? Is this too much? Just do an integration test
    mo_dict = model_options.to_dict()
    print(mo_dict)

    # assert passed in parameters?
    model_options = BoxModelOptions(1, 1.0, 400, 'box')
    mo_dict = model_options.to_dict()
    print()
    print(mo_dict)


def test_condtions_to_dict():
    cond = Conditions()
    cond_dict = cond.to_dict()
    print()
    print(cond_dict)


def test_box_model_to_dict():
    mb = MusicBox()
    mb_dict = mb.to_dict()
    print()
    print(mb_dict)