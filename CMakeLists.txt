cmake_minimum_required(VERSION 3.21)
set(CMAKE_USER_MAKE_RULES_OVERRIDE "SetDefaults.cmake")
project(musicbox)
enable_language(Fortran)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

################################################################################
# options

################################################################################
# Create a directory to hold input data

add_custom_target(data-directory ALL COMMAND ${CMAKE_COMMAND} -E make_directory
  ${CMAKE_BINARY_DIR}/data)

################################################################################
# Dependencies

include(cmake/dependencies.cmake)

################################################################################
# MusicBox application

add_subdirectory(src)

################################################################################
# MUSICA tests

enable_testing()
add_subdirectory(test)
