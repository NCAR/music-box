
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/test.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/test.yml)

Copyright (C) 2020 National Center for Atmospheric Research

# Install and run from local git clone

```
git clone https://github.com/NCAR/music-box
cd music-box
git submodule init
git submodule update
docker build -t music-box .
docker run --rm -it music-box
```

Running those commands will put you in a docker container, at which point you can run

```
cd /music-box/build
make test
```

and you will see tests run, and hopefully pass.

There are a number of examples you can run and modify.

```
cd /music-box/examples/camp_examples/bright_chamber/use_case_7/
/music-box/build/music_box use_case_7_config.json 
```

# Install and run (interactive version)

The only requirement for running MusicBox is that you have [Docker Desktop](https://www.docker.com/get-started) installed and running. With Docker Desktop running, open a terminal window and run the following command: (The first time you run this command, the MusicBox code will be downloaded from Docker Hub, which may take a few minutes.)

```
docker run -p 8000:8000 -it --rm ncar/music-box
```

Leaving the terminal window open, open a web browser and navigate to the following address: [`localhost:8000`](http://localhost:8000). From there, you can configure and run a simulation, plot results, and download the raw model output for further analysis.

When you are ready to stop the MusicBox server, return to the terminal window and stop the server with `Control-C`. If you would like to remove MusicBox from your machine, open a terminal window and run the following command:

```
docker system prune
docker image rm ncar/music-box
```

# Install and run (command-line version)
**[View options for MusicBox configuration](config_options.md)**

You can follow these instructions if you are only interested in using the command-line version of MusicBox and will not be using the browser-based model driver.

You will need to have [Docker Desktop](https://www.docker.com/get-started) installed and running. Then, from a terminal window run:

```
docker run -it --rm ncar/music-box bash
```

## Running MusicBox with the CAMP Solver

CAMP can be specified as the chemical solver by configuring the [model components](config_options.md#model-components) section of the configuration file. To run the model using the CAMP solver under one of the model configurations in the `examples/` folder:
```
cd /build
cp -r examples/camp_examples/dark_chamber/use_case_1/camp_data .
cp examples/camp_examples/dark_chamber/use_case_1/use_case_1_config.json .
./music_box use_case_1_config.json
```



**The results will be in a file named `output.csv`.**



# Documentation

MusicBox documentation can be built using [Doxygen](https://www.doxygen.nl). After [installing](https://www.doxygen.nl/download.html) Doxygen, from the root MusicBox folder run:

```
cd doc
doxygen
```
Then, open `music-box/doc/html/index.html` in a browser.

The documentation includes more detailed instructions for configuring the model, along with developer resources.

