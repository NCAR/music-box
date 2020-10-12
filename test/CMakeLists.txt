################################################################################
# Copy test data

add_custom_target(copy_integration_data ALL ${CMAKE_COMMAND} -E copy_directory
  ${CMAKE_CURRENT_SOURCE_DIR}/integration ${CMAKE_BINARY_DIR}/test/integration)

################################################################################
# MusicBox tests

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

add_test(NAME input_use_case_5 COMMAND integration/input_use_cases/5/run.sh)
add_test(NAME input_use_case_6 COMMAND integration/input_use_cases/6/run.sh)
add_test(NAME input_use_case_7 COMMAND integration/input_use_cases/7/run.sh)
add_test(NAME input_use_case_8 COMMAND integration/input_use_cases/8/run.sh)

################################################################################
