.. _species:

Defining chemical systems
=========================

This section covers the components of a chemical system as defined in MusicBox: Species, Phases, Reactions, and Mechanisms.
As a reminder, this section assumes you have imported::
   
   import musica.mechanism_configuration as mc

Species
--------
Chemical species are the fundamental units that participate in reactions. Define species using the `Species` class::
   
   X = mc.Species(name="X")
   Y = mc.Species(name="Y")
   Z = mc.Species(name="Z")

   species = {"X":X,"Y":Y,"Z":Z}

Species can be initialized with various chemistry-related paramaters (e.g., molecular weight, density, etc.). See the `MUSICA Species
documentation <https://ncar.github.io/musica/api/python.html#musica.mechanism_configuration.Species>`_ for further details.

Phases
-------
Species can be grouped into a phase. Most simple models use a single gas phase::
   
   gas = mc.Phase(name="gas",species=list(species.values()))

Reactions
----------
Reactions are defined with using rate-based classes such as `Arrhenius`.
Each class takes a unique set of rate parameters and the participating species::

   arr1 = mc.Arrhenius(name="X->Y", A=4.0e-3, C=50, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)
   arr2 = mc.Arrhenius(name="Y->Z", A=4.0e-3, C=50, reactants=[species["Y"]], products=[species["Z"]], gas_phase=gas)
   
For passing later on into a `Mechanism`, it is helpful to store your selected reactions into a dictionary::

   rxns = {"X->Y": arr1, "Y->Z": arr2} 

.. note::

   Several other reaction types are made available for use in MusicBox. For a full list of supported reactions types as well as their parameters,
   please see the :ref:`mc:reactions` page in the OpenAtmos Mechanism Configuration documentation.

Mechanisms
----------
A mechanism defines a collection of chemical species, their associated phases, and the reactions between them. Mechanisms can be defined as
follows::

   mechanism = mc.Mechanism(name="tutorial_mechanism", species=list(species.values()), phases=[gas], reactions=list(rxns.values()))