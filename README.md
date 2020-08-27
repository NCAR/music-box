
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/master/LICENSE) [![Build Status](https://travis-ci.com/NCAR/music-box.svg?branch=master)](https://travis-ci.com/NCAR/music-box)

Copyright (C) 2020 National Center for Atmospheric Research

# Install and run

The fastest way to get started with MusicBox is with Docker. You will need to have [Docker Desktop](https://www.docker.com/get-started) installed. Then, from a terminal window run:

```
docker run -it --rm ncar/music-box bash
```

By default, MusicBox loads the Chapman chemistry mechanism. To run the model with this mechanism under one of the model configurations in the `examples/` folder:

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

