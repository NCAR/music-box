######################################################################
# MusicBox library

file(GLOB MUSIC_BOX_SRC *.F90 util/*.F90)

add_library(musicboxlib ${MUSIC_BOX_SRC} ${MUSIC_BOX_UTIL_SRC})

set_target_properties(musicboxlib PROPERTIES OUTPUT_NAME musicbox)
