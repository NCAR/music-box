################################################################################
# MusicBox application

add_executable(musicbox MusicBox.F90)

target_include_directories(musicbox PUBLIC ${CMAKE_BINARY_DIR}/src)
target_link_libraries(musicbox musicalib)

