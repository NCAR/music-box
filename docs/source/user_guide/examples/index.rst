Examples and tutorials
===============================

Running premade examples
-------------------------
MusicBox provides a selection of pre-made example configurations for the user to work with:

* `Analytical <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/analytical>`_
* `CarbonBond5 <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/carbon_bond_5>`_
* `Chapman <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/chapman>`_
* `FlowTube <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/flow_tube>`_
* `TS1 <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/ts1>`_
* `WACCM <https://github.com/NCAR/music-box/tree/main/src/acom_music_box/examples/configs/waccm>`_

Each example (found in `src/acom_music_box/examples/configs`) includes an associated set of JSON files acccessible through the Examples class::

    from acom_music_box import MusicBox, Examples
    import matplotlib.pyplot as plt

    box_model = MusicBox()
    conditions_path = Examples.Analytical.path
    box_model.loadJson(conditions_path)
    df = box_model.solve()
    display(df)
    df.plot(x='time.s', y=['CONC.A.mol m-3', 'CONC.B.mol m-3', 'CONC.C.mol m-3'], title='Concentration over time', ylabel='Concentration (mol m-3)', xlabel='Time (s)')
    plt.show()

Interactive tutorial notebooks
-------------------------------
Looking for hands on examples of the concepts covered in this guide? Explore our :ref:`Tutorials <tutorials page>` page for detailed, interactive walkthroughs.
