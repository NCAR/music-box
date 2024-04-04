################################################################################
# MusicBox library

add_library(music_box)
add_library(musica::music_box ALIAS music_box)

target_sources(music_box 
  PRIVATE
    music_box.cpp
)
  
target_link_libraries(music_box PUBLIC musica::micm)

target_include_directories(music_box
  PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

set_target_properties(music_box PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

################################################################################
# MusicBox application

add_executable(music_box_app)

target_sources(music_box_app 
  PRIVATE
    box_model.cpp
)

target_link_libraries(music_box_app PRIVATE musica::music_box)

set_target_properties(music_box_app PROPERTIES
    OUTPUT_NAME music_box
)