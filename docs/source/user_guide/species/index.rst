Chemical species
================

This section covers the definitions and phases of chemical species used in MusicBox. As a reminder, this section assumes you have imported::
   
   import musica.mechanism_configuration as mc

Defining species
----------------
Chemical species are the fundamental units that participate in reactions. Define species using the `species` class::
   
   X = mc.Species(name="X")
   Y = mc.Species(name="Y")
   Z = mc.Species(name="Z")

   species = {"X":X,"Y":Y,"Z":Z}

Defining phases
-----------------
Species can be grouped into a phase. Most simpel models use a single gas phase::
   
   gas = mc.Phase(name="gas",species=list(species.values()))
