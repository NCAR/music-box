cmake_minimum_required(VERSION 3.21)

project(
  musicbox
  VERSION 2.0.0
  LANGUAGES CXX
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH};${PROJECT_SOURCE_DIR}/cmake")

################################################################################
# options

option(MUSIC_BOX_ENABLE_MEMCHECK "Enable memory checking in tests" OFF)

################################################################################
# Dependencies

include(cmake/dependencies.cmake)

################################################################################
# MusicBox application

add_subdirectory(src)

################################################################################
# MUSICA tests

if(PROJECT_IS_TOP_LEVEL)
  include(CTest)
  enable_testing()
  add_subdirectory(test)
endif()
