
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/test.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/test.yml)

Copyright (C) 2020 National Center for Atmospheric Research

# CMake build

The cmake creates an executable called `music_box`, as well as a set of tests.

## Windows

```
mkdir build
cd build
cmake ..
cmake --build . --config Release
ctest -C Release --output-on-failure
```

## Linux, Mac

```
mkdir build
cd build
cmake ..
make
make test
```

# Docker

To build the docker image

```
docker build -t music_box .
docker run --rm -it music_box
```
