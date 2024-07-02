from acom_music_box import MusicBox


import math
import datetime
import sys

import logging
logger = logging.getLogger(__name__)



# Retrieve named arguments from the command line and
# return in a dictionary of keywords.
# argPairs = list of arguments, probably from sys.argv
#       named arguments are formatted like this=3.14159
# return dictionary of keywords and values
def getArgsDictionary(argPairs):
   argDict = {}

   for argPair in argPairs:
      # the arguments are: arg=value
      pairValue = argPair.split('=')
      if (len(pairValue) < 2):
         argDict[pairValue[0]] = None
         continue

      argDict[pairValue[0]] = pairValue[1]

   return(argDict)



def main():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger.info("{}".format(__file__))
    logger.info("Start time: {}".format(datetime.datetime.now()))
    
    logger.info("Hello, MusicBox World!")
    

    # retrieve and parse the command-line arguments
    myArgs = getArgsDictionary(sys.argv)
    
    # set up the home configuration directory
    musicBoxHomeDir = "music-box\\tests\\configs\\analytical_config\\"      # default
    if ("homeDir" in myArgs):
        musicBoxHomeDir = myArgs.get("homeDir")
    
    # create and load a MusicBox object
    myBox = MusicBox()
    myBox.readConditionsFromJson(musicBoxHomeDir + "my_config.json")
    logger.info("myBox = {}".format(myBox))

    # create solver and solve
    myBox.create_solver(musicBoxHomeDir + myBox.config_file)
    logger.info("myBox.solver = {}".format(myBox.solver))
    mySolution = myBox.solve(musicBoxHomeDir + "my_solution.csv")
    logger.info("mySolution = {}".format(mySolution))

    logger.info("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)


if __name__ == "__main__":
    main()
