#!/usr/bin/env python3
# gridUtils.py
# MusicBox: Utility functions for managing straight (WACCM) and curved (WRF-Chem) grids.
#
# Author: Carl Drews
# Copyright 2026 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

import math

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

