"""
An atmospheric chemistry box model. Powered by MUSICA.

This package contains modules for handling various aspects of a music box,
including species, products, reactants, reactions, and more.
"""
__version__ = "3.0.0"

from .utils import convert_time, convert_pressure, convert_temperature, convert_concentration
from .model_options import BoxModelOptions
from .music_box import MusicBox
from .examples import Examples
from .data_output import DataOutput
from .plot_output import PlotOutput
