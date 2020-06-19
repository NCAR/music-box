######################################################################
# MUSICA library

file(GLOB MUSICA_SRC *.F90 util/*.F90)

add_library(musicalib ${MUSICA_SRC})

target_link_libraries(musicalib ${JSON_LIB} ${NETCDF_LIB})

set_target_properties(musicalib PROPERTIES OUTPUT_NAME musica)

######################################################################
