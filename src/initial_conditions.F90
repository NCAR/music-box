!> \file
!> The musica_initial_conditions module

!> The set_initial_conditions and related functions
module musica_initial_conditions

  implicit none
  private

  public :: set_initial_conditions

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set the initial conditions in a domain state
  subroutine set_initial_conditions( config, domain, state )

    !> Initial condition configuration data
    type(config_t), intent(in) :: config
    !> Model domain data
    class(domain_t), intent(in) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name = 'intial conditions'
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

    !> Configuration data
    type(config_t), intent(in) :: config
    !> Model domain data
    class(domain_t), intent(in) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name = 'initial species concentrations'
    type(config_t) :: subset
    type(string_t) :: species_name
    real(kind=musica_dk) :: conc
    class(iterator_t), pointer :: species_iter

    species_iter => config%get_iterator( )
    do while( iter%next( ) )
      chemical_species = "chemical_species%"//config%key( species_iter )
      call config%get( species_iter, subset, my_name )
      call subset%get( "initial value", "mol m-3", conc, my_name )
      call subset%finalize( )
      mutator => domain%cell_state_mutator( species_name, "mol m-3", my_name )
      call state%update( mutator, conc )
      deallocate( mutator )
    end do

    ! clean up
    deallocate( species_iter )

  end subroutine set_chemical_species

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set environmental conditions for all domain cells
  subroutine set_environmental_conditions( config, domain, state )

    !> Configuration data
    type(config_t), intent(in) :: config
    !> Model domain data
    class(domain_t), intent(in) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: state

    character(len=*), parameter :: my_name =                                  &
      'initial environmental conditions'
    type(config_t) :: subset
    type(string_t) :: property_name, units
    real(musica_dk) :: property_value
    class(iterator_t), pointer :: property_iter

    property_iter => config%get_iterator( )
    do while( iter%next( ) )
      property_name = config%key( property_iter )
      units         = domain%cell_state_variable_units( property_name )
      call config%get( property_iter, subset, my_name )
      call subset%get( property_name, units, property_value, my_name )
      mutator => domain%cell_state_mutator( property_name, units, my_name )
      call state%update( mutator, property_value )
      deallocate( mutator )
    end do

    ! clean up
    deallocate( property_iter )

  end subroutine set_environmental_conditions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_initial_conditions
