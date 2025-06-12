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

Phases
-------
Species can be grouped into a phase. Most simple models use a single gas phase::
   
   gas = mc.Phase(name="gas",species=list(species.values()))
