cmake_minimum_required(VERSION 3.12)
project(MusicBox)
enable_language(Fortran)

################################################################################
# MusicBox library

add_subdirectory(src)

################################################################################
# MusicBox application

add_subdirectory(apps)

################################################################################
# MusicBox tests

enable_testing()
add_subdirectory(test)
