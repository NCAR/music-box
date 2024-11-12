
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://badge.fury.io/py/acom-music-box)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14008358.svg)](https://doi.org/10.5281/zenodo.14008358)


Copyright (C) 2020 National Center for Atmospheric Research

# Installation
```
pip install acom_music_box
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

Output can be saved to a file in csv file when no `--output-format` is passed

```
music_box -e Chapman -o output.csv
```

Output can be saved to a file as csv file when `--output-format` csv is passed

```
music_box --output-format csv -e Chapman -o output.csv
```

Output can be saved to a file as netcdf file when `--output-format` netcdf is passed

```
music_box --output-format netcdf -e Chapman -o output.nc
```

Output can be saved to a file in csv file to output.csv when no output path is given but `--output-format` is csv

```
music_box --output-format csv -e Chapman
```

Output can be saved to a file in netcdf file to output.nc when no output path is given but `--output-format` is netcdf

```
music_box --output-format netcdf -e Chapman
```

You can also run your own configuration

```
music_box -c my_config.json
```

And, if you have gnuplot installed, some basic plots can be made to show some resulting concentrations

```
music_box -e Chapman -o output.csv --color-output --plot CONC.O1D
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
