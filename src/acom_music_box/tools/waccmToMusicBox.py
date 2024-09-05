#!/usr/bin/env python3
# waccmToMusicBox.py
# MusicBox: Extract variables from WACCM model output,
# and convert to initial conditions for MusicBox (case TS1).
#
# Author: Carl Drews
# Copyright 2024 by Atomospheric Chemistry Observations & Modeling (UCAR/ACOM)

# import os
import argparse
import datetime
import xarray
import json
import sys
import os
import shutil

import logging
logger = logging.getLogger(__name__)


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
# when = date and time to extract
# modelDir = directory containing model output
# return list of variable names
def getWaccmSpecies(when, modelDir):
    # create the filename
    waccmFilename = ("f.e22.beta02.FWSD.f09_f09_mg17.cesm2_2_beta02.forecast.001.cam.h3.{:4d}-{:02d}-{:02}-00000.nc"
                     .format(when.year, when.month, when.day))
    logger.info("WACCM species file = {}".format(waccmFilename))

    # open dataset for reading
    waccmDataSet = xarray.open_dataset("{}/{}".format(modelDir, waccmFilename))

    # collect the data variables
    waccmNames = [varName for varName in waccmDataSet.data_vars]

    # To do: remove extraneous non-chemical vars like date and time
    # Idea: use the dimensions to filter out non-chemicals

    # close the NetCDF file
    waccmDataSet.close()

    return(waccmNames)


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

    return(musicaNames)


# Build and return dictionary of WACCM variable names
# and their MusicBox equivalents.
# waccmSpecies = list of variable names in the WACCM model output
# musicaSpecies = list of variable names in species.json
# return ordered dictionary
def getMusicaDictionary(waccmSpecies=None, musicaSpecies=None):
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
    inCommon = [species for species in waccmSpecies if species in musicaSpecies]
    inCommon.sort()

    # provide some diagnostic warnings
    waccmOnly = [species for species in waccmSpecies if not species in musicaSpecies]
    musicaOnly = [species for species in musicaSpecies if not species in waccmSpecies]
    if (len(waccmOnly) > 0):
        logger.warning("The following chemical species are only in WACCM: {}".format(waccmOnly))
    if (len(musicaOnly) > 0):
        logger.warning("The following chemical species are only in MUSICA: {}".format(musicaOnly))

    # build the dictionary
    # To do: As of September 4, 2024 this is not much of a map,
    # as most of the entries are identical. We may map additional
    # pairs in the future. This map is still useful in identifying
    # the common species between WACCM and MUSICA.
    varMap = {
        "T": "temperature",
        "PS": "pressure"
    }

    logger.info("inCommon = {}".format(inCommon))
    for varName in inCommon:
        varMap[varName] = varName

    return(varMap)


# Read array values at a single lat-lon-time point.
# waccmMusicaDict = mapping from WACCM names to MusicBox
# latitude, longitude = geo-coordinates of retrieval point
# when = date and time to extract
# modelDir = directory containing model output
# return dictionary of MUSICA variable names, values, and units
def readWACCM(waccmMusicaDict, latitude, longitude,
              when, modelDir):

    # create the filename
    waccmFilename = ("f.e22.beta02.FWSD.f09_f09_mg17.cesm2_2_beta02.forecast.001.cam.h3.{:4d}-{:02d}-{:02}-00000.nc"
                     .format(when.year, when.month, when.day))
    logger.info("WACCM file = {}".format(waccmFilename))

    # open dataset for reading
    waccmDataSet = xarray.open_dataset("{}/{}".format(modelDir, waccmFilename))
    if (False):
        # diagnostic to look at dataset structure
        logger.info("WACCM dataset = {}".format(waccmDataSet))

    # retrieve all vars at a single point
    whenStr = when.strftime("%Y-%m-%d %H:%M:%S")
    logger.info("whenStr = {}".format(whenStr))
    singlePoint = waccmDataSet.sel(lon=longitude, lat=latitude, lev=1000.0,
                                   time=whenStr, method="nearest")
    if (False):
        # diagnostic to look at single point structure
        logger.info("WACCM singlePoint = {}".format(singlePoint))

    # loop through vars and build another dictionary
    musicaDict = {}
    for waccmKey, musicaName in waccmMusicaDict.items():
        if waccmKey not in singlePoint:
            logger.warning("Requested variable {} not found in WACCM model output."
                           .format(waccmKey))
            musicaTuple = (waccmKey, None, None)
            musicaDict[musicaName] = musicaTuple
            continue

        chemSinglePoint = singlePoint[waccmKey]
        if (True):
            logger.info("WACCM chemical {} = value {} {}".format(waccmKey, chemSinglePoint.values, chemSinglePoint.units))
        musicaTuple = (waccmKey, float(chemSinglePoint.values.mean()), chemSinglePoint.units)   # from 0-dim array
        musicaDict[musicaName] = musicaTuple

    # close the NetCDF file
    waccmDataSet.close()

    return (musicaDict)


# Calculate air density from the ideal gas law.
# tempK = temperature in degrees Kelvin
# pressPa = pressure in Pascals
# return density of air in moles / cubic meter
def calcAirDensity(tempK, pressPa):
    BOLTZMANN_CONSTANT = 1.380649e-23       # joules / Kelvin
    AVOGADRO_CONSTANT = 6.02214076e23       # / mole
    GAS_CONSTANT = BOLTZMANN_CONSTANT * AVOGADRO_CONSTANT   # joules / Kelvin-mole
    airDensity = pressPa / (GAS_CONSTANT * tempK)           # moles / m3

    return (airDensity)


# set up indexes for the tuple
musicaIndex = 0
valueIndex = 1
unitIndex = 2

# Perform any numeric conversion needed.
# varDict = originally read from WACCM, tuples are (musicaName, value, units)
# return varDict with values modified


def convertWaccm(varDict):

    # retrieve temperature and pressure from WACCM
    temperature = varDict["temperature"][valueIndex]
    pressure = varDict["pressure"][valueIndex]
    logger.info("temperature = {} K   pressure = {} Pa".format(temperature, pressure))
    air_density = calcAirDensity(temperature, pressure)
    logger.info("air density = {} mol m-3".format(air_density))

    for key, vTuple in varDict.items():
        # convert moles / mole to moles / cubic meter
        units = vTuple[unitIndex]
        if (units == "mol/mol"):
            varDict[key] = (vTuple[0], vTuple[valueIndex] * air_density, "mol m-3")

    return (varDict)


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

        fp.write(key)
    fp.write("\n")

    # write the variable values
    firstColumn = True
    for key, value in initValues.items():
        if (firstColumn):
            firstColumn = False
        else:
            fp.write(",")

        fp.write("{}".format(value[valueIndex]))
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
        initConfig[dictName][key] = {
            "initial value [{}]".format(value[unitIndex]): value[valueIndex]}

    # write JSON content to the file
    fpJson = open(filename, "w")

    json.dump(initConfig, fpJson, indent=2)
    fpJson.close()

    fpJson.close()
    return


# Reproduce the MusicBox configuration with new initial values.
# initValues = dictionary of Musica varnames and (WACCM name, value, units)
# templateDir = directory containing configuration files and camp_data
# destDir = the template will be created in this directory
def insertIntoTemplate(initValues, templateDir, destDir):

    # copy the template directory to working area
    destZip = os.path.basename(os.path.normpath(templateDir))
    destPath = os.path.join(destDir, destZip)
    logger.info("Create new configuration in = {}".format(destPath))

    # remove directory if it already exists
    if os.path.exists(destPath):
        shutil.rmtree(destPath)

    # copy the template directory
    shutil.copytree(templateDir, destPath)

    # find the standard configuration file and parse it
    myConfigFile = os.path.join(destPath, "my_config.json")
    with open(myConfigFile) as jsonFile:
        myConfig = json.load(jsonFile)

    # locate the section for chemical concentrations
    chemSpeciesTag = "chemical species"
    chemSpecies = myConfig[chemSpeciesTag]
    logger.info("Replace chemSpecies = {}".format(chemSpecies))
    del myConfig[chemSpeciesTag]     # delete the existing section

    # set up dictionary of chemicals and initial values
    chemValueDict = {}
    temperature = 0.0
    pressure = 0.0
    for key, value in initValues.items():
        if (key == "temperature"):
            temperature = safeFloat(value[valueIndex])
            continue
        if (key == "pressure"):
            pressure = safeFloat(value[valueIndex])
            continue

        chemValueDict[key] = {
            "initial value [{}]".format(value[unitIndex]): value[valueIndex]}

    myConfig[chemSpeciesTag] = chemValueDict

    # replace the values of temperature and pressure
    envConditionsTag = "environmental conditions"
    envConfig = myConfig[envConditionsTag]
    envConfig["temperature"]["initial value [K]"] = temperature
    envConfig["pressure"]["initial value [Pa]"] = pressure

    # save over the former json file
    with open(myConfigFile, "w") as myConfigFp:
        json.dump(myConfig, myConfigFp, indent=2)

    # compress the written directory as a zip file
    shutil.make_archive(destPath, "zip",
                        root_dir=destDir, base_dir=destZip)

    # move into the created directory
    shutil.move(destPath + ".zip", destPath)

    return


# Main routine begins here.
def main():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger.info("{}".format(__file__))
    logger.info("Start time: {}".format(datetime.datetime.now()))

    # retrieve and parse the command-line arguments
    myArgs = getArgsDictionary(sys.argv[1:])
    logger.info("Command line = {}".format(myArgs))

    # set up the directories
    waccmDir = None
    if ("waccmDir" in myArgs):
        waccmDir = myArgs.get("waccmDir")

    musicaDir = None
    if ("musicaDir" in myArgs):
        musicaDir = myArgs.get("musicaDir")

    # get the date-time to retrieve
    dateStr = None
    if ("date" in myArgs):
        dateStr = myArgs.get("date")

    timeStr = "00:00"
    if ("time" in myArgs):
        timeStr = myArgs.get("time")

    # get the geographical location to retrieve
    lat = None
    if ("latitude" in myArgs):
        lat = safeFloat(myArgs.get("latitude"))

    lon = None
    if ("longitude" in myArgs):
        lon = safeFloat(myArgs.get("longitude"))

    retrieveWhen = datetime.datetime.strptime(
        "{} {}".format(dateStr, timeStr), "%Y%m%d %H:%M")

    template = None
    if ("template" in myArgs):
        template = myArgs.get("template")

    # read and glean chemical species from WACCM and MUSICA
    waccmChems = getWaccmSpecies(retrieveWhen, waccmDir)
    musicaChems = getMusicaSpecies(template)

    # create map of species common to both WACCM and MUSICA
    commonDict = getMusicaDictionary(waccmChems, musicaChems)
    logger.info("Species in common are = {}".format(commonDict))
    if (len(commonDict) == 0):
        logger.warning("There are no common species between WACCM and your MUSICA species.json file.")

    # Read named variables from WACCM model output.
    logger.info("Retrieve WACCM conditions at ({} North, {} East)   when {}."
                .format(lat, lon, retrieveWhen))
    varValues = readWACCM(commonDict,
                          lat, lon, retrieveWhen, waccmDir)
    logger.info("Original WACCM varValues = {}".format(varValues))

    # Perform any conversions needed, or derive variables.
    varValues = convertWaccm(varValues)
    logger.info("Converted WACCM varValues = {}".format(varValues))

    if (True):
        # Write CSV file for MusicBox initial conditions.
        csvName = "{}/{}".format(musicaDir, "initial_conditions.csv")
        writeInitCSV(varValues, csvName)

    if (True):
        # Write JSON file for MusicBox initial conditions.
        jsonName = "{}/{}".format(musicaDir, "initial_config.json")
        writeInitJSON(varValues, jsonName)

    if (True and template is not None):
        logger.info("Insert values into template {}".format(template))
        insertIntoTemplate(varValues, template, musicaDir)

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error


if (__name__ == "__main__"):
    main()

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error


if (__name__ == "__main__"):
    main()
