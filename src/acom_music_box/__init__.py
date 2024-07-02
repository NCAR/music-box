"""
This is the music_box package.

This package contains modules for handling various aspects of a music box, 
including species, products, reactants, reactions, and more.
"""
__version__ = "2.1.1"

from .utils import convert_time, convert_pressure, convert_temperature, convert_concentration
from .music_box_species import Species
from .music_box_product import Product
from .music_box_reactant import Reactant
from .music_box_reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
from .music_box_species_list import SpeciesList
from .music_box_model_options import BoxModelOptions
from .music_box_species_concentration import SpeciesConcentration
from .music_box_reaction_rate import ReactionRate
from .music_box_conditions import Conditions

from .music_box_evolving_conditions import EvolvingConditions
from .music_box import MusicBox

