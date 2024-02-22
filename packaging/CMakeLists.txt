include(GNUInstallDirs)

set_target_properties(music_box PROPERTIES
    INSTALL_RPATH "${SUNDIALS_LIBS}"
)

install(
  TARGETS 
    music_box
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)