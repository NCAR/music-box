! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The music_box_camp module

!> The camp_t type and related functions
module music_box_partmc

  use musica_component,                only : component_t
  use musica_config,                   only : config_t
  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain_state_accessor,    only : domain_state_accessor_t,        &
                                              domain_state_accessor_ptr
  use musica_domain_state_mutator,     only : domain_state_mutator_t,         &
                                              domain_state_mutator_ptr
!  use camp_camp_core,                  only : camp_core_t
!  use camp_camp_state,                 only : camp_state_t
!  use camp_rxn_data,                   only : rxn_update_data_t

  use pmc_aero_state
  use pmc_gas_state
  use pmc_gas_data
  use pmc_aero_data
  use pmc_env_state

  implicit none
  private

  public :: partmc_t

!  !> MUSICA accessor / CAMP updater pair for reaction parameters
!  type :: reaction_updater_t
!    !> MUSICA accessor for variable
!    class(domain_state_accessor_t), pointer :: accessor_ => null( )
!    !> CAMP updater
!    class(rxn_update_data_t), pointer :: updater_ => null( )
!  contains
!    !> Finalizes a reaction_updater_t object
!    final :: reaction_updater_finalize
!  end type reaction_updater_t

  !> Overridden species mixing ratios
  !!
  !! These species mixing ratios will be used to set the initial CAMP state,
  !! overriding the MUSICA state values. The final CAMP state will still be
  !! used to update the MUSICA state after solving chemistry.
  !!
!  type :: override_t
!    !> Index for the species in the CAMP state array
!    integer(kind=musica_ik) :: camp_id_ = -99999
!    !> Species mixing ratio [mol mol-1]
!    real(kind=musica_dk) :: mixing_ratio__mol_mol_ = 0.0
!  end type override_t

  !> Interface to Chemistry Across Multiple Phases (CAMP)
  !!
  !! CAMP can be used to solve mixed-phase chemical systems, including gas-
  !! and condensed-phase chemistry, condensation, and evaporation.
  !!
  type, extends(component_t) :: partmc_t
    private
    !> CAMP configuration
    type(config_t) :: config_
    !> Mutators for chemical species concentrations [mol m-3]
    class(domain_state_mutator_ptr), pointer ::                               &
        set_species_state__mol_m3_(:) => null( )
    !> Accessors for chemical species concentrations [mol m-3]
    class(domain_state_accessor_ptr), pointer ::                              &
        get_species_state__mol_m3_(:) => null( )
    type(aero_state_t) :: aero_state
    type(aero_data_t) :: aero_data
    type(gas_state_t) :: gas_state
    type(gas_data_t) :: gas_data

    !> Photolysis reaction updaters
!    type(reaction_updater_t), allocatable :: photolysis_(:)
    !> Emissions reaction updaters
!    type(reaction_updater_t), allocatable :: emissions_(:)
    !> Deposition reaction updaters
!    type(reaction_updater_t), allocatable :: deposition_(:)
    !> Temperature [K] accessor
    class(domain_state_accessor_t), pointer :: temperature__K_ => null( )
    !> Pressure [Pa] accessor
    class(domain_state_accessor_t), pointer :: pressure__Pa_ => null( )
    !> Number density of air [mol m-3]
    class(domain_state_accessor_t), pointer ::                                &
        number_density_air__mol_m3_ => null( )
    !> Flag indicating whether to output photolysis rate constants
    logical :: output_photolysis_rate_constants_ = .false.
  contains
    !> Returns the name of the component
    procedure :: name => component_name
    !> Returns a description of the component purpose
    procedure :: description
    !> Advance the model state for a given timestep
    procedure :: advance_state
    !> Save the component configuration for future simultaions
    procedure :: preprocess_input
    !> Connect MUSICA chemical species concentrations to the CAMP mechanism
    procedure, private :: connect_species_state
    !> Connect MUSICA environmental parameters to the CAMP mechanism
    procedure, private :: connect_environment
    !> Connect external photolysis rate constants to the CAMP mechanism
    procedure, private :: connect_photolysis
    !> Connect external emissions rates to the CAMP mechanism
    procedure, private :: connect_emissions
    !> Connect external deposition rate constants to the CAMP mechanism
!    procedure, private :: connect_deposition
    !> Update CAMP with MUSICA species concentrations
    procedure, private :: update_camp_species_state
    !> Update CAMP with MUSICA environmental parameters
    procedure, private :: update_camp_environment
    !> Update CAMP with externally provided photolysis rate constants
    procedure, private :: update_camp_photolysis
    !> Update CAMP with externally provided emission rates
    procedure, private :: update_camp_emissions
    !> Update CAMP with externally provided deposition rate constants
    procedure, private :: update_camp_deposition
    !> Update MUSICA with CAMP species concentrations
    procedure, private :: update_musica_species_state
    !> Finalizes a camp_t object
    final :: finalize
  end type partmc_t

  !> Constructor of camp_t objects
  interface partmc_t
    module procedure :: constructor
  end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> PartMC interface constructor
  function constructor( config, domain, output ) result( new_obj )

    use musica_domain,                 only : domain_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_string,                 only : string_t

    !> New CAMP interface
    type(partmc_t), pointer :: new_obj
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "PartMC interface constructor"
    type(string_t) :: config_file_name

    allocate( new_obj )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component name
  type(string_t) function component_name( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(partmc_t), intent(in) :: this

    component_name = "PartMC: Particle-resolved Monte Carlo code for 
         atmospheric aerosol simulation"

  end function component_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component description
  type(string_t) function description( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(partmc_t), intent(in) :: this

    description = "Particle-resolved aerosol representation"

  end function description

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the model state for multi-phase chemistry
  subroutine advance_state( this, domain_state, domain_element,               &
      current_time__s, time_step__s )

    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_state,           only : domain_state_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: current_time__s
    !> Time step to advance state by [s]
    real(kind=musica_dk), intent(in) :: time_step__s

!    ! update CAMP with externally provided parameters
!    call this%update_camp_species_state( domain_state, domain_element )
!    call this%update_camp_environment(   domain_state, domain_element )
!    call this%update_camp_photolysis(    domain_state, domain_element )
!    call this%update_camp_emissions(     domain_state, domain_element )
!    call this%update_camp_deposition(    domain_state, domain_element )
!
!    ! solve multi-phase chemistry
!    call this%core_%solve( this%state_, time_step__s )
!
!    ! update MUSICA with CAMP results
!    call this%update_musica_species_state( domain_state, domain_element )

  end subroutine advance_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Save the CAMP configuration for future simulations
  subroutine preprocess_input( this, config, output_path )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Model component configuration
    type(config_t), intent(out) :: config
    !> Folder to save input data to
    character(len=*), intent(in) :: output_path

    character(len=*), parameter :: my_name = "CAMP preprocessor"
    type(config_t) :: camp_orig_config, temp_config
    type(string_t) :: config_file_name
    type(string_t), allocatable :: camp_files(:), split_file(:)
    logical :: found
    integer(kind=musica_ik) :: i_file

  end subroutine preprocess_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect MUSICA chemical species concentrations to the CAMP mechanism
  subroutine connect_species_state( this, config, domain, output )

    use musica_assert,                 only : assert, assert_msg
    use musica_constants,              only : musica_lk
    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_iterator,               only : iterator_t
    use musica_property,               only : property_t
    use musica_property_set,           only : property_set_t
    use musica_string,                 only : string_t
    use camp_util,                     only : camp_string_t => string_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP chemical species connector"
    integer(kind=musica_ik) :: i_spec
    logical(kind=musica_lk) :: found, found_spec
    type(string_t) :: spec_name
    type(config_t) :: spec_set, spec_data
    class(iterator_t), pointer :: iter
    type(domain_target_cells_t) :: all_cells
    type(property_t), pointer :: prop
    type(property_set_t) :: prop_set

  end subroutine connect_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect MUSICA environmental parameters to the CAMP mechanism
  subroutine connect_environment( this, config, domain, output )

    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP environment connector"
    type(domain_target_cells_t) :: all_cells
    type(property_t), pointer :: prop

!    prop => property_t( my_name, name = "temperature", units = "K",           &
!                        applies_to = all_cells, data_type = kDouble )
!    this%temperature__K_ => domain%accessor( prop )
!    deallocate( prop )
!    prop => property_t( my_name, name = "pressure", units = "Pa",             &
!                        applies_to = all_cells, data_type = kDouble )
!    this%pressure__Pa_ => domain%accessor( prop )
!    deallocate( prop )
!    prop => property_t( my_name, name = "number density air",                 &
!                        units = "mol m-3", applies_to = all_cells,            &
!                        data_type = kDouble )
!    this%number_density_air__mol_m3_ => domain%accessor( prop )
!    deallocate( prop )

  end subroutine connect_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect external photolysis rate constants to the CAMP mechanism
  subroutine connect_photolysis( this, config, domain, output )

    use musica_assert,                 only : assert
    use musica_constants,              only : musica_lk
    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t
    use musica_string,                 only : string_t
    use camp_rxn_data,                 only : rxn_data_t
    use camp_rxn_photolysis,           only : rxn_photolysis_t,               &
                                              rxn_update_data_photolysis_t
    use camp_util,                     only : camp_string_t => string_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP photolysis connector"
    integer(kind=musica_ik) :: i_rxn, i_mech, n_rxn, i_updater
    logical(kind=musica_lk) :: found
    class(rxn_data_t), pointer :: rxn
    type(property_t), pointer :: prop
    type(domain_target_cells_t) :: all_cells
    character(len=:), allocatable :: key, temp_str

  end subroutine connect_photolysis

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect external emissions rates to the CAMP mechanism
  subroutine connect_emissions( this, config, domain, output )

    use musica_assert,                 only : assert
    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t
    use musica_string,                 only : string_t
    use camp_rxn_data,                 only : rxn_data_t
    use camp_rxn_emission,             only : rxn_emission_t,                 &
                                              rxn_update_data_emission_t
    use camp_util,                     only : camp_string_t => string_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP emissions connector"
    integer(kind=musica_ik) :: i_rxn, i_mech, n_rxn, i_updater
    class(rxn_data_t), pointer :: rxn
    type(property_t), pointer :: prop
    type(domain_target_cells_t) :: all_cells
    character(len=:), allocatable :: key, temp_str

  end subroutine connect_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with MUSICA species concentrations
  subroutine update_camp_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec
    real(kind=musica_dk) :: number_density, new_value

  end subroutine update_camp_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with MUSICA environmental parameters
  subroutine update_camp_environment( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    real(kind=musica_dk) :: new_value

  end subroutine update_camp_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided photolysis rate constants
  subroutine update_camp_photolysis( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_photolysis,           only : rxn_update_data_photolysis_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value

!    do i_pair = 1, size( this%photolysis_ )
!    associate( pair => this%photolysis_( i_pair ) )
!      select type( updater => pair%updater_ )
!      class is( rxn_update_data_photolysis_t )
!        call domain_state%get( domain_element, pair%accessor_, update_value )
!        call updater%set_rate( update_value )
!        call this%core_%update_data( updater )
!      class default
!        call die( 232110673 )
!      end select
!    end associate
!    end do

  end subroutine update_camp_photolysis

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided emissions rate constants
  subroutine update_camp_emissions( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_emission,             only : rxn_update_data_emission_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value, number_density

!    call domain_state%get( domain_element, this%number_density_air__mol_m3_,  &
!                           number_density )
!    do i_pair = 1, size( this%emissions_ )
!    associate( pair => this%emissions_( i_pair ) )
!      select type( updater => pair%updater_ )
!      class is( rxn_update_data_emission_t )
!        call domain_state%get( domain_element, pair%accessor_, update_value )
!        call updater%set_rate( update_value / number_density * 1.0e6 )
!        call this%core_%update_data( updater )
!      class default
!        call die( 190238180 )
!      end select
!    end associate
!    end do

  end subroutine update_camp_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided deposition rate constants
  subroutine update_camp_deposition( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_first_order_loss,     only : rxn_update_data_first_order_loss_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value

!    do i_pair = 1, size( this%deposition_ )
!    associate( pair => this%deposition_( i_pair ) )
!      select type( updater => pair%updater_ )
!      class is( rxn_update_data_first_order_loss_t )
!        call domain_state%get( domain_element, pair%accessor_, update_value )
!        call updater%set_rate( update_value )
!        call this%core_%update_data( updater )
!      class default
!        call die( 916722502 )
!      end select
!    end associate
!    end do

  end subroutine update_camp_deposition

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update MUSICA with CAMP species concentrations
  subroutine update_musica_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec
    real(kind=musica_dk) :: number_density, new_value

    call domain_state%get( domain_element, this%number_density_air__mol_m3_,  &
                           number_density )
!    do i_spec = 1, size( this%set_species_state__mol_m3_ )
!    associate( mutator => this%set_species_state__mol_m3_( i_spec )%val_ )
!      new_value = this%state_%state_var( i_spec ) * 1.0d-6 * number_density
!      call domain_state%update( domain_element, mutator, new_value )
!    end associate
!    end do

  end subroutine update_musica_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes a camp_t object
  elemental subroutine finalize( this )

    !> CAMP interface
    type(partmc_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_elem

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_partmc
