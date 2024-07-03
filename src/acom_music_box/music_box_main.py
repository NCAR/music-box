from acom_music_box import MusicBox


import math
import datetime
import sys

import logging
logger = logging.getLogger(__name__)

import argparse
import os



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
    parser = argparse.ArgumentParser(description='Process some key=value pairs.')
    parser.add_argument(
        'key_value_pairs',
        nargs='+',  # This means one or more arguments are expected
        action=KeyValueAction,
        help='Arguments in key=value format'
    )

    argDict = vars(parser.parse_args(argPairs))      # return dictionary

    return(argDict)



def main():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger.info("{}".format(__file__))
    logger.info("Start time: {}".format(datetime.datetime.now()))
    
    logger.info("Hello, MusicBox World!")
    logger.info("Working directory = {}".format(os.getcwd()))
    
    # retrieve and parse the command-line arguments
    myArgs = getArgsDictionary(sys.argv[1:])
    logger.info("Command line = {}".format(myArgs))

    # set up the home configuration file
    musicBoxConfigFile = "music-box\\tests\\configs\\analytical_config\\my_config.json"      # default
    if ("configFile" in myArgs):
        musicBoxConfigFile = myArgs.get("configFile")

    # set up the output directory
    musicBoxOutputDir = ".\\"      # default
    if ("outputDir" in myArgs):
        musicBoxOutputDir = myArgs.get("outputDir")

    # create and load a MusicBox object
    myBox = MusicBox()
    myBox.readConditionsFromJson(musicBoxConfigFile)
    logger.info("myBox = {}".format(myBox))

    # create solver and solve, writing output to requested directory
    campConfig = os.path.dirname(musicBoxConfigFile) + "\\" + myBox.config_file
    logger.info("CAMP config = {}".format(campConfig))
    myBox.create_solver(campConfig)
    logger.info("myBox.solver = {}".format(myBox.solver))
    mySolution = myBox.solve(musicBoxOutputDir + "\\my_solution.csv")
    logger.info("mySolution = {}".format(mySolution))

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)


if __name__ == "__main__":
    main()
