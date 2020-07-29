
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/master/LICENSE) [![Build Status](https://travis-ci.com/NCAR/music-box.svg?branch=master)](https://travis-ci.com/NCAR/music-box)

Copyright (C) 2020 National Center for Atmospheric Research

# Install and run

The fastest way to get started with MusicBox is with Docker. You will need to have [Docker Desktop](https://www.docker.com/get-started) and [git](https://git-scm.com) installed. Then, from a terminal window run:

```
git clone https://github.com/NCAR/MusicBox2
cd MusicBox2
```

To set up the box model with mechanism 272 (Chapman chemistry) from the [Chemistry Cafe](https://chemistrycafe-devel.acom.ucar.edu/index.html#/Tags), run:

```
docker build -t music-box-test . --build-arg TAG_ID=272
docker run -it music-box-test bash
cd build
```

From here, you can specify model parameters and initial conditions, or use one of the test configurations provided in `/examples`, such as:

```
./musicbox ../MusicBox2/examples/dark_chamber/use_case_1.json
```

The results will be in a file named `output.csv`.

# Documentation

MusicBox documentation can be built using [Doxygen](doxygen.nl). After installing Doxygen, from the root MusicBox folder run:

```
cd doc
doxygen
```
Then, open `MusicBox/doc/build/html/index.html` in a browser.

The documentation includes more detailed instructions for configuring the model, along with developer resources.

