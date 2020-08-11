################################################################################
# Link musicalib to a test and add it to the suite

macro(add_std_test test_name)
  target_include_directories(${test_name} PUBLIC ${CMAKE_BINARY_DIR}/src)
  target_link_libraries(${test_name} musicalib)
  add_test(NAME ${test_name} COMMAND ${test_name})
endmacro(add_std_test)

################################################################################
# Copy test data

add_custom_target(copy_unit_data ALL ${CMAKE_COMMAND} -E copy_directory
  ${CMAKE_CURRENT_SOURCE_DIR}/data ${CMAKE_BINARY_DIR}/test/data)

add_custom_target(copy_integration_data ALL ${CMAKE_COMMAND} -E copy_directory
  ${CMAKE_CURRENT_SOURCE_DIR}/integration ${CMAKE_BINARY_DIR}/test/integration)

################################################################################
# MusicBox tests

add_executable(util_array util/array.F90)
add_std_test(util_array)

add_executable(util_convert util/convert.F90)
add_std_test(util_convert)

add_executable(util_string util/string.F90)
add_std_test(util_string)

add_executable(config config.F90)
add_std_test(config)

add_executable(domain_cell domains/cell.F90)
add_std_test(domain_cell)

add_test(NAME input_use_case_1 COMMAND integration/input_use_cases/1/run.sh)
add_test(NAME input_use_case_2 COMMAND integration/input_use_cases/2/run.sh)
add_test(NAME input_use_case_3 COMMAND integration/input_use_cases/3/run.sh)

add_executable(integration_input_4_check
               integration/input_use_cases/4/check_output.F90
               test_common/output.F90)
target_include_directories(integration_input_4_check PUBLIC ${CMAKE_BINARY_DIR}/src)
target_link_libraries(integration_input_4_check musicalib)
add_test(NAME input_use_case_4 COMMAND integration/input_use_cases/4/run.sh)
add_test(NAME input_use_case_4b COMMAND integration/input_use_cases/4/run_b.sh)

################################################################################
