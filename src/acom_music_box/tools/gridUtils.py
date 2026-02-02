#!/usr/bin/env python3
# gridUtils.py
# MusicBox: Utility functions for managing straight (WACCM) and curved (WRF-Chem) grids.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import math
import numpy
import xarray

import logging
logger = logging.getLogger(__name__)


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

    gridBox = gridDataset.sel(lat=latTicks, lon=lonTicks,
    #                          lev=1000.0, time=whenStr, method="nearest")   # surface
                              lev=[1000.0, 900, 800, 700, 450], time=whenStr, method="nearest")   # surface
    logger.debug(f"gridBox = {gridBox}")

    # cannot take the mean() of strings, so remove them
    stringVars = []
    for varName, varDataArray in gridBox.data_vars.items():
        if not (numpy.issubdtype(varDataArray.dtype, numpy.number)
                or numpy.issubdtype(varDataArray.dtype, numpy.datetime64)
                or numpy.issubdtype(varDataArray.dtype, numpy.timedelta64)
                ):
            stringVars.append(varName)
    logger.info(f"removing stringVars = {stringVars}")
    gridBox = gridBox.drop_vars(stringVars)

    logger.info(f"WACCM gridBox = {gridBox}")
    meanPoint = gridBox.mean(dim=["lat", "lon"], keep_attrs=True)
    logger.debug(f"meanPoint = {meanPoint}")

    return meanPoint


# Extract mean values from a lat-lon rectangle within model output.
# As of October 2025, WACCM uses a straight grid (Mercator)
# and WRF-Chem is curved (Lambert Conformal).
# gridDataset = model output from WACCM or WRF-Chem
# when = desired date-time frame of gridDataset
# latPair, lonPair = coordinates of a single point, or bounding box (SW to NE)
# altPair = altitude bounds over which to average
# return the mean value of single point or the bounding box
def meanCurvedGrid(gridDataset, when, latPair, lonPair, altPair):
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

    iLat, iLon = None, None
    singlePoints = []
    for latFloat in latTicks:
        for lonFloat in lonTicks:
            logger.debug(f"latFloat = {latFloat}   lonFloat = {lonFloat}")

            # select data from the nearest grid point
            iLat, iLon = findClosestVertex(gridDataset,
                "XLAT", "XLONG", latFloat, lonFloat, iLat, iLon)
            logger.debug(f"iLat = {iLat}   iLon = {iLon}")
            singlePoint = gridDataset.isel(Time=timeIndex,
            #                               west_east=iLon, south_north=iLat, bottom_top=0)  # surface
                                           west_east=iLon, south_north=iLat, bottom_top=[0,17, 23, 33, 41])  # surface
            singlePoints.append(singlePoint)
            logger.debug(f"singlePoint = {singlePoint}")

    logger.info(f"Combining {len(singlePoints)} points into a single set...")
    pointDimension = "point_index"
    pointSet = xarray.concat(singlePoints, pointDimension)
    logger.debug(f"WACCM / WRF-Chem pointSet = {pointSet}")

    logger.info(f"Calculating mean value of the set...")
    meanPoint = pointSet.mean(dim=[pointDimension], keep_attrs=True)

    return meanPoint

