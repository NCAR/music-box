! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The music_box_camp module

!> The camp_t type and related functions
module music_box_camp

  use musica_component,                only : component_t
  use musica_config,                   only : config_t
  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain_state_accessor,    only : domain_state_accessor_t,        &
                                              domain_state_accessor_ptr
  use musica_domain_state_mutator,     only : domain_state_mutator_t,         &
                                              domain_state_mutator_ptr
  use camp_camp_core,                  only : camp_core_t
  use camp_camp_state,                 only : camp_state_t
  use camp_rxn_data,                   only : rxn_update_data_t

  implicit none
  private

  public :: camp_t

  !> MUSICA accessor / CAMP updater pair for reaction parameters
  type :: reaction_updater_t
    !> MUSICA accessor for variable
    class(domain_state_accessor_t), pointer :: accessor_ => null( )
    !> CAMP updater
    class(rxn_update_data_t), pointer :: updater_ => null( )
  contains
    !> Finalizes a reaction_updater_t object
    final :: reaction_updater_finalize
  end type reaction_updater_t

  !> Overridden species mixing ratios
  !!
  !! These species mixing ratios will be used to set the initial CAMP state,
  !! overriding the MUSICA state values. The final CAMP state will still be
  !! used to update the MUSICA state after solving chemistry.
  !!
  type :: override_t
    !> Index for the species in the CAMP state array
    integer(kind=musica_ik) :: camp_id_ = -99999
    !> Species mixing ratio [mol mol-1]
    real(kind=musica_dk) :: mixing_ratio__mol_mol_ = 0.0
  end type override_t

  !> Interface to Chemistry Across Multiple Phases (CAMP)
  !!
  !! CAMP can be used to solve mixed-phase chemical systems, including gas-
  !! and condensed-phase chemistry, condensation, and evaporation.
  !!
  type, extends(component_t) :: camp_t
    private
    !> CAMP configuration
    type(config_t) :: config_
    !> CAMP core
    type(camp_core_t), pointer :: core_ => null( )
    !> CAMP state
    type(camp_state_t), pointer :: state_ => null( )
    !> Mutators for chemical species concentrations [mol m-3]
    class(domain_state_mutator_ptr), pointer ::                               &
        set_species_state__mol_m3_(:) => null( )
    !> Accessors for chemical species concentrations [mol m-3]
    class(domain_state_accessor_ptr), pointer ::                              &
        get_species_state__mol_m3_(:) => null( )
    !> Overridden species
    type(override_t), allocatable :: overrides_(:)
    !> Photolysis reaction updaters
    type(reaction_updater_t), allocatable :: photolysis_(:)
    !> Emissions reaction updaters
    type(reaction_updater_t), allocatable :: emissions_(:)
    !> Deposition reaction updaters
    type(reaction_updater_t), allocatable :: deposition_(:)
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
    procedure, private :: connect_deposition
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
  end type camp_t

  !> Constructor of camp_t objects
  interface camp_t
    module procedure :: constructor
  end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> CAMP interface constructor
  function constructor( config, domain, output ) result( new_obj )

    use musica_domain,                   only : domain_t
    use musica_assert,                   only : assert_msg, die_msg
    use musica_input_output_processor,   only : input_output_processor_t
    use musica_string,                   only : string_t
    use musica_iterator,                 only : iterator_t
    use camp_aero_rep_data,              only : aero_rep_data_t
    use camp_aero_rep_modal_binned_mass, only : aero_rep_modal_binned_mass_t,                                                &
                                                aero_rep_update_data_modal_binned_mass_GMD_t,                                &
                                                aero_rep_update_data_modal_binned_mass_GSD_t

    !> New CAMP interface
    type(camp_t), pointer :: new_obj
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP interface constructor"
    type(string_t) :: config_file_name, object_type, filename, rep_name
    type(config_t) :: mechanism_config, child_config, obj_config, mode_config, single_phase_config
    class(iterator_t), pointer  :: iter
    logical                     :: found, file_exists
    real(musica_dk) :: gmd, gsd
    class(aero_rep_data_t), pointer :: aero_rep
    type(aero_rep_update_data_modal_binned_mass_GMD_t) :: update_data_GMD
    type(aero_rep_update_data_modal_binned_mass_GSD_t) :: update_data_GSD
    integer :: i_sect_single

    allocate( new_obj )

    ! save the configuration (used for preprocessing input data only)
    new_obj%config_ = config

    ! get the path to the CAMP configuration file
    call config%get( "configuration file", config_file_name, my_name )

    ! construct the CAMP core
    new_obj%core_ => camp_core_t( config_file_name%to_char( ) )
    call new_obj%core_%initialize( )

    ! connect CAMP rates to external model components
    call new_obj%connect_species_state( config, domain, output )
    call new_obj%connect_environment(   config, domain, output )
    call new_obj%connect_photolysis(    config, domain, output )
    call new_obj%connect_emissions(     config, domain, output )
    call new_obj%connect_deposition(    config, domain, output )

    ! check if the configuration file has a mean diameter and standard deviation. Create an updater if so
    filename = "camp_data/mechanism.json"
    inquire( file=filename%to_char(), exist=file_exists )
    if(file_exists) then
      call mechanism_config%from_file( filename%to_char() )
      call mechanism_config%get( "camp-data", child_config, my_name )
      iter => child_config%get_iterator()
      do while( iter%next() )
        call child_config%get( iter, obj_config, my_name )
        call obj_config%get( "type", object_type, my_name, found = found)

        if(found .and. (object_type == "AERO_REP_MODAL_BINNED_MASS")) then
          call obj_config%get( "modes/bins", mode_config, my_name )
          call mode_config%get( "single phase mode", single_phase_config, my_name, found = found )
          if(found) then
            call obj_config%get( "name", rep_name, my_name)
            call assert_msg(940125461, new_obj%core_%get_aero_rep(rep_name%to_char(), aero_rep), rep_name)
            call assert_msg(636914093, associated(aero_rep), rep_name)
            call new_obj%core_%initialize_update_object(aero_rep, update_data_GMD)
            call new_obj%core_%initialize_update_object(aero_rep, update_data_GSD)

            ! Update the GMD and GSD for the two modes
            select type (aero_rep)
              type is (aero_rep_modal_binned_mass_t)
                call assert_msg(937636446, &
                            aero_rep%get_section_id("single phase mode", &
                                                    i_sect_single), &
                            "Could not get section id for the single phase mode")
              class default
                call die_msg(570113680, rep_name)
            end select


            call single_phase_config%get( "geometric mean diameter", gmd, my_name )
            call single_phase_config%get( "geometric standard deviation", gsd, my_name )

            call update_data_GMD%set_GMD(i_sect_single, gmd)
            call update_data_GSD%set_GSD(i_sect_single, gsd)

            call new_obj%core_%update_data(update_data_GMD)
            call new_obj%core_%update_data(update_data_GSD)
          end if
          exit
        end if
      end do
    end if

    ! at this point the core and update objects could be packed onto a
    ! character buffer and used to recreate these objects for use on multiple
    ! threads or processors

    call new_obj%core_%solver_initialize( )
    new_obj%state_ => new_obj%core_%new_state( )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component name
  type(string_t) function component_name( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(camp_t), intent(in) :: this

    component_name = "CAMP: Chemistry Across Multiple Phases"

  end function component_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component description
  type(string_t) function description( this )

    use musica_string,                 only : string_t

    !> CAMP interface
    class(camp_t), intent(in) :: this

    description = "Combined solving of gas- and condensed-phase chemistry"

  end function description

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the model state for multi-phase chemistry
  subroutine advance_state( this, domain_state, domain_element,               &
      current_time__s, time_step__s )

    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_state,           only : domain_state_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: current_time__s
    !> Time step to advance state by [s]
    real(kind=musica_dk), intent(in) :: time_step__s

    ! update CAMP with externally provided parameters
    call this%update_camp_species_state( domain_state, domain_element )
    call this%update_camp_environment(   domain_state, domain_element )
    call this%update_camp_photolysis(    domain_state, domain_element )
    call this%update_camp_emissions(     domain_state, domain_element )
    call this%update_camp_deposition(    domain_state, domain_element )

    ! solve multi-phase chemistry
    call this%core_%solve( this%state_, time_step__s )

    ! update MUSICA with CAMP results
    call this%update_musica_species_state( domain_state, domain_element )

  end subroutine advance_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Save the CAMP configuration for future simulations
  subroutine preprocess_input( this, config, output_path )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
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

    ! set MUSICA configuration for CAMP
    call config%empty( )
    call config%add( "type", "CAMP", my_name )
    call config%add( "configuration file", "camp_config.json", my_name )
    call this%config_%get( "override species", temp_config, my_name,          &
                           found = found )
    if( found ) then
      call config%add( "override species", temp_config, my_name )
    end if
    call this%config_%get( "suppress output", temp_config, my_name,          &
                           found = found )
    if( found ) then
      call config%add( "suppress output", temp_config, my_name )
    end if

    ! get the path to the original CAMP configuration file
    call this%config_%get( "configuration file", config_file_name, my_name )
    call camp_orig_config%from_file( config_file_name%to_char( ) )

    ! copy each CAMP configuration file to the output path
    call camp_orig_config%get( "camp-files", camp_files, my_name )
    do i_file = 1, size( camp_files )
      call temp_config%from_file( camp_files( i_file )%to_char( ) )
      split_file = camp_files( i_file )%split( "/" )
      camp_files( i_file ) = "camp_data_"//split_file( size( split_file ) )
      call temp_config%to_file( output_path//camp_files( i_file )%to_char( ) )
    end do

    ! save the main CAMP configuration file with updated file names
    call temp_config%empty( )
    call temp_config%add( "camp-files", camp_files, my_name )
    call temp_config%to_file( output_path//"camp_config.json" )

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
    class(camp_t), intent(inout) :: this
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
    type(camp_string_t), allocatable :: species_names(:)

    species_names = this%core_%unique_names( )
    prop_set = property_set_t( )
    do i_spec = 1, size( species_names )
      prop => property_t( my_name,                                            &
                          name = species_names( i_spec )%string,              &
                          units = "mol m-3",                                  &
                          applies_to = all_cells,                             &
                          data_type = kDouble,                                &
                          default_value = 0.0_musica_dk )
      call prop_set%add( prop )
      deallocate( prop )
    end do
    call domain%register( "chemical_species", prop_set )
    this%set_species_state__mol_m3_ =>                                &
        domain%mutator_set(  "chemical_species",                              & !- property set name
                             "mol m-3",                                       & !- units
                             kDouble,                                         & !- data type
                             all_cells,                                       & !- variable domain
                             my_name )
    this%get_species_state__mol_m3_ =>                                &
        domain%accessor_set( "chemical_species",                              & !- property set name
                             "mol m-3",                                       & !- units
                             kDouble,                                         & !- data type
                             all_cells,                                       & !- variable domain
                             my_name )
    call assert( 207263567, size( this%set_species_state__mol_m3_ )   &
                            .eq. size( species_names ) )
    call assert( 533689988, size( this%get_species_state__mol_m3_ )   &
                            .eq. size( species_names ) )

    ! regsiter the species concentration for output
    call config%get( "suppress output", spec_set, my_name, found = found )
    do i_spec = 1, size( species_names )
      if( found ) then
        call spec_set%get( species_names( i_spec )%string, spec_data, my_name,&
                           found = found_spec )
        if( found_spec ) cycle
      end if
      call output%register_output_variable(                                   &
          domain,                                                             &
          "chemical_species%"//species_names( i_spec )%string,                &
          "mol m-3",                                                          & !- units
          "CONC."//species_names( i_spec )%string )                             !- output name
    end do

    ! look for specified overriding species mixing ratios
    call config%get( "override species", spec_set, my_name, found = found )
    if( found ) then
      allocate( this%overrides_( spec_set%number_of_children( ) ) )
      iter => spec_set%get_iterator( )
      i_spec = 0
      do while( iter%next( ) )
        i_spec = i_spec + 1
        associate( override => this%overrides_( i_spec ) )
        spec_name = spec_set%key( iter )
        call spec_set%get( iter, spec_data, my_name )
        call spec_data%get( "mixing ratio mol mol-1",                         &
                            override%mixing_ratio__mol_mol_, my_name )
        call assert_msg( 452759550,                                           &
                         this%core_%spec_state_id( spec_name%to_char( ),      &
                                                   override%camp_id_ ),       &
                         "Cannot find species '"//spec_name%to_char( )//      &
                         "' in CAMP mechanism" )
        end associate
      end do
      call assert( 617677744, i_spec .eq. size( this%overrides_ ) )
      deallocate( iter )
    else
      allocate( this%overrides_( 0 ) )
    end if

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
    class(camp_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP environment connector"
    type(domain_target_cells_t) :: all_cells
    type(property_t), pointer :: prop

    prop => property_t( my_name, name = "temperature", units = "K",           &
                        applies_to = all_cells, data_type = kDouble )
    this%temperature__K_ => domain%accessor( prop )
    deallocate( prop )
    prop => property_t( my_name, name = "pressure", units = "Pa",             &
                        applies_to = all_cells, data_type = kDouble )
    this%pressure__Pa_ => domain%accessor( prop )
    deallocate( prop )
    prop => property_t( my_name, name = "number density air",                 &
                        units = "mol m-3", applies_to = all_cells,            &
                        data_type = kDouble )
    this%number_density_air__mol_m3_ => domain%accessor( prop )
    deallocate( prop )

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
    class(camp_t), intent(inout) :: this
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

    ! check if photolysis rate constants should be output
    call config%get( "output photolysis rate constants",                      &
                     this%output_photolysis_rate_constants_,                  &
                     my_name, found = found )

    key = "MUSICA name"

    call assert( 108675461, .not. allocated( this%photolysis_ ) )
    call assert( 171795900, associated( this%core_%mechanism ) )
    n_rxn = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_photolysis_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            n_rxn = n_rxn + 1
          end if
        end select
      end do
    end associate
    end do
    allocate( this%photolysis_( n_rxn ) )
    i_updater = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_photolysis_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            prop => property_t( my_name,                                      &
                                name = "photolysis_rate_constants%"//temp_str,&
                                units = "s-1",                                &
                                applies_to = all_cells,                       &
                                data_type = kDouble,                          &
                                default_value = 0.0_musica_dk )
            call domain%register( prop )
            i_updater = i_updater + 1
            associate( pair => this%photolysis_( i_updater ) )
            pair%accessor_ => domain%accessor( prop )
            allocate( rxn_update_data_photolysis_t :: pair%updater_ )
            call this%core_%initialize_update_object( rxn, pair%updater_ )
            if( this%output_photolysis_rate_constants_ ) then
              call output%register_output_variable( domain,                   &
                                "photolysis_rate_constants%"//temp_str,       &
                                "s-1",                                        &
                                "PHOTO."//temp_str )
            end if
            end associate
            deallocate( prop )
          end if
        end select
      end do
    end associate
    end do
    call assert( 253930157, i_updater .eq. n_rxn )

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
    class(camp_t), intent(inout) :: this
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

    key = "MUSICA name"

    call assert( 135018976, .not. allocated( this%emissions_ ) )
    call assert( 582386822, associated( this%core_%mechanism ) )
    n_rxn = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_emission_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            n_rxn = n_rxn + 1
          end if
        end select
      end do
    end associate
    end do
    allocate( this%emissions_( n_rxn ) )
    i_updater = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_emission_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            prop => property_t( my_name,                                      &
                                name = "emission_rates%"//temp_str,           &
                                units = "mol m-3 s-1",                        &
                                applies_to = all_cells,                       &
                                data_type = kDouble,                          &
                                default_value = 0.0_musica_dk )
            call domain%register( prop )
            i_updater = i_updater + 1
            associate( pair => this%emissions_( i_updater ) )
            pair%accessor_ => domain%accessor( prop )
            allocate( rxn_update_data_emission_t :: pair%updater_ )
            call this%core_%initialize_update_object( rxn, pair%updater_ )
            end associate
            deallocate( prop )
          end if
        end select
      end do
    end associate
    end do
    call assert( 192732825, i_updater .eq. n_rxn )

  end subroutine connect_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect external deposition rate constants to the CAMP mechanism
  subroutine connect_deposition( this, config, domain, output )

    use musica_assert,                 only : assert
    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t
    use musica_string,                 only : string_t
    use camp_rxn_data,                 only : rxn_data_t
    use camp_rxn_first_order_loss,     only : rxn_first_order_loss_t,         &
                                            rxn_update_data_first_order_loss_t
    use camp_util,                     only : camp_string_t => string_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> CAMP configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "CAMP deposition connector"
    integer(kind=musica_ik) :: i_rxn, i_mech, n_rxn, i_updater
    type(property_t), pointer :: prop
    type(domain_target_cells_t) :: all_cells
    class(rxn_data_t), pointer :: rxn
    character(len=:), allocatable :: key, temp_str

    key = "MUSICA name"

    call assert( 674552529, .not. allocated( this%deposition_ ) )
    call assert( 221920376, associated( this%core_%mechanism ) )
    n_rxn = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_first_order_loss_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            n_rxn = n_rxn + 1
          end if
        end select
      end do
    end associate
    end do
    allocate( this%deposition_( n_rxn ) )
    i_updater = 0
    do i_mech = 1, size( this%core_%mechanism )
    associate( mech => this%core_%mechanism( i_mech )%val )
      do i_rxn = 1, mech%size( )
        rxn => mech%get_rxn( i_rxn )
        select type( rxn )
        class is( rxn_first_order_loss_t )
          if( rxn%property_set%get_string( key, temp_str ) ) then
            prop => property_t( my_name,                                      &
                                name = "loss_rate_constants%"//temp_str,      &
                                units = "s-1",                                &
                                applies_to = all_cells,                       &
                                data_type = kDouble,                          &
                                default_value = 0.0_musica_dk )
            call domain%register( prop )
            i_updater = i_updater + 1
            associate( pair => this%deposition_( i_updater ) )
            pair%accessor_ => domain%accessor( prop )
            allocate( rxn_update_data_first_order_loss_t :: pair%updater_ )
            call this%core_%initialize_update_object( rxn, pair%updater_ )
            end associate
            deallocate( prop )
          end if
        end select
      end do
    end associate
    end do
    call assert( 689316150, i_updater .eq. n_rxn )

  end subroutine connect_deposition

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with MUSICA species concentrations
  subroutine update_camp_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec
    real(kind=musica_dk) :: number_density, new_value

    call domain_state%get( domain_element, this%number_density_air__mol_m3_,  &
                           number_density )
    do i_spec = 1, size( this%get_species_state__mol_m3_ )
    associate( accessor => this%get_species_state__mol_m3_( i_spec )%val_ )
      call domain_state%get( domain_element, accessor, new_value )
      this%state_%state_var( i_spec ) = 1.0d6 * new_value / number_density
    end associate
    end do
    do i_spec = 1, size( this%overrides_ )
    associate( override => this%overrides_( i_spec ) )
      this%state_%state_var( override%camp_id_ ) =                            &
          1.0d6 * override%mixing_ratio__mol_mol_
    end associate
    end do

  end subroutine update_camp_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with MUSICA environmental parameters
  subroutine update_camp_environment( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    real(kind=musica_dk) :: new_value

    call domain_state%get( domain_element, this%temperature__K_, new_value )
    call this%state_%env_states(1)%set_temperature_K( new_value )
    call domain_state%get( domain_element, this%pressure__Pa_, new_value )
    call this%state_%env_states(1)%set_pressure_Pa( new_value )

  end subroutine update_camp_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided photolysis rate constants
  subroutine update_camp_photolysis( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_photolysis,           only : rxn_update_data_photolysis_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value

    do i_pair = 1, size( this%photolysis_ )
    associate( pair => this%photolysis_( i_pair ) )
      select type( updater => pair%updater_ )
      class is( rxn_update_data_photolysis_t )
        call domain_state%get( domain_element, pair%accessor_, update_value )
        call updater%set_rate( update_value )
        call this%core_%update_data( updater )
      class default
        call die( 232110673 )
      end select
    end associate
    end do

  end subroutine update_camp_photolysis

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided emissions rate constants
  subroutine update_camp_emissions( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_emission,             only : rxn_update_data_emission_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value, number_density

    call domain_state%get( domain_element, this%number_density_air__mol_m3_,  &
                           number_density )
    do i_pair = 1, size( this%emissions_ )
    associate( pair => this%emissions_( i_pair ) )
      select type( updater => pair%updater_ )
      class is( rxn_update_data_emission_t )
        call domain_state%get( domain_element, pair%accessor_, update_value )
        call updater%set_rate( update_value / number_density * 1.0e6 )
        call this%core_%update_data( updater )
      class default
        call die( 190238180 )
      end select
    end associate
    end do

  end subroutine update_camp_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update CAMP with externally provided deposition rate constants
  subroutine update_camp_deposition( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t
    use camp_rxn_first_order_loss,     only : rxn_update_data_first_order_loss_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value

    do i_pair = 1, size( this%deposition_ )
    associate( pair => this%deposition_( i_pair ) )
      select type( updater => pair%updater_ )
      class is( rxn_update_data_first_order_loss_t )
        call domain_state%get( domain_element, pair%accessor_, update_value )
        call updater%set_rate( update_value )
        call this%core_%update_data( updater )
      class default
        call die( 916722502 )
      end select
    end associate
    end do

  end subroutine update_camp_deposition

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update MUSICA with CAMP species concentrations
  subroutine update_musica_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> CAMP interface
    class(camp_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec
    real(kind=musica_dk) :: number_density, new_value

    call domain_state%get( domain_element, this%number_density_air__mol_m3_,  &
                           number_density )
    do i_spec = 1, size( this%set_species_state__mol_m3_ )
    associate( mutator => this%set_species_state__mol_m3_( i_spec )%val_ )
      new_value = this%state_%state_var( i_spec ) * 1.0d-6 * number_density
      call domain_state%update( domain_element, mutator, new_value )
    end associate
    end do

  end subroutine update_musica_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes a reaction_updater_t object
  elemental subroutine reaction_updater_finalize( this )

    !> Reaction updater pair
    type(reaction_updater_t), intent(inout) :: this

    if( associated( this%accessor_ ) ) deallocate( this%accessor_ )
    if( associated( this%updater_  ) ) deallocate( this%updater_  )

  end subroutine reaction_updater_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes a camp_t object
  elemental subroutine finalize( this )

    !> CAMP interface
    type(camp_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_elem

    if( associated( this%core_ ) ) deallocate( this%core_ )
    if( associated( this%state_ ) ) deallocate( this%state_ )
    if( associated( this%get_species_state__mol_m3_ ) ) then
      do i_elem = 1, size( this%get_species_state__mol_m3_ )
        if( associated( this%get_species_state__mol_m3_( i_elem )%val_ ) ) then
          deallocate( this%get_species_state__mol_m3_( i_elem )%val_ )
        end if
      end do
      deallocate( this%get_species_state__mol_m3_ )
    end if
    if( associated( this%set_species_state__mol_m3_ ) ) then
      do i_elem = 1, size( this%set_species_state__mol_m3_ )
        if( associated( this%set_species_state__mol_m3_( i_elem )%val_ ) ) then
          deallocate( this%set_species_state__mol_m3_( i_elem )%val_ )
        end if
      end do
      deallocate( this%set_species_state__mol_m3_ )
    end if
    if( associated( this%temperature__K_ ) ) deallocate( this%temperature__K_ )
    if( associated( this%pressure__Pa_   ) ) deallocate( this%pressure__Pa_   )
    if( associated( this%number_density_air__mol_m3_ ) )                      &
        deallocate( this%number_density_air__mol_m3_ )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_camp
