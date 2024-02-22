################################################################################
# Utility functions for creating tests

if(MUSIC_BOX_ENABLE_MEMCHECK)
  find_program(MEMORYCHECK_COMMAND "valgrind")
endif()

################################################################################
# build and add a standard test (one linked to the micm library)

function(create_standard_test)
  set(prefix TEST)
  set(optionalValues SKIP_MEMCHECK)
  set(singleValues NAME WORKING_DIRECTORY)
  set(multiValues SOURCES)

  include(CMakeParseArguments)
  cmake_parse_arguments(${prefix} "${optionalValues}" "${singleValues}" "${multiValues}" ${ARGN})

  add_executable(test_${TEST_NAME} ${TEST_SOURCES})

  target_link_libraries(test_${TEST_NAME} PUBLIC musica::music_box GTest::gtest_main)

  if(NOT DEFINED TEST_WORKING_DIRECTORY)
    set(TEST_WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
  endif()

  add_musicbox_test(${TEST_NAME} test_${TEST_NAME} "" ${TEST_WORKING_DIRECTORY} ${TEST_SKIP_MEMCHECK})
endfunction(create_standard_test)

################################################################################
# Add a test

function(add_musicbox_test test_name test_binary test_args working_dir test_skip_memcheck)
  add_test(NAME ${test_name}
            COMMAND ${test_binary} ${test_args}
            WORKING_DIRECTORY ${working_dir})
  set(MEMORYCHECK_COMMAND_OPTIONS "--error-exitcode=1 --trace-children=yes --leak-check=full --gen-suppressions=all ${MEMCHECK_SUPPRESS}")
  set(memcheck "${MEMORYCHECK_COMMAND} ${MEMORYCHECK_COMMAND_OPTIONS}")
  separate_arguments(memcheck)
  if(MEMORYCHECK_COMMAND AND MUSIC_BOX_ENABLE_MEMCHECK AND NOT test_skip_memcheck)
    add_test(NAME memcheck_${test_name}
             COMMAND ${memcheck} ${CMAKE_BINARY_DIR}/${test_binary} ${test_args}
             WORKING_DIRECTORY ${working_dir})
  endif()
endfunction(add_musicbox_test)

################################################################################
