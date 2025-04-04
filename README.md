
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![codecov](https://codecov.io/github/NCAR/music-box/graph/badge.svg?token=OR7JEQJSRQ)](https://codecov.io/github/NCAR/music-box)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://badge.fury.io/py/acom-music-box)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14008358.svg)](https://doi.org/10.5281/zenodo.14008358)


Copyright (C) 2020 National Science Foundation - National Center for Atmospheric Research

# Installation
```
pip install acom-music-box
```

# Command line tool
MusicBox provides a command line tool that can run configurations as well as some pre-configured examples. Basic plotting can be done if gnuplot is installed.

Checkout the command line options

```
music_box -h                                        
```

Run an example. Notice that the output, in csv format, is printed to the terminal.

```
music_box -e Chapman
```

Output can be saved to a csv file (the default format) and printed to the terminal.

```
music_box -e Chapman -o output
```

Output can be saved to a csv file by specifying the .csv extension for Comma-Separated Values.

```
music_box -e Chapman -o output.csv
```

Output can be saved to a file as netcdf file by specifying the .nc file extension.

```
music_box -e Chapman -o output.nc
```

Output can be saved to a file in csv format when a filename is not specified. In this case a timestamped csv file is made.

```
music_box -e Chapman
```

You may also specify multiple output files with different formats, using the file extension.

```
music_box -e Analytical -o results.csv -o results.nc
```

You can also run your own configuration

```
music_box -c my_config.json
```

## Plotting
Some basic plots can be made to show concentrations throughout the simulation

### matplotlib

```
music_box -e Chapman -o output.csv --plot O1D
```

You can also make multiple plots by specifying groupings of species

```
music_box -e TS1 --plot O3 --plot PAN,HF 
```

Note that the windows may overlap each other

By default all plot units are in `mol m-3`. You can see a list of unit options to specify with `--plot-output-unit`

```
music_box -h
```

It is used like this

```
 music_box -e TS1 --plot O3 --plot-output-unit "ppb"
```

### gnuplot
If you want ascii plots (maybe you're running over ssh and can't view a graphical window), you can set
the plot tool to gnuplo (`--plot-tool gnuplot`) to view some output

```
music_box -e Chapman -o output.csv --plot O1D --plot-tool gnuplot
```

# Development and Contributing

For local development, install `music-box` as an editable installation:

```
pip install -e '.[dev]'
```

## Tests

```
pytest
```
