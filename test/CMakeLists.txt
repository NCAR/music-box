################################################################################
# Test options

################################################################################
# Copy test data

add_custom_target(copy_integration_data ALL ${CMAKE_COMMAND} -E copy_directory
  ${CMAKE_CURRENT_SOURCE_DIR}/integration ${CMAKE_BINARY_DIR}/test/integration)

################################################################################
# Test tools

add_executable(compare_results test_common/compare_results.c)

################################################################################
# MusicBox tests

add_executable(integration_input_4_check
               integration/input_use_cases/4/check_output.F90
               test_common/output.F90)
target_include_directories(integration_input_4_check PUBLIC ${CMAKE_BINARY_DIR}/src)
target_link_libraries(integration_input_4_check musica::musicacore)
add_test(NAME input_use_case_1_camp COMMAND integration/input_use_cases/1/run_camp.sh)
add_test(NAME input_use_case_1_preprocessor_camp COMMAND integration/input_use_cases/1/run_preprocessor_camp.sh)
add_test(NAME input_use_case_2_camp COMMAND integration/input_use_cases/2/run_camp.sh)
add_test(NAME input_use_case_2_preprocessor_camp COMMAND integration/input_use_cases/2/run_preprocessor_camp.sh)
add_test(NAME input_use_case_3_camp COMMAND integration/input_use_cases/3/run_camp.sh)
add_test(NAME input_use_case_3_preprocessor_camp COMMAND integration/input_use_cases/3/run_preprocessor_camp.sh)
add_test(NAME input_use_case_4_camp COMMAND integration/input_use_cases/4/run_camp.sh)
add_test(NAME input_use_case_4_preprocessor_camp COMMAND integration/input_use_cases/4/run_preprocessor_camp.sh)
add_test(NAME input_use_case_4b_camp COMMAND integration/input_use_cases/4/run_b_camp.sh)
add_test(NAME input_use_case_4b_preprocessor_camp COMMAND integration/input_use_cases/4/run_b_preprocessor_camp.sh)
add_test(NAME input_use_case_5_camp COMMAND integration/input_use_cases/5/run_camp.sh)
add_test(NAME input_use_case_5_preprocessor_camp COMMAND integration/input_use_cases/5/run_preprocessor_camp.sh)
add_test(NAME input_use_case_6_camp COMMAND integration/input_use_cases/6/run_camp.sh)
add_test(NAME input_use_case_6_preprocessor_camp COMMAND integration/input_use_cases/6/run_preprocessor_camp.sh)
add_test(NAME input_use_case_7_camp COMMAND integration/input_use_cases/7/run_camp.sh)
add_test(NAME input_use_case_7_preprocessor_camp COMMAND integration/input_use_cases/7/run_preprocessor_camp.sh)
add_test(NAME input_use_case_8_camp COMMAND integration/input_use_cases/8/run_camp.sh)
add_test(NAME input_use_case_8_preprocessor_camp COMMAND integration/input_use_cases/8/run_preprocessor_camp.sh)
add_test(NAME input_use_case_8b_camp COMMAND integration/input_use_cases/8/run_b_camp.sh)
add_test(NAME input_use_case_8b_preprocessor_camp COMMAND integration/input_use_cases/8/run_b_preprocessor_camp.sh)
add_test(NAME input_use_case_9_camp COMMAND integration/input_use_cases/9/run_camp.sh)
add_test(NAME input_use_case_9_preprocessor_camp COMMAND integration/input_use_cases/9/run_preprocessor_camp.sh)

################################################################################
