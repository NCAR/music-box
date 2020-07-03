################################################################################
# MusicBox application

add_executable(music_box music_box.F90 music_box_core.F90)

target_link_libraries(music_box musicalib)

