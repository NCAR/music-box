! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> Model domain factory

!> Builder of model domains
module musica_domain_factory

  use musica_domain,                   only : domain_t
  use musica_domain_cell,              only : domain_cell_t

  implicit none
  private

  public :: domain_builder

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Build a domain by name
  !!
  !! At minimum, the \c config argument must include a top-level key-value
  !! pair "type" whose value is a valid domain type name. Currently, these
  !! are:
  !! - "cell" (or "box")
  !!
  !! The \c config argument should also include any additional information
  !! required by the specific domain constructor.
  !!
  !! Example:
  !! \code{f90}
  !!   use musica_config,                   only : config_t
  !!   use musica_domain,                   only : domain_t
  !!   use musica_domain_factory,           only : domain_builder
  !!
  !!   class(domain_t), pointer :: domain
  !!   type(config_t) :: config
  !!
  !!   call config%from_file( 'domain_config.json' )
  !!
  !!   domain => domain_builder( config )
  !!
  !!   ! use the domain
  !!
  !!   deallocate( domain )
  !! \endcode
  !!
  !! `domain_config.json`:
  !! \code{json}
  !!   {
  !!     "type" : "cell"
  !!   }
  !! \endcode
  !!
  function domain_builder( config ) result( new_domain )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_string,                 only : string_t

    !> New domain
    class(domain_t), pointer :: new_domain
    !> Domain configuration data
    class(config_t), intent(inout) :: config

    type(string_t) :: domain_type
    character(len=*), parameter :: my_name = 'domain builder'

    new_domain => null( )
    call config%get( 'type', domain_type, my_name )
    domain_type = domain_type%to_lower( )

    if( domain_type .eq. 'box' .or. domain_type .eq. 'cell' ) then
      new_domain => domain_cell_t( config )
    else
      call die_msg( 404074165, "Invalid domain type: '"//                     &
                                domain_type%to_char( )//"'" )
    end if

  end function domain_builder

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_domain_factory
