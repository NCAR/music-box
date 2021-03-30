
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE) [![Build Status](https://travis-ci.com/NCAR/music-box.svg?branch=main)](https://travis-ci.com/NCAR/music-box)

Copyright (C) 2020 National Center for Atmospheric Research

# Install and run (interactive version)

The only requirement for running MusicBox is that you have [Docker Desktop](https://www.docker.com/get-started) installed and running. With Docker Desktop running, open a terminal window and run the following command: (The first time you run this command, the MusicBox code will be downloaded from Docker Hub, which may take a few minutes.)
```
docker image pull ncar/music-box
```
Then, run Music Box.
```
docker run -p 8000:8000 -it --rm ncar/music-box
```

Leaving the terminal window open, open a web browser and navigate to the following address: [`localhost:8000`](http://localhost:8000). From there, you can configure and run a simulation, plot results, and download the raw model output for further analysis.

When you are ready to stop the MusicBox server, return to the terminal window and stop the server with `Control-C`. If you would like to remove MusicBox from your machine, open a terminal window and run the following command:

```
docker image rm ncar/music-box
```

# Install and run (command-line version)

You can follow these instructions if you are only interested in using the command-line version of MusicBox and will not be using the browser-based model driver.

You will need to have [Docker Desktop](https://www.docker.com/get-started) installed and running. Then, from a terminal window run:

```
docker run -it --rm ncar/music-box bash
```

By default, MusicBox loads the Chapman chemistry mechanism for simulations using MICM. To run the model with this mechanism under one of the model configurations in the `examples/` folder:

```
cd /build
cp examples/bright_chamber/use_case_4.json .
cp examples/bright_chamber/use_case_4_initial.csv data/
./music_box use_case_4.json
```

The results will be in a file named `output.csv`.

To set up the box model with a different mechanism from the [Public Chemistry Cafe Mechanism Store](https://www.acom.ucar.edu/cafe), run:

```
/change_mechanism.sh T1mozcart
```

# Documentation

MusicBox documentation can be built using [Doxygen](https://www.doxygen.nl). After [installing](https://www.doxygen.nl/download.html) Doxygen, from the root MusicBox folder run:

```
cd doc
doxygen
```
Then, open `music-box/doc/html/index.html` in a browser.

The documentation includes more detailed instructions for configuring the model, along with developer resources.

