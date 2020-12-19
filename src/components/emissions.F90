! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_emissions module

!> The emissions_t type and related functions
module musica_emissions

  use musica_constants,                only : musica_dk, musica_ik
  use musica_component,                only : component_t
  use musica_domain_state_accessor,    only : domain_state_accessor_t
  use musica_domain_state_mutator,     only : domain_state_mutator_t

  implicit none
  private

  public :: emissions_t

  !> Accessors/mutators for emission rate/species pairs
  type :: emission_pairs_t
    !> Emission rate accessor
    class(domain_state_accessor_t), pointer :: get_rate_ => null( )
    !> Get current chemical species concentration
    class(domain_state_accessor_t), pointer :: get_species_ => null( )
    !> Set chemical species concentration
    class(domain_state_mutator_t), pointer :: set_species_ => null( )
  end type emission_pairs_t

  !> Emissions handler for MUSICA
  !!
  !! These objects match emission rates registered by other model components
  !! to chemical species during construction. During the simulation the
  !! type-bound \c emit() function can be called to update a domain state
  !! to include emissions for a provided time step.
  !!
  !! \todo add emissions_t example
  !!
  type, extends(component_t) :: emissions_t
    private
    !> Emission rate/species pairs
    type(emission_pairs_t), allocatable :: pairs_(:)
  contains
    !> Returns the name of the component
    procedure :: name => component_name
    !> Returns a description of the component purpose
    procedure :: description
    !> Update domain state for emissions occurring over a given time step
    procedure :: advance_state
    !> Preprocess emissions configuration data
    procedure :: preprocess_input
    !> Cleans up memory
    final :: finalize
  end type emissions_t

  !> Constructor for the emissions_t type
  interface emissions_t
    module procedure :: constructor
  end interface emissions_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Create an emissions_t object
  !!
  !! The constructor finds registered emission rates and matches them to
  !! chemical species concentrations, setting up accessors and mutators to use
  !! at run-time to update the domain state to include emissions.
  !!
  function constructor( config, domain, output ) result( new_obj )

    use musica_config,                 only : config_t
    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_domain_state_accessor,  only : domain_state_accessor_ptr
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t
    use musica_string,                 only : string_t

    !> New emissions_t object
    type(emissions_t), pointer :: new_obj
    !> Emissions configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Output file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = 'emissions_t constructor'
    class(domain_state_accessor_ptr), pointer :: species(:)
    type(string_t) :: species_name
    class(property_t), pointer :: emit_prop, chem_prop
    integer(kind=musica_ik) :: i_rate
    type(domain_target_cells_t) :: all_cells

    allocate( new_obj )

    species => domain%accessor_set( "chemical_species",                       & !- state variable set name
                                    "mol m-3",                                & !- MUSICA units
                                    kDouble,                                  & !- data type
                                    all_cells,                                & !- accessor target domain
                                    my_name )

    allocate( new_obj%pairs_( size( species ) ) )

    do i_rate = 1, size( species )
      new_obj%pairs_( i_rate )%get_species_ => species( i_rate )%val_
      species( i_rate )%val_ => null( )
      chem_prop => new_obj%pairs_( i_rate )%get_species_%property( )
      species_name = chem_prop%base_name( )
      emit_prop => property_t( chem_prop,                                     &
                               my_name,                                       &
                               name = "emission_rates%"//                     & !- state variable name
                                      species_name%to_char( ),                &
                               units = "mol m-3 s-1",                         & !- MUSICA units
                               data_type = kDouble,                           & !- data type
                               applies_to = all_cells,                        & !- target domain
                               default_value = 0.0_musica_dk )
      call domain%register( emit_prop )
      new_obj%pairs_( i_rate )%get_rate_    => domain%accessor( emit_prop )
      new_obj%pairs_( i_rate )%set_species_ => domain%mutator(  chem_prop )
      deallocate( emit_prop )
      deallocate( chem_prop )
    end do

    deallocate( species )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component name
  type(string_t) function component_name( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(emissions_t), intent(in) :: this

    component_name = "Musica Emissions"

  end function component_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component description
  type(string_t) function description( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(emissions_t), intent(in) :: this

    description = "Time-split emissions handler"

  end function description

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update a domain state for emissions over a given time step
  subroutine advance_state( this, domain_state, domain_element,               &
      current_time__s, time_step__s )

    use musica_assert,                 only : assert
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use musica_property,               only : property_t

    !> Emissions handler
    class(emissions_t), intent(inout) :: this
    !> Model domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Grid cell to emit into
    class(domain_iterator_t), intent(in) :: domain_element
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: current_time__s
    !> Time step to calculate emissions for [s]
    real(kind=musica_dk), intent(in) :: time_step__s

    integer(kind=musica_ik) :: i_rate
    real(kind=musica_dk) :: conc, rate
    class(property_t), pointer :: prop

    call assert( 189684562, allocated( this%pairs_ ) )
    do i_rate = 1, size( this%pairs_ )
      call domain_state%get( domain_element,                                  &
                             this%pairs_( i_rate )%get_rate_, rate )
      call domain_state%get( domain_element,                                  &
                             this%pairs_( i_rate )%get_species_, conc )
      conc = conc + rate * time_step__s
      call domain_state%update( domain_element,                               &
                                this%pairs_( i_rate )%set_species_, conc )
    end do

  end subroutine advance_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Preprocess emissions configuration data
  subroutine preprocess_input( this, config, output_path )

    use musica_config,                 only : config_t

    !> Emissions handler
    class(emissions_t), intent(inout) :: this
    !> Emissions configuration
    type(config_t), intent(out) :: config
    !> Folder to save input data to
    character(len=*), intent(in) :: output_path

    character(len=*), parameter :: my_name = "Emissions handler preprocessor"

    call config%empty( )
    call config%add( "type", "musica-emissions", my_name )

  end subroutine preprocess_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Cleans up memory
  elemental subroutine finalize( this )

    !> Emissions handler
    type(emissions_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_rate

    if( allocated( this%pairs_ ) ) then
      do i_rate = 1, size( this%pairs_ )
        if( associated( this%pairs_( i_rate )%get_rate_ ) )                   &
          deallocate( this%pairs_( i_rate )%get_rate_ )
        if( associated( this%pairs_( i_rate )%get_species_ ) )                &
          deallocate( this%pairs_( i_rate )%get_species_ )
        if( associated( this%pairs_( i_rate )%set_species_ ) )                &
          deallocate( this%pairs_( i_rate )%set_species_ )
      end do
      deallocate( this%pairs_ )
    end if

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_emissions
