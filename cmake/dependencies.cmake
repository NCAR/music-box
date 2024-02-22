include(FetchContent)

################################
# micm

FetchContent_Declare(micm
  GIT_REPOSITORY https://github.com/NCAR/micm.git
  GIT_TAG 7afa87f
)
FetchContent_MakeAvailable(micm)

################################
# google test

if(PROJECT_IS_TOP_LEVEL)
  FetchContent_Declare(googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
  )

  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)

  FetchContent_MakeAvailable(googletest)
endif()