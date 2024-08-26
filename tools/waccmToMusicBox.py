#!/usr/bin/env python3
# waccmToMusicBox.py
# MusicBox: Extract variables from WACCM model output,
# and convert to initial conditions for MusicBox (case TS1).
#
# Author: Carl Drews
# Copyright 2024 by Atomospheric Chemistry Observations & Modeling (UCAR/ACOM)

#import os
import argparse
import datetime
import xarray
import json
import sys

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



# Build and return dictionary of WACCM variable names
# and their MusicBox equivalents.
def getMusicaDictionary():
   varMap = {
      "T": "temperature",
      "PS": "pressure",
      "H2O": "H2O",
      "TEPOMUC": "jtepo",   # test var not in WACCM
      "BENZENE": "jbenzene",
      "O3": "O3",
      "NH3": "NH3",
      "CH4": "CH4",
      "O": "O"             # test var not in WACCM
   }

   return(dict(sorted(varMap.items())))



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
  if (True):
    # diagnostic to look at dataset structure
    logger.info("WACCM dataset = {}".format(waccmDataSet))

  # retrieve all vars at a single point
  whenStr = when.strftime("%Y-%m-%d %H:%M:%S")
  logger.info("whenStr = {}".format(whenStr))
  singlePoint = waccmDataSet.sel(lon=longitude, lat=latitude, lev=1000.0,
    time=whenStr, method="nearest")
  if (True):
    # diagnostic to look at single point structure
    logger.info("WACCM singlePoint = {}".format(singlePoint))

  # loop through vars and build another dictionary
  musicaDict = {}
  for waccmKey, musicaName in waccmMusicaDict.items():
    logger.info("WACCM Chemical = {}".format(waccmKey))
    if not waccmKey in singlePoint:
      logger.warning("Requested variable {} not found in WACCM model output."
        .format(waccmKey))
      musicaTuple = (waccmKey, None, None)
      musicaDict[musicaName] = musicaTuple
      continue

    chemSinglePoint = singlePoint[waccmKey]
    if (True):
      logger.info("{} = object {}".format(waccmKey, chemSinglePoint))
      logger.info("{} = value {} {}".format(waccmKey, chemSinglePoint.values, chemSinglePoint.units))
    musicaTuple = (waccmKey, float(chemSinglePoint.values.mean()), chemSinglePoint.units)   # from 0-dim array
    musicaDict[musicaName] = musicaTuple

  # close the NetCDF file
  waccmDataSet.close()

  return(musicaDict)



# set up indexes for the tuple
musicaIndex = 0
valueIndex = 1
unitIndex = 2

# Perform any numeric conversion needed.
# varDict = originally read from WACCM, tuples are (musicaName, value, units)
# return varDict with values modified
def convertWaccm(varDict):
  # convert Ammonia to milli-moles
  nh3Tuple = varDict["NH3"]
  varDict["NH3"] = (nh3Tuple[0], nh3Tuple[valueIndex] * 1000, "milli" + nh3Tuple[2])
  return(varDict)



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
  initConfig = {dictName: {} }

  for key, value in initValues.items():
    initConfig[dictName][key] = {
      "initial value [{}]".format(value[unitIndex]): value[valueIndex]}

  # write JSON content to the file
  fpJson = open(filename, "w")

  json.dump(initConfig, fpJson, indent=2)
  fpJson.close()

  fpJson.close()
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

    logger.info("Retrieve WACCM conditions at ({} North, {} East)   when {}."
        .format(lat, lon, retrieveWhen))

    # Read named variables from WACCM model output.
    varValues = readWACCM(getMusicaDictionary(),
      lat, lon, retrieveWhen, waccmDir)
    logger.info("Original WACCM varValues = {}".format(varValues))

    # Perform any conversions needed, or derive variables.
    varValues = convertWaccm(varValues)
    logger.info("Converted WACCM varValues = {}".format(varValues))

    if (False):
      # Write CSV file for MusicBox initial conditions.
      csvName = "{}/{}".format(musicaDir, "initial_conditions.csv")
      writeInitCSV(varValues, csvName)

    else:
      # Write JSON file for MusicBox initial conditions.
      jsonName = "{}/{}".format(musicaDir, "initial_config.json")
      writeInitJSON(varValues, jsonName)

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error



if (__name__ == "__main__"):
    main()


    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error



if (__name__ == "__main__"):
    main()

