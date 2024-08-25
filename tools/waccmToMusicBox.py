#!/usr/bin/env python3
# waccmToMusicBox.py
# MusicBox: Extract variables from WACCM model output,
# and convert to initial conditions for MusicBox (case TS1).
#
# Author: Carl Drews
# Copyright 2024 by Atomospheric Chemistry Observations & Modeling (UCAR/ACOM)

#import os
import argparse
#import numpy
import datetime
import xarray
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
      "Nairobi": [-1.2921, 36.8219],
      "Kampala": [0.3476, 32.5825],
      "Kigali": [-1.9441, 30.0619],
      "Dodoma": [-6.1630, 35.7516],
      "Lilongwe": [-13.9626, 33.7741],
      "Lusaka": [-15.3875, 28.3228]
   }

   return(dict(sorted(varMap.items())))



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

    # get the geographical location to retrieve
    lat = None
    if ("latitude" in myArgs):
        lat = safeFloat(myArgs.get("latitude"))

    lon = None
    if ("longitude" in myArgs):
        lon = safeFloat(myArgs.get("longitude"))

    logger.info("Retrieve WACCM conditions at ({} North, {} East)."
        .format(lat, lon))

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error



if (__name__ == "__main__"):
    main()


    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)     # no error



if (__name__ == "__main__"):
    main()

