Box model
=========
.. note::
    
    MusicBox uses the Model-Independent Chemical Module (MICM) as its core chemistry solver. For more information about available reaction types,
    species configuration, and solver behavior, see the `MICM documentation <micm:index>`_.

This section details the components of the box model, a mechanism (the set of reactions and species), conditions, and solutions. To use the MusicBox model,
import the :class:`acom_music_box.music_box.MusicBox` class::
    
    from acom_music_box import MusicBox, Conditions

Using the previously defined in-code mechanism (see :ref:`Defining chemical systems <species>`), a box model can now be created and initialized with it::
    
    box_model = MusicBox()
    box_model.load_mechanism(mechanism)

Initial and evolving conditions
--------------------------------
Use :class:`acom_music_box.conditions.Conditions` to set environmental parameters and species concentrations (:math:`\textsf{mol m}^{-3}`). Initial conditions define the environment that 
the mechanism takes place in at the start of the simulation through the parameters temperature (K), pressure (Pa), and optionally 
air density. Without an air density provided, the Ideal Gas Law is used to calculate this parameter. The initial concentrations of each
Species is also included::
    
    box_model.initial_conditions = Conditions( temperature=298.15, pressure=101325.0, species_concentrations={"X": 3.75, "Y": 5.0, "Z": 2.5,})

Evolving conditions (see :class:`acom_music_box.evolving_conditions.EvolvingConditions`) change the environment of the mechanism at a defined time value (Seconds), its first argument. Like importnitial conditions,
these changes can also include temperature, pressure, air density, and Species concentrations::
    
    box_model.add_evolving_condition(100.0, Conditions(temperature=310.0, pressure=100100.0))

Additional model options
-------------------------
Each box model also contains three time parameters that must be defined:

* simulation_length: the number of seconds that the simulation lasts for
* chem_step_time: the number of time steps between each simulation calculation
* output_step_time: the number of seconds between each output of the model

See :mod:`acom_music_box.model_options` for further details. The time parameters can be used as follows::
    
    box_model.box_model_options.simulation_length = 200 # Units: Seconds (s)
    box_model.box_model_options.chem_step_time = 1 # Units: Seconds (s)
    box_model.box_model_options.output_step_time = 20 # Units: Seconds (s)

For further descriptions of these MusicBox attributes, please see the `API Reference <https://ncar.github.io/music-box/branch/main/api/index.html>`_.

Solving
--------
Once all components of the box model have been defined, it can be solved by calling::

    df = box_model.solve()

This returns the following dataframe of the conditions and Species concentrations as they've varied across time steps.

+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|    |   time.s |   ENV.temperature.K |   ENV.pressure.Pa |   ENV.air number density.mol m-3 |   CONC.X.mol m-3 |   CONC.Y.mol m-3 |   CONC.Z.mol m-3 |
+====+==========+=====================+===================+==================================+==================+==================+==================+
|  0 |        0 |              298.15 |            101325 |                          40.874  |          3.75    |          5       |          2.5     |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  1 |       20 |              298.15 |            101325 |                          40.874  |          3.41149 |          4.8714  |          2.96711 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  2 |       40 |              298.15 |            101325 |                          40.874  |          3.10354 |          4.72528 |          3.42118 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  3 |       60 |              298.15 |            101325 |                          40.874  |          2.82338 |          4.56584 |          3.86077 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  4 |       80 |              298.15 |            101325 |                          40.874  |          2.56852 |          4.39669 |          4.28479 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  5 |      100 |              298.15 |            101325 |                          40.874  |          2.33666 |          4.22086 |          4.69247 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  6 |      120 |              310    |            100100 |                          38.8363 |          2.12702 |          4.04212 |          5.08087 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  7 |      140 |              310    |            100100 |                          38.8363 |          1.93618 |          3.86147 |          5.45235 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  8 |      160 |              310    |            100100 |                          38.8363 |          1.76247 |          3.6807  |          5.80683 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
|  9 |      180 |              310    |            100100 |                          38.8363 |          1.60434 |          3.50128 |          6.14438 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+
| 10 |      200 |              310    |            100100 |                          38.8363 |          1.4604  |          3.32443 |          6.46517 |
+----+----------+---------------------+-------------------+----------------------------------+------------------+------------------+------------------+


Loading premade configurations (optional)
------------------------------------------
As an alternative to defining a chemical configuration in code, MusicBox also supports loading
from a JSON configuration file. See :ref:`Configuration Files <configuration>` for a full
description of the JSON format. This example assumes you are using a file called
"custom_box_model.json" in a "config" subfolder::

    import sys

    box_model = MusicBox()
    conditions_path = "config/custom_box_model.json"
    box_model.loadJson(conditions_path)
    df = box_model.solve()
