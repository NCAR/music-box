!> \file
!> The musica_initial_conditions module

!> The set_initial_conditions and related functions
module musica_initial_conditions

  use musica_config,                   only : config_t
  use musica_domain,                   only : domain_t, domain_state_t

  implicit none
  private

  public :: set_initial_conditions

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set the initial conditions in a domain state
  subroutine set_initial_conditions( config, domain, state )

    !> Initial condition configuration data
    type(config_t), intent(inout) :: config
    !> Model domain data
    class(domain_t), intent(inout) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name = 'initial conditions'
    logical :: found
    type(config_t) :: subset

    ! set all domain cell chemical species concentrations to specified
    ! values
    call config%get( "chemical species", subset, my_name, found = found )
    if( found ) then
      call set_chemical_species( subset, domain, state )
      call subset%finalize( )
    end if

    ! set all domain cell environmental conditions to specified values
    call config%get( "environmental conditions", subset, my_name,             &
                     found = found )
    if( found ) then
      call set_environmental_conditions( subset, domain, state )
      call subset%finalize( )
    end if

  end subroutine set_initial_conditions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set initial species concentrations for all domain cells
  subroutine set_chemical_species( config, domain, state )

    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_state_mutator_t,         &
                                              domain_iterator_t
    use musica_iterator,               only : iterator_t
    use musica_string,                 only : string_t

    !> Configuration data
    type(config_t), intent(inout) :: config
    !> Model domain data
    class(domain_t), intent(inout) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name = 'initial species concentrations'
    type(config_t) :: subset
    type(string_t) :: species_name
    real(kind=musica_dk) :: conc
    class(iterator_t), pointer :: species_iter
    class(domain_iterator_t), pointer :: cell_iter
    class(domain_state_mutator_t), pointer :: mutator

    species_iter => config%get_iterator( )
    cell_iter    => domain%cell_iterator( )
    do while( species_iter%next( ) )
      species_name = "chemical_species%"//config%key( species_iter )
      call config%get( species_iter, subset, my_name )
      call subset%get( "initial value", "mol m-3", conc, my_name )
      call subset%finalize( )
      mutator => domain%cell_state_mutator( species_name%to_char( ),          &
                                            "mol m-3", my_name )
      call cell_iter%reset( )
      do while( cell_iter%next( ) )
        call state%update( cell_iter, mutator, conc )
      end do
      deallocate( mutator )
    end do

    ! clean up
    deallocate( species_iter )
    deallocate( cell_iter    )

  end subroutine set_chemical_species

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set environmental conditions for all domain cells
  subroutine set_environmental_conditions( config, domain, state )

    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_state_mutator_t,        &
                                              domain_iterator_t
    use musica_iterator,               only : iterator_t
    use musica_string,                 only : string_t

    !> Configuration data
    type(config_t), intent(inout) :: config
    !> Model domain data
    class(domain_t), intent(inout) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name =                                  &
      'initial environmental conditions'
    type(config_t) :: subset
    type(string_t) :: property_name, units
    real(musica_dk) :: property_value
    class(iterator_t), pointer :: property_iter
    class(domain_iterator_t), pointer :: cell_iter
    class(domain_state_mutator_t), pointer :: mutator

    property_iter => config%get_iterator( )
    cell_iter     => domain%cell_iterator( )
    do while( property_iter%next( ) )
      property_name = config%key( property_iter )
      units         = domain%cell_state_units( property_name%to_char( ) )
      call config%get( property_iter, subset, my_name )
      call subset%get( "initial value",  units%to_char( ), property_value,    &
                      my_name )
      call subset%finalize( )
      mutator => domain%cell_state_mutator( property_name%to_char( ),         &
                                            units%to_char( ), my_name )
      call cell_iter%reset( )
      do while( cell_iter%next( ) )
        call state%update( cell_iter, mutator, property_value )
      end do
      deallocate( mutator )
    end do

    ! clean up
    deallocate( property_iter )
    deallocate( cell_iter     )

  end subroutine set_environmental_conditions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_initial_conditions
