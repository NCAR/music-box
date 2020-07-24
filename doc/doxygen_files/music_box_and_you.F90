
!> \page music_box_and_you MusicBox and You
!!
!! \anchor music_box_and_you_installing
!! ### Installing ###
!!
!! The simplest option for running MusicBox is using [Docker Desktop]
!! (https://www.docker.com/get-started) , which does
!! not require MusicBox to be installed locally. Instructions for
!! running MusicBox with Docker Desktop are in the MusicBox
!! [README](https://github.com/NCAR/music-box).
!!
!! MusicBox has a number of dependencies that must be available for a
!! local installation including fortran and c compilers, NetCDF, python,
!! Node.js, CMake, and json-fortran. Until more detailed instructions
!! are provided, the easiest way to install MusicBox on a new system is
!! by following the workflow described in the \c Dockerfile in the root
!! \c music-box directory.
!!
!! \todo add detailed installation instructions to documentation
!!
!! \anchor music_box_and_you_input_data
!! ### Input Data ###
!!
!! \todo add input data documentation as new input data sources are
!!       allowed
!!
!! \anchor music_box_and_you_running
!! ### Running the Model ###
!!
!! The MusicBox executable takes a single command-line argument, which
!! is the path to a model configuration file:
!! \code{.f90}
!!   ./music_box config.json
!! \endcode
!!
!! A number of example configurations are located in the \c
!! music-box/examples folder, with descriptions of the example scenario
!! and instructions for use.
!!
!! \anchor music_box_and_you_results
!! ### Results ###
!!
!! \todo add description of results to documentation
!!
