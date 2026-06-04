#!/usr/bin/env python3
# speciesMap.py
# MusicBox: Provide mapping of chemical species
# from the atmospheric models (WACCM, WRF-Chem) to MusicBox.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

# import os
import pathvalidate
import argparse
import datetime
import xarray
import json
import sys
import os
import shutil
import tempfile
import zipfile
from acom_music_box import Examples, __version__
from acom_music_box.utils import calculate_air_density
import netCDF4
from acom_music_box.tools import gridUtils
from acom_music_box.tools import fileUtils
from acom_music_box import conditions_manager
import copy

import logging
logger = logging.getLogger(__name__)


# Build and return dictionary of WACCM variable names
# and their MusicBox equivalents.
# waccmSpecies = list of variable names in the WACCM model output
# musicaSpecies = list of variable names in species.json
# return ordered dictionary
def getMusicaDictionary(modelType, waccmSpecies=None, musicaSpecies=None):
    if ((waccmSpecies is None) or (musicaSpecies is None)):
        logger.warning("No species map found for WACCM or MUSICA.")

        # build a simple species map
        varMap = {
            "T": "temperature",
            "lev": "pressure",      # WACCM sigma pressure coordinates
            "N2O": "N2O",
            "H2O2": "H2O2",
            "O3": "O3",
            "NH3": "NH3",
            "CH4": "CH4"
        }

        return (dict(sorted(varMap.items())))

    # create new list of species common to both lists
    inCommon = sorted([species for species in waccmSpecies if species in musicaSpecies])

    # provide some diagnostic warnings
    # If these messages are crucially important, change to logger.warning().
    waccmOnly = [species for species in waccmSpecies if species not in musicaSpecies]
    musicaOnly = [species for species in musicaSpecies if species not in waccmSpecies]
    if (len(waccmOnly) > 0):
        logger.info(f"The following chemical species are only in WACCM: {waccmOnly}")
    if (len(musicaOnly) > 0):
        logger.info(f"The following chemical species are only in MUSICA: {musicaOnly}")

    # build the dictionary
    # To do: As of September 4, 2024 this is not much of a map,
    # as most of the entries are identical. We may map additional
    # pairs in the future. This map is still useful in identifying
    # the common species between WACCM and MUSICA.
    if (modelType == fileUtils.WACCM_File):
        varMap = {
            # WACCM: MusicBox
            "T": "temperature",
            "lev": "pressure"       # sigma pressure coordinates
        }
    elif (modelType == fileUtils.WRF_Chem_File):
        varMap = {
            # WRF-Chem: MusicBox
            "T2": "temperature",
            "PB": "pressure"
        }

    for varName in inCommon:
        varMap[varName] = varName

    return (varMap)

