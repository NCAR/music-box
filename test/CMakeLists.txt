################################################################################
# MusicBox tests

add_executable(util_string util/string.F90)
target_include_directories(util_string PUBLIC ${CMAKE_BINARY_DIR}/src)
target_link_libraries(util_string musicboxlib)
add_test(NAME util_string COMMAND util_string)

add_executable(util_convert util/convert.F90)
target_include_directories(util_convert PUBLIC ${CMAKE_BINARY_DIR}/src)
target_link_libraries(util_convert musicboxlib)
add_test(NAME util_convert COMMAND util_convert)

