! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> Input/output factory

!> Builder of input/output object
module musica_io_factory

  use musica_domain,                   only : domain_t
  use musica_io,                       only : io_t
  use musica_io_text,                  only : io_text_t
  use musica_io_netcdf,                only : io_netcdf_t

  implicit none
  private

  public :: io_builder

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Builds an input/output object by name
  !!
  !! At minimum, the \c config argument must include a top-level key-value
  !! pair "type" whose value is a valid input/output type name. Currently,
  !! these are:
  !! - "csv", "txt", or "text" (a delimited text file)
  !!
  !! The \c config argument should also include any additional information
  !! required by the specific io constructor.
  !!
  !! Input files also require that the initialized domain be passed to the
  !! constructor for mapping between file and domain variables.
  !!
  !! Example:
  !! \code{f90}
  !!   use musica_config,                   only : config_t
  !!   use musica_io,                       only : io_t
  !!   use musica_io_factory,               only : io_builder
  !!
  !!   class(io_t), pointer :: io
  !!
  !!   call config%from_file( 'io_config.json' )
  !!
  !!   io => io_builder( config )
  !!
  !!   ! use the input/output
  !!
  !!   deallocate( io )
  !! \endcode
  !!
  !! `io_config.json`:
  !! \code{json}
  !!   {
  !!     "type" : "csv",
  !!     "intent" : "output"
  !!   }
  !! \endcode
  !!
  function io_builder( config, domain ) result( new_io )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_string,                 only : string_t

    !> New input/output objects
    class(io_t), pointer :: new_io
    !> Input/output object configration data
    class(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout), optional :: domain

    type(string_t) :: io_type
    character(len=*), parameter :: my_name = 'input/output builder'

    new_io => null( )
    call config%get( 'type', io_type, my_name )
    io_type = io_type%to_lower( )

    if( io_type .eq. 'txt' .or.                                               &
        io_type .eq. 'text' .or.                                              &
        io_type .eq. 'csv' ) then
      new_io => io_text_t( config, domain )
    else if( io_type .eq. 'nc' .or.                                           &
             io_type .eq. 'netcdf' ) then
      new_io => io_netcdf_t( config, domain )
    else
      call die_msg( 690482624, "Invalid input/output type: '"//               &
                               io_type%to_char( )//"'" )
    end if

  end function io_builder

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io_factory
