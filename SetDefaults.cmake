# Overwrite the init values choosen by CMake
if (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
  set(CMAKE_Fortran_FLAGS_DEBUG_INIT "-g")
endif()
