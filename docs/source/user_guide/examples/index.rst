Running premade examples
========================
MusicBox provides a selection of pre-made example configurations for the user to work with:

* Analytical
* CarbonBond5
* Chapman
* FlowTube
* TS1
* WACCM

Each example (found in `src/acom_music_box/examples`) includes an associated set of JSON files acccessible through the Examples class::

    from acom_music_box import MusicBox, Examples
    import matplotlib.pyplot as plt
    
    box_model = MusicBox()
    conditions_path = Examples.Analytical.path
    box_model.loadJson(conditions_path)
    df = box_model.solve()
    display(df)
    df.plot(x='time.s', y=['CONC.A.mol m-3', 'CONC.B.mol m-3', 'CONC.C.mol m-3'], title='Concentration over time', ylabel='Concentration (mol m-3)', xlabel='Time (s)')
    plt.show()