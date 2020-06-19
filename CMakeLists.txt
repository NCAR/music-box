cmake_minimum_required(VERSION 3.12)
project(MUSICA)
enable_language(Fortran)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

################################################################################
# options

option(ENABLE_NETCDF "Enable NetCDF for input/output" ON)

################################################################################
# NetCDF library

if(ENABLE_NETCDF)
  find_path(NETCDF_INCLUDE_DIR netcdf.mod NETCDF.mod
    DOC "NetCDF include directory (must contain netcdf.mod)"
    PATHS
      $ENV{NETCDF_HOME}/include
      /usr/lib/gfortran/modules
      /usr/lib64/gfortran/modules
      /opt/local/include)
  find_library(NETCDF_C_LIB netcdf
    DOC "NetCDF C library"
    PATHS
      $ENV{NETCDF_HOME}/lib
      $ENV{NETCDF_HOME}/lib64
      opt/local/lib)
  find_library(NETCDF_FORTRAN_LIB netcdff
    DOC "NetCDF Fortran library"
    PATHS
      $ENV{NETCDF_HOME}/lib
      $ENV{NETCDF_HOME}/lib64
      /opt/local/lib)
  set(NETCDF_LIBS ${NETCDF_C_LIB})
  if(NETCDF_FORTRAN_LIB)
    set(NETCDF_LIBS ${NETCDF_LIBS} ${NETCDF_FORTRAN_LIB})
  endif()
  include_directories(${NETCDF_INCLUDE_DIR})
  add_definitions(-DMUSICA_USE_NETCDF)
endif()

################################################################################
# json-fortran library

find_path(JSON_INCLUDE_DIR json_module.mod
  DOC "json-fortran include directory (must include json_*.mod files)"
  PATHS
    $ENV{JSON_FORTRAN_HOME}/lib
    /opt/local/lib
    /usr/local/lib
    /usr/local/lib64)
find_library(JSON_LIB jsonfortran
  DOC "json-fortran library"
  PATHS
    $ENV{JSON_FORTRAN_HOME}/lib
    /opt/local/lib
    /usr/local/lib)
include_directories(${JSON_INCLUDE_DIR})

################################################################################
# MUSICA library

add_subdirectory(src)

################################################################################
# MusicBox application

add_subdirectory(apps)

################################################################################
# MUSICA tests

enable_testing()
add_subdirectory(test)
