################################################################################
# MUSICA library

include(FetchContent)

FetchContent_Declare(musicacore
  GIT_REPOSITORY https://github.com/NCAR/musica-core.git
  GIT_TAG 25ef3ab
  FIND_PACKAGE_ARGS NAMES musicacore
)

FetchContent_MakeAvailable(musicacore)

################################################################################
# NetCDF library

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
    /usr/local/lib
    /usr/local/lib64)
include_directories(${JSON_INCLUDE_DIR})

################################################################################
# GSL

find_path(GSL_INCLUDE_DIR gsl/gsl_math.h
  DOC "GSL include directory (must have gsl/ subdir)"
  PATHS $ENV{GSL_HOME}/include /opt/local/include)
find_library(GSL_LIB gsl
  DOC "GSL library"
  PATHS $ENV{GSL_HOME}/lib /opt/local/lib)
find_library(GSL_CBLAS_LIB gslcblas
  DOC "GSL CBLAS library"
  PATHS $ENV{GSL_HOME}/lib /opt/local/lib)
find_library(M_LIB m
  DOC "standard C math library")
set(GSL_LIBS ${GSL_LIB} ${GSL_CBLAS_LIB} ${M_LIB})
include_directories(${GSL_INCLUDE_DIR})

################################################################################
# SUNDIALS

find_path(SUITE_SPARSE_INCLUDE_DIR klu.h
  DOC "SuiteSparse include directory (must have klu.h)"
  PATHS $ENV{SUITE_SPARSE_HOME}/include $ENV{SUNDIALS_HOME}/include
        /opt/local/include /usr/local/include)
find_library(SUITE_SPARSE_KLU_LIB klu
  DOC "SuiteSparse klu library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_library(SUITE_SPARSE_AMD_LIB amd
  DOC "SuiteSparse amd library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_library(SUITE_SPARSE_BTF_LIB btf
  DOC "SuiteSparse btf library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_library(SUITE_SPARSE_COLAMD_LIB colamd
  DOC "SuiteSparse colamd library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_library(SUITE_SPARSE_CONFIG_LIB suitesparseconfig
  DOC "SuiteSparse config library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_path(SUNDIALS_INCLUDE_DIR cvode/cvode.h
  DOC "SUNDIALS include directory (must have cvode/, sundials/, nvector/ subdirs)"
  PATHS $ENV{SUNDIALS_HOME}/include /opt/local/include /usr/local/include)
find_library(SUNDIALS_NVECSERIAL_LIB sundials_nvecserial
  DOC "SUNDIALS serial vector library"
  PATHS $ENV{SUNDIALS_HOME}/lib /opt/local/lib /usr/local/lib)
find_library(SUNDIALS_CVODE_LIB sundials_cvode
  DOC "SUNDIALS CVODE library"
  PATHS $ENV{SUNDIALS_HOME}/lib /opt/local/lib /usr/local/lib)
find_library(SUNDIALS_KLU_LIB sundials_sunlinsolklu
  DOC "SUNDIALS KLU library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
find_library(SUNDIALS_SUNMATRIX_SPARSE_LIB sundials_sunmatrixsparse
  DOC "SUNDIALS SUNMatrixSparse library"
  PATHS $ENV{SUITE_SPARSE_HOME}/lib $ENV{SUNDIALS_HOME}/lib
        /opt/local/lib /usr/local/lib)
set(SUNDIALS_LIBS ${SUNDIALS_NVECSERIAL_LIB} ${SUNDIALS_CVODE_LIB}
  ${SUNDIALS_KLU_LIB} ${SUNDIALS_SUNMATRIX_SPARSE_LIB} ${SUITE_SPARSE_KLU_LIB}
  ${SUITE_SPARSE_COLAMD_LIB} ${SUITE_SPARSE_AMD_LIB} ${SUITE_SPARSE_BTF_LIB}
  ${SUITE_SPARSE_CONFIG_LIB})
include_directories(${SUNDIALS_INCLUDE_DIR} ${SUITE_SPARSE_INCLUDE_DIR})

################################################################################
# CAMP library

find_path(CAMP_INCLUDE_DIR camp_core.mod
  DOC "CAMP include directory (must include camp_*.mod files)"
  PATHS
    /opt/local/lib
    /usr/local/lib
    /usr/local/lib64)
  find_library(CAMP_LIB camp
    DOC "CAMP library"
  PATHS
    /opt/local/lib
    /usr/local/lib
    /usr/local/lib64)
include_directories(${CAMP_INCLUDE_DIR})
