Box model
=========
This section details the components of the box model, a mechanism (the set of reactions and species), conditions, and solutions. To use the MusicBox model, import::
    
    from acom_music_box import MusicBox, Conditions

Using the previously defined in-code mechanism (see :ref:`Defining chemical species <species>`), a box model can now be created and initialized with it::
    
    box_model = MusicBox()
    box_model.load_mechanism(mechanism)

Initial and evolving conditions
--------------------------------
Use `Conditions` to set environmental parameters and species concentrations. Initial conditions define the environment that 
the mechanism takes place in at the start of the simulation through the parameters temperature (K), pressure (Pa), and optionally 
air density. Without an air density provided, the Ideal Gas Law is used to calculate this parameter. The initial concentrations of each
Species is also included::
    
    box_model.initial_conditions = Conditions( temperature=298.15, pressure=101325.0, species_concentrations={"X": 3.75, "Y": 5.0, "Z": 2.5,})

Evolving conditions change the environment of the mechanism at a defined time value (Seconds), its first argument. Like Initial Conditions,
these changes can also include temprature, pressure, air density, and Species concentrations::
    
    box_model.add_evolving_condition(100.0, Conditions(temperature=310.0, pressure=100100.0))

Additional model options
-------------------------
Each box model also contains three time parameters that must be defined:

* simulation_length: the number of time steps that the simulation lasts for
* chem_step_time: the number of time steps between each simulation calculation
* output_step_time: the number of time steps between each output of the model

All three parameters are in seconds::
    
    box_model.box_model_options.simulation_length = 200 # Units: Seconds (s)
    box_model.box_model_options.chem_step_time = 1 # Units: Seconds (s)
    box_model.box_model_options.output_step_time = 20 # Units: Seconds (s)



Loading premade configurations
-------------------------------
In addition to using the steps thus far to define a chemical configuration in code, MusicBox
also supports definitions via a configuration file in JSON format. This example assumes you are using a file called
"custom_box_model.json" in a "config" subfolder::

    import sys

    box_model = MusicBox()
    conditions_path = "config/custom_box_model.json"
    box_model.loadJson(conditions_path)
    df = box_model.solve()

Solving
--------
Once all components of the box model have been defined (in code or via JSON), it can be solved by calling::

    df = box_model.solve()

This returns a dataframe of the conditions and Species concentrations as they've varied across time steps.
