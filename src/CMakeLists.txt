######################################################################
# MUSICA library

set(MUSICA_SRC config.F90
               domain.F90
               domain_factory.F90
               domains/cell.F90
               emissions.F90
               evolving_conditions.F90
               initial_conditions.F90
               io.F90
               io_factory.F90
               ios/netcdf.F90
               ios/netcdf_dimension.F90
               ios/netcdf_file.F90
               ios/netcdf_updater.F90
               ios/netcdf_variable.F90
               ios/text.F90
               loss.F90
               util/array.F90
               util/assert.F90
               util/constants.F90
               util/convert.F90
               util/datetime.F90
               util/iterator.F90
               util/logger.F90
               util/string.F90)

add_library(musicalib ${MUSICA_SRC})

target_link_libraries(musicalib ${JSON_LIB} ${NETCDF_LIBS})

set_target_properties(musicalib PROPERTIES OUTPUT_NAME musica)

######################################################################
