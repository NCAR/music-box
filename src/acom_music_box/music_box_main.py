from acom_music_box import MusicBox

import math
import datetime
import sys

import music_box_logger



if __name__ == "__main__":
    music_box_logger.progress("{}".format(__file__))
    music_box_logger.progress("Start time: {}".format(datetime.datetime.now()))
    
    music_box_logger.progress("Hello, MusicBox World!")
    
    # set up the home configuration directory TODO: Make this a command-line argument.
    musicBoxHomeDir = "C:\\2024\\MusicBox\\music-box\\tests\\configs\\analytical_config\\"
    
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
