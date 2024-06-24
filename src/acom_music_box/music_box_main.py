from acom_music_box import MusicBox

import math
import datetime
import sys

import music_box_logger



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



if __name__ == "__main__":
    music_box_logger.progress("{}".format(__file__))
    music_box_logger.progress("Start time: {}".format(datetime.datetime.now()))
    
    music_box_logger.progress("Hello, MusicBox World!")
    
    # retrieve and parse the command-line arguments
    myArgs = getArgsDictionary(sys.argv)
    
    # set up the home configuration directory
    musicBoxHomeDir = "music-box\\tests\\configs\\analytical_config\\"      # default
    if ("homeDir" in myArgs):
        musicBoxHomeDir = myArgs.get("homeDir")
    
    # create and load a MusicBox object
    myBox = MusicBox()
    myBox.readConditionsFromJson(musicBoxHomeDir + "my_config.json")
    music_box_logger.progress("myBox = {}".format(myBox))

    # create solver and solve
    myBox.create_solver(musicBoxHomeDir + myBox.config_file)
    mySolution = myBox.solve()
    music_box_logger.progress("mySolution = {}".format(mySolution))

    music_box_logger.progress("End time: {}".format(datetime.datetime.now()))
    sys.exit(0)
