Output and visualization
========================
MusicBox supports the visualization of simulation results, with integration of `Matplotlib <https://matplotlib.org>`_ for customization. Matplotlib
comes installed with MusicBox. To utilize it, first::

    import matplotlib.pyplot as plt

Then, specific results of your box model simulation can be visualized::

    df.plot(x='time.s', y=['CONC.X.mol m-3', 'CONC.Y.mol m-3', 'CONC.Z.mol m-3'], title='Concentration over time', ylabel='Concentration (mol m-3)', xlabel='Time (s)')
    plt.show()  


