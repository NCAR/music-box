################################################################################
# MusicBox application

add_executable(music_box component_factory.F90
                         components/camp.F90
                         components/emissions.F90
                         components/loss.F90
                         music_box.F90
                         music_box_core.F90)

target_link_libraries(music_box musica::musicacore ${CAMP_LIB} ${SUNDIALS_LIBS}
  ${GSL_LIBS})

