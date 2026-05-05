#!/usr/bin/env python3
# fileUtils.py
# MusicBox: Utility functions for managing collections of NetCDF files.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import sys
import math
import numbers
import numpy
import xarray
import netCDF4

import logging
logger = logging.getLogger(__name__)


def collectFilesDates(modelDir):
    return []

