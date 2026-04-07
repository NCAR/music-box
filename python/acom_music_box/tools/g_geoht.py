#!/usr/bin/env python3
# g_geoht.py
# MusicBox: Retrieve height from WRF-Chem dataset.
# Adapted and simplified from wrf-python package.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

from __future__ import (absolute_import, division, print_function)

import xarray
from acom_music_box.tools.destag import destagger
import logging
logger = logging.getLogger(__name__)

kGravityG = 9.81        # m s-2


# Convert netCDF4.Variable to xarray.DataArray
def netcdfVariableToDataArray(netVar):
    data_array = xarray.DataArray(
        data=netVar[:],  # Load the data into a numpy array
        dims=netVar.dimensions,
        attrs=netVar.__dict__
        # coordinates can be trickier to map manually
    )

    return data_array


def _get_geoht(wrfin, timeidx, method="cat", squeeze=True,
               cache=None, meta=True, _key=None,
               height=True, msl=True, stag=False):
    """Return the geopotential or geopotential height.

    If *height* is False, then geopotential is returned in units of
    [m2 s-2].  If *height* is True, then geopotential height is
    returned in units of [m].  If *msl* is True, then geopotential height
    is return as Mean Sea Level (MSL).  If *msl* is False, then geopotential
    height is returned as Above Ground Level (AGL).

    This functions extracts the necessary variables from the NetCDF file
    object in order to perform the calculation.

    Args:

        wrfin (:class:`netCDF4.Dataset`, :class:`Nio.NioFile`, or an \
            iterable): WRF-ARW NetCDF
            data as a :class:`netCDF4.Dataset`, :class:`Nio.NioFile`
            or an iterable sequence of the aforementioned types.

        timeidx (:obj:`int` or :data:`wrf.ALL_TIMES`, optional): The
            desired time index. This value can be a positive integer,
            negative integer, or
            :data:`wrf.ALL_TIMES` (an alias for None) to return
            all times in the file or sequence. The default is 0.

        method (:obj:`str`, optional): The aggregation method to use for
            sequences.  Must be either 'cat' or 'join'.
            'cat' combines the data along the Time dimension.
            'join' creates a new dimension for the file index.
            The default is 'cat'.

        squeeze (:obj:`bool`, optional): Set to False to prevent dimensions
            with a size of 1 from being automatically removed from the shape
            of the output. Default is True.

        cache (:obj:`dict`, optional): A dictionary of (varname, ndarray)
            that can be used to supply pre-extracted NetCDF variables to the
            computational routines.  It is primarily used for internal
            purposes, but can also be used to improve performance by
            eliminating the need to repeatedly extract the same variables
            used in multiple diagnostics calculations, particularly when using
            large sequences of files.
            Default is None.

        meta (:obj:`bool`, optional): Set to False to disable metadata and
            return :class:`numpy.ndarray` instead of
            :class:`xarray.DataArray`.  Default is True.

        _key (:obj:`int`, optional): A caching key. This is used for internal
            purposes only.  Default is None.

        height (:obj:`bool`, optional): Set to True to return geopotential
            height instead of geopotential.  Default is True.

        msl (:obj:`bool`, optional): Set to True to return geopotential height
            as Mean Sea Level (MSL).  Set to False to return the
            geopotential height as Above Ground Level (AGL) by subtracting
            the terrain height.  Default is True.

        stag (:obj:`bool`, optional): Set to True to use the vertical
            staggered grid, rather than the mass grid. Default is False.

    Returns:
        :class:`xarray.DataArray` or :class:`numpy.ndarray`: The
        geopotential or geopotential height.
        If xarray is enabled and the *meta* parameter is True, then the result
        will be a :class:`xarray.DataArray` object.  Otherwise, the result will
        be a :class:`numpy.ndarray` object with no metadata.

    """

    # retrieve the geopotential variables
    ph = wrfin["PH"]        # m2 s-2
    phb = wrfin["PHB"]
    hgt = wrfin["HGT"]      # m
    logger.debug(f"ph = {ph}")

    phArray = netcdfVariableToDataArray(ph).isel(Time=timeidx)
    phbArray = netcdfVariableToDataArray(phb).isel(Time=timeidx)
    hgtArray = netcdfVariableToDataArray(hgt).isel(Time=timeidx)
    logger.debug(f"phArray = {phArray}")

    geopt = phArray + phbArray

    if not stag:
        geopt_unstag = destagger(geopt, -3)
    else:
        geopt_unstag = geopt
    logger.debug(f"geopt_unstag = {geopt_unstag}")

    # calculate the requested height units
    if not height:
        return geopt_unstag

    if msl:
        geoptSeaLevel = geopt_unstag / kGravityG
        geoptSeaLevel.attrs["units"] = "m"
        return geoptSeaLevel

    # subtract the terrain height
    geoptHeight = (geopt_unstag / kGravityG) - hgtArray
    geoptHeight.attrs["units"] = "m"
    return geoptHeight


def get_height(wrfin, timeidx=0, method="cat", squeeze=True,
               cache=None, meta=True, _key=None,
               msl=True, units="m"):
    """Return the geopotential height.

    If *msl* is True, then geopotential height is returned as Mean Sea Level
    (MSL).  If *msl* is False, then geopotential height is returned as
    Above Ground Level (AGL) by subtracting the terrain height.

    This functions extracts the necessary variables from the NetCDF file
    object in order to perform the calculation.

    Args:

        wrfin (:class:`netCDF4.Dataset`, :class:`Nio.NioFile`, or an \
            iterable): WRF-ARW NetCDF
            data as a :class:`netCDF4.Dataset`, :class:`Nio.NioFile`
            or an iterable sequence of the aforementioned types.

        timeidx (:obj:`int` or :data:`wrf.ALL_TIMES`, optional): The
            desired time index. This value can be a positive integer,
            negative integer, or
            :data:`wrf.ALL_TIMES` (an alias for None) to return
            all times in the file or sequence. The default is 0.

        method (:obj:`str`, optional): The aggregation method to use for
            sequences.  Must be either 'cat' or 'join'.
            'cat' combines the data along the Time dimension.
            'join' creates a new dimension for the file index.
            The default is 'cat'.

        squeeze (:obj:`bool`, optional): Set to False to prevent dimensions
            with a size of 1 from being automatically removed from the shape
            of the output. Default is True.

        cache (:obj:`dict`, optional): A dictionary of (varname, ndarray)
            that can be used to supply pre-extracted NetCDF variables to the
            computational routines.  It is primarily used for internal
            purposes, but can also be used to improve performance by
            eliminating the need to repeatedly extract the same variables
            used in multiple diagnostics calculations, particularly when using
            large sequences of files.
            Default is None.

        meta (:obj:`bool`, optional): Set to False to disable metadata and
            return :class:`numpy.ndarray` instead of
            :class:`xarray.DataArray`.  Default is True.

        _key (:obj:`int`, optional): A caching key. This is used for internal

        msl (:obj:`bool`, optional): Set to True to return geopotential height
            as Mean Sea Level (MSL).  Set to False to return the
            geopotential height as Above Ground Level (AGL) by subtracting
            the terrain height.  Default is True.

        units (:obj:`str`): The desired units.  Refer to the :meth:`getvar`
            product table for a list of available units for 'z'.  Default
            is 'm'.

    Returns:
        :class:`xarray.DataArray` or :class:`numpy.ndarray`: The
        geopotential height.
        If xarray is enabled and the *meta* parameter is True, then the result
        will be a :class:`xarray.DataArray` object.  Otherwise, the result will
        be a :class:`numpy.ndarray` object with no metadata.

    """

    return _get_geoht(wrfin, timeidx, method, squeeze, cache, meta, _key,
                      True, msl)
