#!/usr/bin/env python3
# waccmToMusicBox.py
# MusicBox: Extract variables from WACCM model output,
# and convert to initial conditions for MusicBox (case TS1).
#
# Author: Carl Drews
# Copyright 2024 by Atmospheric Chemistry Observations & Modeling (UCAR/ACOM)

# import os
import argparse
import datetime
import xarray
import json
import sys
import os
import shutil
import tempfile
import zipfile
from acom_music_box import Examples
from acom_music_box.utils import calculate_air_density

import logging
logger = logging.getLogger(__name__)
import math
import numpy



# configure argparse for key-value pairs
class KeyValueAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        for value in values:
            key, val = value.split('=')
            setattr(namespace, key, val)

# Retrieve named arguments from the command line and
# return in a dictionary of keywords.
# argPairs = list of arguments, probably from sys.argv[1:]
#       named arguments are formatted like this=3.14159
# return dictionary of keywords and values


def getArgsDictionary(argPairs):
    parser = argparse.ArgumentParser(
        description='Process some key=value pairs.')
    parser.add_argument(
        'key_value_pairs',
        nargs='+',  # This means one or more arguments are expected
        action=KeyValueAction,
        help="Arguments in key=value format. Example: configFile=my_config.json"
    )

    argDict = vars(parser.parse_args(argPairs))      # return dictionary

    return (argDict)


# Convert safely from string to integer (alphas convert to 0).
def safeInt(intString):
    intValue = 0
    try:
        intValue = int(intString)
    except ValueError as error:
        intValue = 0

    return intValue


# Convert string to number, or 0.0 if not numeric.
# numString = string that probably can be converted
def safeFloat(numString):
    result = -1.0
    try:
        result = float(numString)
    except ValueError:
        result = 0.0

    return result


# Create and return list of WACCM chemical species
# that will be mapped to MUSICA.
# modelDir = directory containing model output
# waccmFilename = name of WACCM model output file
# return list of variable names
def getWaccmSpecies(modelDir, waccmFilename):
    # create the filename
    logger.info(f"WACCM species file = {waccmFilename}")

    # open dataset for reading
    waccmDataSet = xarray.open_dataset(os.path.join(modelDir, waccmFilename))

    # collect the data variables
    waccmNames = [varName for varName in waccmDataSet.data_vars]

    # To do: remove extraneous non-chemical vars like date and time
    # Idea: use the dimensions to filter out non-chemicals

    # close the NetCDF file
    waccmDataSet.close()

    return (waccmNames)


# Create list of chemical species in MUSICA,
# corresponding to the same chemical species in WACCM.
# templateDir = directory containing configuration files and camp_data
# return list of variable names
def getMusicaSpecies(templateDir):
    # find the standard configuration file and parse it
    myConfigFile = os.path.join(templateDir, "camp_data", "species.json")
    with open(myConfigFile) as jsonFile:
        myConfig = json.load(jsonFile)

    # locate the section for chemical species
    chemSpeciesTag = "camp-data"
    chemSpecies = myConfig[chemSpeciesTag]

    # retrieve just the names
    musicaNames = []
    for spec in chemSpecies:
        specName = spec.get("name")
        if (specName):
            musicaNames.append(spec.get("name"))

    return (musicaNames)


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
            "PS": "pressure",
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
    waccmOnly = [species for species in waccmSpecies if species not in musicaSpecies]
    musicaOnly = [species for species in musicaSpecies if species not in waccmSpecies]
    if (len(waccmOnly) > 0):
        logger.warning(f"The following chemical species are only in WACCM: {waccmOnly}")
    if (len(musicaOnly) > 0):
        logger.warning(f"The following chemical species are only in MUSICA: {musicaOnly}")

    # build the dictionary
    # To do: As of September 4, 2024 this is not much of a map,
    # as most of the entries are identical. We may map additional
    # pairs in the future. This map is still useful in identifying
    # the common species between WACCM and MUSICA.
    if (modelType == WACCM_OUT):
        varMap = {
            "T": "temperature",
            "PS": "pressure"
        }
    elif (modelType == WRFCHEM_OUT):
        varMap = {
            # WRF-Chem: MusicBox
            "T2": "temperature",
            "P": "pressure",
            "isopr": "ISOPB02",
            "o3": "O3"
        }

    logger.info(f"inCommon = {inCommon}")
    for varName in inCommon:
        varMap[varName] = varName

    return (varMap)


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

    infoSearch = False
    if (infoSearch):
        logger.info(f"Starting vertex search at lat = {latIndex} {myLat}   lon = {lonIndex} {myLon}")

    # try to decrease the distance by searching adjacent cells
    while (True):
        # calculate the change in the four compass directions
        currentDist = distSquared(myLat, myLon, latitude, longitude)
        if (infoSearch):
            logger.info(f"currentDist = {currentDist}")
        northChange = southChange = eastWest = westChange = 0.0

        if (latIndex < numLats - 1):
            northChange = distSquared(lats[latIndex + 1, lonIndex], lons[latIndex + 1, lonIndex], latitude, longitude) - currentDist
        if (latIndex > 0):
            southChange = distSquared(lats[latIndex - 1, lonIndex], lons[latIndex - 1, lonIndex], latitude, longitude) - currentDist
        if (lonIndex < numLons - 1):
            eastChange = distSquared(lats[latIndex, lonIndex + 1], lons[latIndex, lonIndex + 1], latitude, longitude) - currentDist
        if (lonIndex > 0):
            westChange = distSquared(lats[latIndex, lonIndex - 1], lons[latIndex, lonIndex - 1], latitude, longitude) - currentDist
        if (infoSearch):
            logger.info(f"Changes are north {northChange} south {southChange} east {eastChange} west {westChange}")

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

        if (infoSearch):
            logger.info(f"goDirection = {goDirection}   goDecrease = {goDecrease}")
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
        if (infoSearch):
            logger.info(f"\tvertex search now at lat = {latIndex} {myLat}   lon = {lonIndex} {myLon}")

    if (False):
        logger.info(f"Closest vertex reached in {numSteps} steps.")
    return (latIndex, lonIndex)


# Extract mean values from a lat-lon rectangle within model output.
# As of October 2025, WACCM uses a straight grid (Mercator)
# and WRF-Chem is curved (Lambert Conformal).
# gridDataset = model output from WACCM or WRF-Chem
# when = desired date-time frame of gridDataset
# latPair, lonPair = coordinates of a single point, or bounding box (SW to NE)
def meanStraightGrid(gridDataset, when, latPair, lonPair):
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
                               lev=1000.0, time=whenStr, method="nearest")

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

    return meanPoint


# Extract mean values from a lat-lon rectangle within model output.
# As of October 2025, WACCM uses a straight grid (Mercator)
# and WRF-Chem is curved (Lambert Conformal).
# gridDataset = model output from WACCM or WRF-Chem
# when = desired date-time frame of gridDataset
# latPair, lonPair = coordinates of a single point, or bounding box (SW to NE)
def meanCurvedGrid(gridDataset, when, latPair, lonPair):
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

    infoGrid = False

    iLat, iLon = None, None
    singlePoints = []
    for latFloat in latTicks:
        for lonFloat in lonTicks:
            if (infoGrid):
                logger.info(f"latFloat = {latFloat}   lonFloat = {lonFloat}")

            # select data from the nearest grid point
            iLat, iLon = findClosestVertex(gridDataset, "XLAT", "XLONG",
                latFloat, lonFloat, iLat, iLon)
            if (infoGrid):
                logger.info(f"iLat = {iLat}   iLon = {iLon}")
            singlePoint = gridDataset.isel(Time=timeIndex,
                west_east=iLon, south_north=iLat, bottom_top=0)
            singlePoints.append(singlePoint)

    logger.info(f"Combining {len(singlePoints)} points into a single set...")
    pointDimension = "point_index"
    pointSet = xarray.concat(singlePoints, pointDimension)
    if (False):
        logger.info(f"WACCM / WRF-Chem pointSet = {pointSet}")

    logger.info(f"Calculating mean value of the set...")
    meanPoint = pointSet.mean(dim=[pointDimension], keep_attrs=True)

    return meanPoint


# Read array values at a single lat-lon-time point.
# waccmMusicaDict = mapping from WACCM names to MusicBox
# latitudes, longitudes = geo-coordinates of retrieval point(s)
#   Could be a single point or corners of a selection rectangle.
# when = date and time to extract
# modelDir = directory containing model output
# waccmFilename = name of the model output file
# modelType = WACCM_OUT or WRFCHEM_OUT
# return dictionary of MUSICA variable names, values, and units
def readWACCM(waccmMusicaDict, latitudes, longitudes,
              when, modelDir, waccmFilename, modelType):

    waccmFilepath = os.path.join(modelDir, waccmFilename)
    logger.info(f"WACCM file path = {waccmFilepath}")

    # open dataset for reading
    waccmDataSet = xarray.open_dataset(waccmFilepath)
    if (False):
        # diagnostic to look at dataset structure
        logger.info(f"WACCM dataset = {waccmDataSet}")

    # retrieve all vars at a single point
    meanPoint = None
    if (modelType == WACCM_OUT):            # straight grid
        meanPoint = meanStraightGrid(waccmDataSet, when,
            latitudes, longitudes)

    elif (modelType == WRFCHEM_OUT):        # curved grid
        meanPoint = meanCurvedGrid(waccmDataSet, when,
            latitudes, longitudes)

    if (True):
        # diagnostic to look at single point structure
        logger.info(f"WACCM / WRF-Chem meanPoint = {meanPoint}")

    # loop through vars and build another dictionary
    musicaDict = {}
    for waccmKey, musicaName in waccmMusicaDict.items():
        if waccmKey not in meanPoint:
            logger.warning(f"Requested variable {waccmKey} not found in WACCM model output.")
            musicaTuple = (waccmKey, None, None)
            musicaDict[musicaName] = musicaTuple
            continue

        chemSinglePoint = meanPoint[waccmKey]
        if (True):
            logger.info(f"WACCM chemical {waccmKey} = value {chemSinglePoint.values} {chemSinglePoint.units}")
        musicaTuple = (waccmKey, float(chemSinglePoint.values.mean()), chemSinglePoint.units)   # from 0-dim array
        musicaDict[musicaName] = musicaTuple

    # close the NetCDF file
    waccmDataSet.close()

    return (musicaDict)


# Add molecular Nitrogen, Oxygen, and Argon to dictionary.
# varValues = already read from WACCM, contains (name, concentration, units)
# return varValues with N2, O2, and Ar added
def addStandardGases(varValues):
    varValues["N2"] = ("N2", 0.78084, "mol/mol")    # standard fraction by volume
    varValues["O2"] = ("O2", 0.20946, "mol/mol")
    varValues["Ar"] = ("Ar", 0.00934, "mol/mol")

    return (varValues)


# set up indexes for the tuple
musicaIndex = 0
valueIndex = 1
unitIndex = 2

# Perform any numeric conversion needed.
# varDict = originally read from WACCM, tuples are (musicaName, value, units)
# return varDict with values modified


def convertWaccm(varDict):
    # from the supporting documents
    # https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1029%2F2019MS001882&file=jame21103-sup-0001-2019MS001882+Text_SI-S01.pdf
    soa_molecular_weight = 0.115  # kg mol-1
    soa_density = 1770  # kg m-3

    # retrieve temperature and pressure from WACCM
    temperature = varDict["temperature"][valueIndex]
    pressure = varDict["pressure"][valueIndex]
    logger.info(f"temperature = {temperature} K   pressure = {pressure} Pa")
    air_density = calculate_air_density(temperature, pressure)
    logger.info(f"air density = {air_density} mol m-3")

    for key, vTuple in varDict.items():
        # convert moles / mole to moles / cubic meter
        units = vTuple[unitIndex]
        if (units == "mol/mol"):
            varDict[key] = (vTuple[0], vTuple[valueIndex] * air_density, "mol m-3")
        if (units == "kg/kg"):
            # soa species only
            varDict[key] = (vTuple[0], vTuple[valueIndex] * soa_density / soa_molecular_weight, "mol m-3")

    return (varDict)


# Determines if chemical "name" is an environmental variable or not.
# return True for temperature, pressure, ...
def isEnvironment(varName):
    if (varName.lower() in {"temperature", "pressure"}):
        return (True)

    return (False)


# Write CSV file suitable for initial_conditions.csv in MusicBox.
# initValues = dictionary of Musica varnames and (WACCM name, value, units)
def writeInitCSV(initValues, filename):
    fp = open(filename, "w")

    # write the column titles
    firstColumn = True
    for key, value in initValues.items():
        if (firstColumn):
            firstColumn = False
        else:
            fp.write(",")

        reaction_type = "CONC"
        if isEnvironment(key):
            reaction_type = "ENV"

        fp.write("{}.{} [{}]".format(reaction_type, key, value[unitIndex]))
    fp.write("\n")

    # write the variable values
    firstColumn = True
    for key, value in initValues.items():
        if (firstColumn):
            firstColumn = False
        else:
            fp.write(",")

        fp.write(f"{value[valueIndex]}")
    fp.write("\n")

    fp.close()
    return


# Write JSON fragment suitable for my_config.json in MusicBox.
# initValues = dictionary of Musica varnames and (WACCM name, value, units)
def writeInitJSON(initValues, filename):

    # set up dictionary of vars and initial values
    dictName = "chemical species"
    initConfig = {dictName: {}}

    for key, value in initValues.items():
        initConfig[dictName][key] = {f"initial value [{value[unitIndex]}]": value[valueIndex]}

    # write JSON content to the file
    fpJson = open(filename, "w")

    json.dump(initConfig, fpJson, indent=2)
    fpJson.close()

    fpJson.close()
    return


# Reproduce the MusicBox configuration with new initial values and write to config.zip in the current directory
# initValues = dictionary of Musica varnames and (WACCM name, value, units)
# templateDir = directory containing configuration files and camp_data
def insertIntoTemplate(initValues, templateDir):
    with tempfile.TemporaryDirectory() as temp_dir:
        # copy the template directory to a new 'configuration' folder
        destPath = os.path.join(temp_dir, 'configuration')
        logger.info(f"Create new configuration in = {destPath}")

        # copy the template directory
        shutil.copytree(templateDir, destPath)

        # find the standard configuration file and parse it
        myConfigFile = os.path.join(destPath, "my_config.json")
        with open(myConfigFile) as jsonFile:
            myConfig = json.load(jsonFile)

        # retrieve temperature and pressure
        temperature = 0.0
        pressure = 0.0
        key = "temperature"
        if key in initValues:
            temperature = safeFloat(initValues[key][valueIndex])
        key = "pressure"
        if key in initValues:
            pressure = safeFloat(initValues[key][valueIndex])

        # replace the values of temperature and pressure
        envConditionsTag = "environmental conditions"
        envConfig = myConfig[envConditionsTag]
        envConfig["temperature"]["initial value [K]"] = temperature
        envConfig["pressure"]["initial value [Pa]"] = pressure

        # save over the former json file
        with open(myConfigFile, "w") as myConfigFp:
            json.dump(myConfig, myConfigFp, indent=2)

        # Create a zip file that contains the 'configuration' folder
        zip_path = os.path.join(os.getcwd(), 'config.zip')
        with zipfile.ZipFile(zip_path, 'w') as zipf:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    # Ensure the files are zipped under 'configuration' directory
                    zipf.write(file_path, os.path.relpath(file_path, temp_dir))

        logger.info(f"Configuration zipped to {zip_path}")


# type of model output in directory
WACCM_OUT = 1
WRFCHEM_OUT = 2
modelNames = [None, "waccm", "wrf-chem"]


# Main routine begins here.
def main():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger.info(f"{__file__}")
    logger.info(f"Start time: {datetime.datetime.now()}")

    # retrieve and parse the command-line arguments
    myArgs = getArgsDictionary(sys.argv[1:])
    logger.info(f"Command line = {myArgs}")

    # set up the directories
    waccmDir = None
    if ("waccmDir" in myArgs):
        waccmDir = myArgs.get("waccmDir")

    wrfChemDir = None
    if ("wrfchemDir" in myArgs):
        wrfChemDir = myArgs.get("wrfchemDir")

    musicaDir = os.path.dirname(Examples.WACCM.path)
    if ("musicaDir" in myArgs):
        musicaDir = myArgs.get("musicaDir")

    template = os.path.dirname(Examples.TS1.path)
    if ("template" in myArgs):
        template = myArgs.get("template")

    # get the date-time to retrieve
    dateStr = None
    if ("date" in myArgs):
        dateStr = myArgs.get("date")

    timeStr = "00:00"
    if ("time" in myArgs):
        timeStr = myArgs.get("time")

    # get the geographical location(s) to retrieve
    lats = []
    if ("latitude" in myArgs):
        latStrings = myArgs.get("latitude").split(",")
        for latString in latStrings:
            lats.append(safeFloat(latString))

    lons = []
    if ("longitude" in myArgs):
        lonStrings = myArgs.get("longitude").split(",")
        for lonString in lonStrings:
            lons.append(safeFloat(lonString))

    # fix common lat-lon errors
    if (len(lats) > 1):
        if (lats[0] > lats[1]):
            # swap latitudes
            lats = [lats[1], lats[0]]

    # always use two lat-lon bounds
    if (len(lats) < 2):
        lats.append(lats[0])
    if (len(lons) < 2):
        lons.append(lons[0])

    # For longitude, we assume the user knows the model's
    # longitude conventions regarding 0:360 or -180:180.

    logger.info(f"lats = {lats}   lons = {lons}")

    # get the requested (diagnostic) output
    outputCSV = False
    outputJSON = False
    insertIntoConfig = False
    if ("output" in myArgs):
        # parameter is like: output=CSV,JSON
        outputFormats = myArgs.get("output").split(",")
        outputFormats = [lowFormat.lower() for lowFormat in outputFormats]
        outputCSV = "csv" in outputFormats
        outputJSON = "json" in outputFormats

    for modelDir, modelType in zip(
        [waccmDir, wrfChemDir], [WACCM_OUT, WRFCHEM_OUT]):
        if not modelDir:
            continue

        logger.info(f"Directory: {modelDir}   type {modelType}")

        # locate the WACCM output file
        when = datetime.datetime.strptime(
            f"{dateStr} {timeStr}", "%Y%m%d %H:%M")
        if (modelType == WACCM_OUT):
            waccmFilename = f"f.e22.beta02.FWSD.f09_f09_mg17.cesm2_2_beta02.forecast.001.cam.h3.{when.year:4d}-{when.month:02d}-{when.day:02}-00000.nc"
        elif (modelType == WRFCHEM_OUT):
            waccmFilename = f"wrfout_hourly_d01_{when.year:4d}-{when.month:02d}-{when.day:02}_{when.hour:02d}:00:00"

        # read and glean chemical species from WACCM and MUSICA
        waccmChems = getWaccmSpecies(modelDir, waccmFilename)
        musicaChems = getMusicaSpecies(template)

        # create map of species common to both WACCM and MUSICA
        commonDict = getMusicaDictionary(modelType, waccmChems, musicaChems)
        logger.info(f"Species in common are = {commonDict}")
        if (len(commonDict) == 0):
            logger.warning("There are no common species between WACCM and your MUSICA species.json file.")

        # Read named variables from WACCM model output.
        logger.info(f"Retrieve WACCM conditions at ({lats} North, {lons} East)   when {when}.")
        varValues = readWACCM(commonDict, lats, lons, when,
            modelDir, waccmFilename, modelType)
        logger.info(f"Original WACCM varValues = {varValues}")

        # add molecular Nitrogen, Oxygen, and Argon
        varValues = addStandardGases(varValues)

        # Perform any conversions needed, or derive variables.
        varValues = convertWaccm(varValues)
        logger.info(f"Converted WACCM varValues = {varValues}")

        if (outputCSV):
            # Write CSV file for MusicBox initial conditions.
            csvName = os.path.join(musicaDir,
                "initial_conditions-{}.csv".format(modelNames[modelType]))
            logger.info(f"csvName = {csvName}")
            writeInitCSV(varValues, csvName)

        if (outputJSON):
            # Write JSON file for MusicBox initial conditions.
            jsonName = os.path.join(musicaDir,
                "initial_config-{}.json".format(modelNames[modelType]))
            logger.info(f"jsonName = {jsonName}")
            writeInitJSON(varValues, jsonName)

        if (insertIntoConfig):
            logger.info(f"Insert values into template {template}")
            insertIntoTemplate(varValues, template)

    logger.info(f"End time: {datetime.datetime.now()}")


if (__name__ == "__main__"):
    main()
    logger.info(f"End time: {datetime.datetime.now()}")
    sys.exit(0)  # no error

