
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://badge.fury.io/py/acom-music-box)

Copyright (C) 2020 National Center for Atmospheric Research

# Installation

The project is configured to be installed using `pip` by the `pyproject.toml` file. 

To install the `music-box` package into a Python environment, run the following command from the root directory:

```
pip install .
```

The package is also available on PyPi and can be installed in any Python environment through:

```
pip install acom_music_box
```

# Tests

After installing music box for local development `pip install -e .`

```
cd tests
pytest
```

# Command line tool
MusicBox provides a command line tool that can run configurations as well as some pre-configured examples. Basic plotting can be done if gnuplot is installed.

```
music_box -h                                        
usage: music_box [-h] [-c CONFIG] [-e {CB5,Chapman,FlowTube,Analytical}] [-o OUTPUT] [-v] [--color-output] [--plot PLOT]

MusicBox simulation runner.

optional arguments:
  -h, --help            show this help message and exit
  -c CONFIG, --config CONFIG
                        Path to the configuration file. If --example is provided, this argument is ignored.
  -e {CB5,Chapman,FlowTube,Analytical}, --example {CB5,Chapman,FlowTube,Analytical}
                        Name of the example to use. Overrides --config.
                        Available examples:
                        CB5: Carbon bond 5
                        Chapman: The Chapman cycle with conditions over Boulder, Colorado
                        FlowTube: A fictitious flow tube experiment
                        Analytical: An example of an analytical solution to a simple chemical system
  -o OUTPUT, --output OUTPUT
                        Path to save the output file, including the file name. If not provided, result will be printed to the console.
  -v, --verbose         Increase logging verbosity. Use -v for info, -vv for debug.
  --color-output        Enable color output for logs.
  --plot PLOT           Plot a comma-separated list of species if gnuplot is available (e.g., CONC.A,CONC.B).
```

To run one of the examples and plot something you would run

```
music_box -e Chapman -o output.csv -vv --color-output --plot CONC.O1D
```
