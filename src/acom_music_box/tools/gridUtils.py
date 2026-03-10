#!/usr/bin/env python3
# gridUtils.py
# MusicBox: Utility functions for managing straight (WACCM) and curved (WRF-Chem) grids.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import sys
import math
import numbers
import numpy
import xarray
import netCDF4
from acom_music_box.tools import g_geoht

import logging
logger = logging.getLogger(__name__)


kSurfaceKeyword = "surface"     # request is for the surface layer
P0 = 1013.25                    # standard surface pressure in hPa

# Convert altitude in meters to pressure in hPa (hectopascals).
# altMeters = height above sea level (meters)
# return the pressure level in hPa


def altitudeToPressure(altMeters):
    temp = math.exp(-altMeters / 8431.0)
    pressure = P0 * temp
    return pressure


# Convert pressure in hPa (hectopascals) to altitude in meters.
# pressure = atmospheric pressure (hPa)
# return the altitude in meters
def pressureToAltitude(pressure):
    temp = math.log(pressure / P0)
    altitude = -8431.0 * temp
    return altitude


# Return true if variable is int or float, false if not.
def isNumber(myVar):
    return (isinstance(myVar, numbers.Number)
            and not isinstance(myVar, bool))


# Find the nearest value in an array of altitude values.
# value = surface, or a value in meters.
#   Meteorological variables like PBLH are specified in meters before this function is called.
# reversed = values are listed from top of atmosphere to surface (WACCM)
# Return nearest height value and index where it was found
def findNearestAltitude(altitudes, value, reversed=False):
    isNum = isNumber(value)
    # logger.debug(f"value = {value}   isNum = {isNum}")
    if not isNumber(value):
        if (value.lower() == kSurfaceKeyword):
            if (not reversed):
                return [0.0, 0]    # only WRF-Chem
            else:
                return [0.0, len(altitudes) - 1]

    # locate the closest height
    index = (numpy.abs(altitudes - value)).argmin()
    return [altitudes[index], index]


# Calcuate the squared distance between points.
# x1, y1, x2, y2 = coordinates of first and second points
# return the square of the Pythagorean hypotenuse
#   Avoid taking square root for faster calculation
def distSquared(x1, y1, x2, y2):
    return ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))


# constants for marking compass directions
kNoChange = 0
kNorth = 1
kSouth = 2
kEast = 3
kWest = 4

# Search and locate the closest grid point to the specified coordinates.
# This function is applicable for any non-orthogonal projection, not just Lambert Conformal.
# This function will often be called repeatedly for a grid request;
# recycle the previous return values into the init suggestions
# in order to make the nearby searching more efficient.
# wrfChemDataSet = already-open NetCDF file as xarray
# latsVarname, lonsVarname = coordinate variables in the dataset
# latitude, longitude = want to retrieve data at this location
# initLatIndex, initLonIndex = caller's suggestion where to start the search


def findClosestVertex(wrfChemDataSet, latsVarname, lonsVarname,
                      latitude, longitude, initLatIndex=None, initLonIndex=None):
    timeIndex = 0

    latsVar = wrfChemDataSet.get(latsVarname)
    latCoord = latsVar.coords["south_north"]
    numLats = len(latCoord)

    lonsVar = wrfChemDataSet.get(lonsVarname)
    lonCoord = lonsVar.coords["west_east"]
    numLons = len(lonCoord)

    latIndex = initLatIndex
    lonIndex = initLonIndex
    if (latIndex is None):
        # start the search in the middle of the grid
        latIndex = math.floor(numLats / 2)
    if (lonIndex is None):
        lonIndex = math.floor(numLons / 2)

    # make sure that supplied initial indexes are in bounds
    if (latIndex < 0):
        latIndex = 0
    if (lonIndex < 0):
        lonIndex = 0

    if (latIndex >= numLats):
        latIndex = numLats - 1
    if (lonIndex >= numLons):
        lonIndex = numLons - 1

    lats = latsVar.data[timeIndex, :, :]
    lons = lonsVar.data[timeIndex, :, :]
    myLat = lats[latIndex, lonIndex]
    myLon = lons[latIndex, lonIndex]
    numSteps = 0

    logger.debug(f"Starting vertex search at lat = {latIndex} {myLat}   lon = {lonIndex} {myLon}")

    # try to decrease the distance by searching adjacent cells
    while (True):
        # calculate the change in the four compass directions
        currentDist = distSquared(myLat, myLon, latitude, longitude)
        logger.debug(f"currentDist = {currentDist}")
        northChange = southChange = eastWest = westChange = 0.0

        if (latIndex < numLats - 1):
            northChange = distSquared(lats[latIndex + 1, lonIndex], lons[latIndex + 1, lonIndex], latitude, longitude) - currentDist
        if (latIndex > 0):
            southChange = distSquared(lats[latIndex - 1, lonIndex], lons[latIndex - 1, lonIndex], latitude, longitude) - currentDist
        if (lonIndex < numLons - 1):
            eastChange = distSquared(lats[latIndex, lonIndex + 1], lons[latIndex, lonIndex + 1], latitude, longitude) - currentDist
        if (lonIndex > 0):
            westChange = distSquared(lats[latIndex, lonIndex - 1], lons[latIndex, lonIndex - 1], latitude, longitude) - currentDist
        logger.debug(f"Changes are north {northChange} south {southChange} east {eastChange} west {westChange}")

        # which direction will produce the greatest improvement (go closer)?
        goDirection = kNoChange
        goDecrease = 0.0

        if (northChange < goDecrease):
            goDirection = kNorth
            goDecrease = northChange
        if (southChange < goDecrease):
            goDirection = kSouth
            goDecrease = southChange
        if (eastChange < goDecrease):
            goDirection = kEast
            goDecrease = eastChange
        if (westChange < goDecrease):
            goDirection = kWest
            goDecrease = westChange

        logger.debug(f"goDirection = {goDirection}   goDecrease = {goDecrease}")
        if (goDecrease >= 0.0):
            # we can go no closer than the current position
            break

        # move in the best direction
        if (goDirection == kNorth):
            latIndex += 1
        elif (goDirection == kSouth):
            latIndex -= 1
        elif (goDirection == kEast):
            lonIndex += 1
        elif (goDirection == kWest):
            lonIndex -= 1
        numSteps += 1

        myLat = lats[latIndex, lonIndex]
        myLon = lons[latIndex, lonIndex]
        logger.debug(f"\tvertex search now at lat = {latIndex} {myLat}   lon = {lonIndex} {myLon}")

    logger.debug(f"Closest vertex reached in {numSteps} steps.")
    return (latIndex, lonIndex)


# Python cannot take the mean() of strings, so remove them.
# myDataset = contains data variables, some of type string.
# return myDataset with string variables removed
def removeStringVars(myDataset):
    stringVars = []
    for varName, varDataArray in myDataset.data_vars.items():
        if not (numpy.issubdtype(varDataArray.dtype, numpy.number)
                or numpy.issubdtype(varDataArray.dtype, numpy.datetime64)
                or numpy.issubdtype(varDataArray.dtype, numpy.timedelta64)
                ):
            stringVars.append(varName)

    logger.debug(f"removing stringVars = {stringVars}")
    numericDataset = myDataset.drop_vars(stringVars)
    return numericDataset


# Load PBLH and other 2D vars if requested.
# Some model variables (Planetary Boundary Layer Height) can serve
# as the lower or upper bound of the average. Those variables
# do not have a height dimension.
# altParams = pair of command-line args like [surface, PBLH]
# myDataset = WACCM or WRF-Chem data loaded from disk file
# return pointers to height vars in myDataset
def loadHeightVars(altParams, myDataset):
    heightVars = [None, None]
    for hi in range(0, 2):
        if isNumber(altParams[hi]):
            continue
        if (altParams[hi].lower() == kSurfaceKeyword):
            continue

        # get a pointer to that variable
        heightVars[hi] = myDataset[altParams[hi]]

    return heightVars


# Truncate columns in the grid at variable levels like PBLH.
# The truncation could happen at both ends of the column.
# mySubGrid = dataset already selected for time and lat-lon bounds
# altitudePair = altitude bounds in which to select, in meters
# return grid dataset with same lat-lon size but columns are shorter
def cutOffColumns(mySubGrid, altitudePair):
    kPressureKey = "lev"
    mySubPressure = mySubGrid[kPressureKey].data                   # units are hPa
    mySubHeights = numpy.zeros(len(mySubPressure))
    for pi in range(len(mySubPressure)):
        mySubHeights[pi] = pressureToAltitude(mySubPressure[pi])      # units are meters
    logger.debug(f"mySubHeights = {mySubHeights} meters")

    # load PBLH here if requested as some altitude bound
    heightVars = loadHeightVars(altitudePair, mySubGrid)    # meters
    logger.debug(f"Original heightVars = {heightVars}")

    heightPair = altitudePair.copy()      # we will replace PBLH with the numerical value at each grid cell
    logger.debug(f"Starting heightPair = {heightPair} meters")

    # step through the cells of the grid
    singlePoints = []
    for lati in range(mySubGrid.sizes["lat"]):
        for loni in range(mySubGrid.sizes["lon"]):

            # retrieve the PBLH at this grid cell
            for pi in range(0, 2):
                if (heightVars[pi] is not None):
                    heightPair[pi] = float(heightVars[pi].data[lati, loni])
            logger.debug(f"heightPair at {lati}, {loni} = {heightPair}")

            # set up the height bounds for this column
            heightIndexPair = [0, 0]
            for pi in range(0, 2):
                # WACCM uses pressure coordinates from top of atmosphere down to surface,
                # and the user probably specifies from lower altitude to higher.
                dummy, heightIndexPair[1 - pi] = findNearestAltitude(
                    mySubHeights, heightPair[pi], reversed=True)     # reverse the index bounds
            logger.info(f"Height indexes are {heightIndexPair[0]} through {heightIndexPair[1]}")

            # check for variable surfaces that are locally inverted at this grid point
            if (heightPair[0] > heightPair[1]):
                # since lower bound > upper bound at this point, don't include anything
                logger.info("Local surface inversion;, skipping this grid point.")
                continue

            # select only the sub-column
            singlePoint = mySubGrid.isel(
                lev=range(heightIndexPair[0], heightIndexPair[1] + 1),
                lat=lati, lon=loni)
            logger.debug(f"cutOff singlePoint = {singlePoint}")

            # remove string variables for numeric calculation
            singlePoint = removeStringVars(singlePoint)
            logger.debug(f"Numeric singlePoint = {singlePoint}")

            # capture the pressure because vertical coordinate will get removed
            myLev = singlePoint[kPressureKey]
            logger.debug(f"Captured myLev = {myLev}")

            # calculate variable means for the column
            singlePoint = singlePoint.mean(skipna=True, keep_attrs=True)   # take mean within sub-column
            logger.debug(f"Mean singlePoint = {singlePoint}")

            # restore the pressure
            singlePoint[kPressureKey] = myLev.mean()    # mean() preserves the attributes
            logger.debug(f"Mean singlePoint with pressure restored = {singlePoint}")

            singlePoints.append(singlePoint)

    logger.info(f"Combining {len(singlePoints)} cutoff points into a single set...")
    pointDimension = "point_index"
    pointSet = xarray.concat(singlePoints, pointDimension, coords="all")
    logger.debug(f"Cutoff pointSet = {pointSet}")

    return pointSet


# Extract mean values from a lat-lon rectangle within model output.
# As of October 2025, WACCM uses a straight grid (Mercator)
# and WRF-Chem is curved (Lambert Conformal).
# gridDataset = model output from WACCM or WRF-Chem
# when = desired date-time frame of gridDataset
# latPair, lonPair = coordinates of a single point, or bounding box (SW to NE)
# altPair = altitude bounds over which to average
# return the mean value of single point or the bounding box
def meanStraightGrid(gridDataset, when, latPair, lonPair, altPair):
    # find the time index
    whenStr = when.strftime("%Y-%m-%d %H:%M:%S")
    logger.info(f"whenStr = {whenStr}")

    # determine the grid spacing
    latVar = gridDataset["lat"].data
    latStride = latVar[1] - latVar[0]
    lonVar = gridDataset["lon"].data
    lonStride = lonVar[1] - lonVar[0]
    logger.info(f"latStride = {latStride}   lonStride = {lonStride}")

    # use xarray to select sub-grid and then take average
    numGridLats = math.ceil((latPair[1] - latPair[0]) / latStride) + 1      # include the endpoint
    numGridLons = math.ceil((lonPair[1] - lonPair[0]) / lonStride) + 1
    logger.info(f"Requested sub-grid will be {numGridLats} lats x {numGridLons} lons.")

    latTicks = numpy.linspace(latPair[0], latPair[1], numGridLats)
    lonTicks = numpy.linspace(lonPair[0], lonPair[1], numGridLons)
    logger.info(f"latTicks = {latTicks}")
    logger.info(f"lonTicks = {lonTicks}")

    # determine the pressure levels
    pressPair = [None, None]
    fixedHeight = True
    for pi in range(0, 2):
        if isNumber(altPair[pi]):
            pressPair[pi] = altitudeToPressure(altPair[pi])
        elif (altPair[pi].lower() == kSurfaceKeyword):
            pressPair[pi] = kSurfaceKeyword
        else:
            # handle PBLH here; cut off the columns later
            if (pi == 0):
                pressPair[pi] = kSurfaceKeyword
            else:
                pressPair[pi] = 0.0     # pressure at top of atmosphere
            fixedHeight = False

    logger.info(f"Requesting pressure range {pressPair[0]} to {pressPair[1]} hPa")

    # look up pressure levels to get the pressure indexes
    pressLevels = gridDataset["lev"].data
    logger.debug(f"pressLevels = {pressLevels}")
    pressIndexPair = [0, 0]
    for pi in range(0, 2):
        # WACCM uses pressure coordinates from top of atmosphere down to surface,
        # and the user probably specifies from lower altitude to higher.
        dummy, pressIndexPair[1 - pi] = findNearestAltitude(
            pressLevels, pressPair[pi], reversed=True)     # reverse the index bounds
        logger.debug(f"nearest = {dummy} at index {pressIndexPair[1-pi]}")
    logger.info(f"Pressure indexes are {pressIndexPair[0]} through {pressIndexPair[1]}")

    # check for reversed altitude bounds
    if (pressIndexPair[0] > pressIndexPair[1]):
        logger.error("Altitude bounds are reversed. Please specify lower,upper instead.")
        return None

    # select the entire rectanglar region
    cutPressLevels = pressLevels[pressIndexPair[0]: pressIndexPair[1] + 1]
    logger.debug(f"Selecting lev = {cutPressLevels}")
    gridBox = gridDataset.sel(lat=latTicks, lon=lonTicks,
                              lev=cutPressLevels,
                              time=whenStr, method="nearest")
    gridDims = ["lat", "lon"]
    logger.debug(f"gridBox = {gridBox}")

    # cannot take the mean() of strings, so remove them
    gridBox = removeStringVars(gridBox)

    if not fixedHeight:
        # if height bounds are not fixed, then cut off individual columns
        logger.info("Cutting off columns at PBLH.")
        gridBox = cutOffColumns(gridBox, altPair)
        gridDims = ["point_index"]

    logger.info(f"WACCM gridBox = {gridBox}")
    meanPoint = gridBox.mean(dim=gridDims, keep_attrs=True)
    logger.debug(f"meanPoint = {meanPoint}")

    return meanPoint


# Calculate indexes of levels to retrieve in a whole column.
# wholeColumn = altitudes from surface to top of atmosphere
# altitudes[] = lower and upper values to select
# return indexes like [23, 24, 25, 26, 27]
def getSubColumn(wholeColumn, altitudes):
    logger.debug(f"wholeColumn = {wholeColumn} meters")
    dummy, lower = findNearestAltitude(wholeColumn, altitudes[0])
    dummy, upper = findNearestAltitude(wholeColumn, altitudes[1])
    logger.debug(f"lower index = {lower}   upper index = {upper}")
    indexes = list(range(lower, upper + 1))
    return indexes


# Extract mean values from a lat-lon rectangle within model output.
# As of October 2025, WACCM uses a straight grid (Mercator)
# and WRF-Chem is curved (Lambert Conformal).
# gridDataset = model output from WACCM or WRF-Chem
# when = desired date-time frame of gridDataset
# latPair, lonPair = coordinates of a single point, or bounding box (SW to NE)
# altPair = altitude bounds over which to average
# wrfDataset = WRF-Chem file opened as netCDF4 Dataset
# return the mean value of single point or the bounding box
def meanCurvedGrid(gridDataset, when, latPair, lonPair, altPair,
                   wrfDataset):
    # find the time index
    whenStr = when.strftime("%Y-%m-%d_%H:%M:%S")
    logger.info(f"whenStr = {whenStr}")
    timesVar = gridDataset["Times"]
    timesVarStrings = timesVar.str.decode("utf-8")
    stringMatches = numpy.where(timesVarStrings == whenStr)
    timeIndex = stringMatches[0][0]
    logger.info(f"timeIndex = {timeIndex}")

    # estimate the grid spacing
    latVar = gridDataset["XLAT"].data
    latStride = latVar[timeIndex, 1, 0] - latVar[timeIndex, 0, 0]
    lonVar = gridDataset["XLONG"].data
    lonStride = lonVar[timeIndex, 0, 1] - lonVar[timeIndex, 0, 0]
    logger.info(f"latStride = {latStride}   lonStride = {lonStride}")

    # loop through the sub-grid and extract points
    numGridLats = math.ceil((latPair[1] - latPair[0]) / latStride) + 1      # include the endpoint
    numGridLons = math.ceil((lonPair[1] - lonPair[0]) / lonStride) + 1
    logger.info(f"Requested sub-grid will be {numGridLats} lats x {numGridLons} lons.")

    latTicks = numpy.linspace(latPair[0], latPair[1], numGridLats)
    lonTicks = numpy.linspace(lonPair[0], lonPair[1], numGridLons)
    logger.info(f"latTicks = {latTicks}")
    logger.info(f"lonTicks = {lonTicks}")

    # Previously used wrf-python to obtain the z-level grid for this time frame.
    # That code replaced with stripped-down version here. Carl Drews - February 18, 2026
    # zLevels = wrf.getvar(wrfDataset, "z")   # meters
    zLevels = g_geoht.get_height(wrfDataset)
    logger.debug(f"zLevels = {zLevels}")

    # load PBLH here if requested as some altitude bound
    heightVars = loadHeightVars(altPair, gridDataset)
    logger.debug(f"heightVars = {heightVars}")

    heightPair = altPair.copy()      # we will replace PBLH with the numerical value at each grid cell
    logger.debug(f"Starting heightPair = {heightPair}")

    iLat, iLon = None, None
    singlePoints = []
    timeIndex = 0
    for latFloat in latTicks:
        logger.info(f"latFloat = {latFloat}")
        for lonFloat in lonTicks:
            logger.debug(f"\tlatFloat = {latFloat}   lonFloat = {lonFloat}")

            # select data from the nearest grid point
            iLat, iLon = findClosestVertex(gridDataset,
                                           "XLAT", "XLONG", latFloat, lonFloat, iLat, iLon)
            logger.debug(f"iLat = {iLat}   iLon = {iLon}")

            # set up the column bounds for this grid cell
            for pi in range(0, 2):
                if (heightVars[pi] is not None):
                    heightPair[pi] = float(heightVars[pi].data[timeIndex, iLat, iLon])
            logger.debug(f"heightPair at {iLat}, {iLon} = {heightPair}")

            # retrieve the sub-column between the altitude bounds
            verticalIndexes = getSubColumn(zLevels.values[:, iLat, iLon], heightPair)
            logger.info(f"verticalIndexes = {verticalIndexes}")
            if (len(verticalIndexes) == 0):
                logger.debug("\tNo level within those height bounds.")
                continue        # there is no level here within the height range

            singlePoint = gridDataset.isel(Time=timeIndex,
                                           west_east=iLon, south_north=iLat, bottom_top=verticalIndexes)
            logger.debug(f"Sub-column singlePoint = {singlePoint}")

            # calculate variable means for the column
            singlePoint = removeStringVars(singlePoint)
            logger.debug(f"Numeric singlePoint = {singlePoint}")
            singlePoint = singlePoint.mean(skipna=True, keep_attrs=True)   # take mean within sub-column
            logger.debug(f"Mean singlePoint = {singlePoint}")
            singlePoints.append(singlePoint)

    logger.info(f"Combining {len(singlePoints)} points into a single set...")
    pointDimension = "point_index"
    pointSet = xarray.concat(singlePoints, pointDimension)
    logger.debug(f"WACCM / WRF-Chem pointSet = {pointSet}")

    logger.info(f"Calculating mean value of the set...")
    meanPoint = pointSet.mean(dim=[pointDimension], keep_attrs=True)

    return meanPoint
