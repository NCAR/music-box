from acom_music_box import MusicBox

import math
import sys



# Display progress message on the console.
# endString = set this to '' for no return
def progress(message, endString='\n'):
    if (True):   # disable here in production
        print(message, end=endString)
        sys.stdout.flush()



if __name__ == "__main__":
    progress("Hello, MusicBox World!")
    sys.exit(0)
