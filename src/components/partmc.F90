!> \file
!> The music_box_partmc module

!> The partmc_t type and related functions
module music_box_partmc

  use musica_component,                only : component_t
  use musica_config,                   only : config_t
  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain_state_accessor,    only : domain_state_accessor_t,        &
                                              domain_state_accessor_ptr
  use musica_domain_state_mutator,     only : domain_state_mutator_t,         &
                                              domain_state_mutator_ptr
  use pmc_aero_state
  use pmc_gas_state
  use pmc_gas_data
  use pmc_aero_data
  use pmc_env_state
  use pmc_scenario

  use pmc_bin_grid
  use pmc_aero_dist
  use pmc_aero_binned
  use pmc_coag_kernel
  use pmc_run_part
  use pmc_spec_file
  use pmc_util

  implicit none
  private

  public :: partmc_t

  !> Interface to PartMC (PartMC)
  !!
  !! PartMC can be used for simulating particle-resolved emissions, dilution,
  !! coagulation, and nucleation.
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
    !> Aerosol state
    type(aero_state_t) :: aero_state
    !> Aerosol data
    type(aero_data_t) :: aero_data
    !> Gas state
    type(gas_state_t) :: gas_state
    !> Gas data
    type(gas_data_t) :: gas_data
    !> Environmental state
    type(env_state_t) :: env_state
    !> Scenario data
    type(scenario_t) :: scenario
    !> Configuration options
    type(run_part_opt_t) :: run_part_opt
    !> Emissions reaction updaters
!    type(reaction_updater_t), allocatable :: emissions_(:)
    !> Temperature [K] accessor
    class(domain_state_accessor_t), pointer :: temperature__K_ => null( )
    !> Pressure [Pa] accessor
    class(domain_state_accessor_t), pointer :: pressure__Pa_ => null( )
    !> Box height [m] accessor
    class(domain_state_accessor_t), pointer :: height__m_ => null( )
    !> Number density of air [mol m-3]
    class(domain_state_accessor_t), pointer ::                                &
        number_density_air__mol_m3_ => null( )
  contains
    !> Returns the name of the component
    procedure :: name => component_name
    !> Returns a description of the component purpose
    procedure :: description
    !> Advance the model state for a given timestep
    procedure :: advance_state
    !> Save the component configuration for future simultaions
    procedure :: preprocess_input
    !> Connect MUSICA chemical species concentrations to the PartMC mechanism
    procedure, private :: connect_species_state
    !> Connect MUSICA environmental parameters to the PartMC mechanism
    procedure, private :: connect_environment
    !> Connect external emissions rates to the PartMC mechanism
    procedure, private :: connect_emissions
    !> Update PartMC with MUSICA species concentrations
    procedure, private :: update_partmc_species_state
    !> Update PartMC with MUSICA environmental parameters
    procedure, private :: update_partmc_environment
    !> Update PartMC with externally provided emission rates
    procedure, private :: update_partmc_emissions
    !> Update MUSICA with PartMC species concentrations
    procedure, private :: update_musica_species_state
    !> Finalizes a partmc_t object
    final :: finalize
  end type partmc_t

  !> Constructor of partmc_t objects
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

    !> New PartMC interface
    type(partmc_t), pointer :: new_obj
    !> PartMC configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "PartMC interface constructor"
    type(string_t) :: config_file_name

    character(len=100) :: spec_name
    type(spec_file_t) :: file
    type(run_part_opt_t) :: run_part_opt
    character(len=PMC_MAX_FILENAME_LEN) :: sub_filename
    type(spec_file_t) :: sub_file

    type(gas_state_t) :: gas_state_init
    type(aero_dist_t) :: aero_dist_init
    type(aero_state_t) :: aero_state_init
    type(scenario_t) :: scenario
    type(env_state_t) :: env_state_init
    type(aero_data_t) :: aero_data
    type(gas_data_t) :: gas_data

    real(kind=dp) :: n_part
    logical :: do_restart, do_init_equilibriate, aero_mode_type_exp_present
    integer :: rand_init

    call config%get( "configuration file", config_file_name, my_name )
    spec_name = config_file_name%to_char()

    allocate( new_obj )
    call spec_file_open(spec_name, file)

    call spec_file_read_real(file, 'n_part', n_part)

    env_state_init%elapsed_time = 0d0
    call spec_file_read_string(file, 'gas_data', sub_filename)
    call spec_file_open(sub_filename, sub_file)
    call spec_file_read_gas_data(sub_file, gas_data)
    call spec_file_close(sub_file)

    call spec_file_read_string(file, 'gas_init', sub_filename)
    call spec_file_open(sub_filename, sub_file)
    call spec_file_read_gas_state(sub_file, gas_data, &
         gas_state_init)
    call spec_file_close(sub_file)

    call spec_file_read_string(file, 'aerosol_data', sub_filename)
    call spec_file_open(sub_filename, sub_file)
    call spec_file_read_aero_data(sub_file, aero_data)
    call spec_file_close(sub_file)
    call spec_file_read_fractal(file, aero_data%fractal)

    call spec_file_read_string(file, 'aerosol_init', sub_filename)
    call spec_file_open(sub_filename, sub_file)
    call spec_file_read_aero_dist(sub_file, aero_data, aero_dist_init)
    call spec_file_close(sub_file)

    ! TODO: Eventually will be replaced spec_file_read_scenario reads:
    !   - temperature, pressure and box height profile
    !   - gas emissions, aerosol emissions
    !   - gas background, aerosol background
    !   - loss function
    ! Will be replaced with connect_environment()
    call spec_file_read_scenario(file, gas_data, aero_data, scenario)
    ! TODO: spec_file_read_env_state reads:
    !   - relative humidity
    !   - latitude, longitude, altitude
    !   - start time and start day
    call spec_file_read_env_state(file, env_state_init)

    call spec_file_read_logical(file, 'do_coagulation', &
         run_part_opt%do_coagulation)
    if (run_part_opt%do_coagulation) then
       call spec_file_read_coag_kernel_type(file, &
            run_part_opt%coag_kernel_type)
    else
       run_part_opt%coag_kernel_type = COAG_KERNEL_TYPE_INVALID
    end if

    call spec_file_read_logical(file, 'do_condensation', &
         run_part_opt%do_condensation)
#ifndef PMC_USE_SUNDIALS
    call assert_msg(121370218, &
         run_part_opt%do_condensation .eqv. .false., &
         "cannot use condensation, SUNDIALS support is not compiled in")
#endif
    if (run_part_opt%do_condensation) then
       call spec_file_read_logical(file, 'do_init_equilibriate', &
            do_init_equilibriate)
    else
       do_init_equilibriate = .false.
    end if

    run_part_opt%do_optical = .false.

    call spec_file_read_logical(file, 'do_nucleation', &
         run_part_opt%do_nucleation)
    if (run_part_opt%do_nucleation) then
       call spec_file_read_nucleate_type(file, aero_data, &
            run_part_opt%nucleate_type, run_part_opt%nucleate_source)
    else
       run_part_opt%nucleate_type = NUCLEATE_TYPE_INVALID
    end if

    call spec_file_read_integer(file, 'rand_init', rand_init)
    call spec_file_read_logical(file, 'allow_doubling', &
         run_part_opt%allow_doubling)
    call spec_file_read_logical(file, 'allow_halving', &
         run_part_opt%allow_halving)
    call spec_file_read_logical(file, 'do_select_weighting', &
         run_part_opt%do_select_weighting)
    if (run_part_opt%do_select_weighting) then
       call spec_file_read_aero_state_weighting_type(file, &
            run_part_opt%weighting_type, run_part_opt%weighting_exponent)
    else
       run_part_opt%weighting_type = AERO_STATE_WEIGHT_NUMMASS_SOURCE
       run_part_opt%weighting_exponent = 0.0d0
    end if
    call spec_file_read_logical(file, 'record_removals', &
         run_part_opt%record_removals)

    call spec_file_read_logical(file, 'do_parallel', &
         run_part_opt%do_parallel)

    run_part_opt%output_type = OUTPUT_TYPE_SINGLE
    run_part_opt%mix_timescale = 0d0
    run_part_opt%gas_average = .false.
    run_part_opt%env_average = .false.
    run_part_opt%parallel_coag_type = PARALLEL_COAG_TYPE_LOCAL

    ! set things just in case
    run_part_opt%n_repeat = 1
    run_part_opt%t_progress = 0
    run_part_opt%do_mosaic = .false.
    run_part_opt%do_camp_chem = .false.

    new_obj%env_state = env_state_init
    new_obj%scenario = scenario
    new_obj%gas_data = gas_data
    new_obj%aero_data = aero_data
    new_obj%run_part_opt = run_part_opt

    call aero_state_zero(new_obj%aero_state)
    aero_mode_type_exp_present &
         = aero_dist_contains_aero_mode_type(aero_dist_init, &
         AERO_MODE_TYPE_EXP) &
         .or. scenario_contains_aero_mode_type(scenario, &
         AERO_MODE_TYPE_EXP)
    if (aero_mode_type_exp_present) then
       call warn_msg(245301880, "using flat weighting only due to " &
            // "presence of exp aerosol mode")
       call aero_state_set_weight(new_obj%aero_state, aero_data, &
            AERO_STATE_WEIGHT_FLAT)
    else
       call aero_state_set_weight(new_obj%aero_state, aero_data, &
            run_part_opt%weighting_type, run_part_opt%weighting_exponent)
    end if
    call aero_state_set_n_part_ideal(new_obj%aero_state, n_part)
    call aero_state_add_aero_dist_sample(new_obj%aero_state, aero_data, &
         aero_dist_init, 1d0, 0d0, run_part_opt%allow_doubling, &
         run_part_opt%allow_halving)

    call spec_file_close(file)

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component name
  type(string_t) function component_name( this )

    use musica_string,                 only : string_t

    !> PartMC interface
    class(partmc_t), intent(in) :: this

    component_name = "PartMC: Particle-resolved Monte Carlo code for" &
         // "atmospheric aerosol simulation"

  end function component_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component description
  type(string_t) function description( this )

    use musica_string,                 only : string_t

    !> PartMC interface
    class(partmc_t), intent(in) :: this

    description = "Particle-resolved aerosol representation"

  end function description

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the model state for multi-phase chemistry
  subroutine advance_state( this, domain_state, domain_element,               &
      current_time__s, time_step__s )

    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_state,           only : domain_state_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: current_time__s
    !> Time step to advance state by [s]
    real(kind=musica_dk), intent(in) :: time_step__s

    integer :: n_dil_in, n_dil_out, n_emit, n_samp, n_coag
    type(env_state_t) :: old_env_state

!    ! update PartMC with externally provided parameters
!     call this%update_partmc_species_state( domain_state, domain_element )
    old_env_state = this%env_state
!    call this%update_partmc_environment(   domain_state, domain_element, &
!         time_step__s )
!    call this%update_partmc_emissions(     domain_state, domain_element )
    ! TODO: What is current simulation time?
    call scenario_update_env_state(this%scenario, this%env_state, &
         this%env_state%elapsed_time + time_step__s)
    print*, this%env_state%elapsed_time, 'temp:', this%env_state%temp, &
         'n_part:', aero_state_n_part(this%aero_state)

    ! solve
    if (this%run_part_opt%do_nucleation) then
       call nucleate(this%run_part_opt%nucleate_type, &
            this%run_part_opt%nucleate_source, this%env_state, this%gas_data, &
            this%aero_data, this%aero_state, this%gas_state, time_step__s, &
            this%run_part_opt%allow_doubling, this%run_part_opt%allow_halving)
    end if

    if (this%run_part_opt%do_coagulation) then
       call mc_coag(this%run_part_opt%coag_kernel_type, this%env_state, &
            this%aero_data, this%aero_state, time_step__s, n_samp, n_coag)
       print*, 'n_coag', n_coag
    end if

    call scenario_update_aero_state(this%scenario, time_step__s, &
         this%env_state, old_env_state, this%aero_data, this%aero_state, &
         n_emit, n_dil_in, n_dil_out, this%run_part_opt%allow_doubling, &
         this%run_part_opt%allow_halving)
    print*, 'n_emit:', n_emit, 'n_dil_in:', n_dil_in, 'n_dil_out', n_dil_out

    call aero_state_rebalance(this%aero_state, this%aero_data, &
         this%run_part_opt%allow_doubling, &
         this%run_part_opt%allow_halving, initial_state_warning=.false.)

    ! update MUSICA with PartMC results
    call this%update_musica_species_state( domain_state, domain_element )

  end subroutine advance_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Save the PartMC configuration for future simulations
  subroutine preprocess_input( this, config, output_path )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Model component configuration
    type(config_t), intent(out) :: config
    !> Folder to save input data to
    character(len=*), intent(in) :: output_path

    character(len=*), parameter :: my_name = "PartMC preprocessor"
    type(config_t) :: partmc_orig_config, temp_config
    type(string_t) :: config_file_name
    type(string_t), allocatable :: partmc_files(:), split_file(:)
    logical :: found
    integer(kind=musica_ik) :: i_file

!    ! set MUSICA configuration for PartMC 
!    call config%empty( )
!    call config%add( "type", "PartMC", my_name )
!    call config%add( "configuration file", "partmc_config.spec", my_name )
!
!    ! get the path to the original PartMC configuration file
!    call this%config_%get( "configuration file", config_file_name, my_name )
!    call partmc_orig_config%from_file( config_file_name%to_char( ) )
!
!    ! copy each PartMC configuration file to the output path
!
!    ! save the main PartMC configuration file with updated file names
!    call temp_config%empty( )
!    call temp_config%add( "partmc-files", partmc_files, my_name )
!    call temp_config%to_file( output_path//"partmc_config.spec" )

  end subroutine preprocess_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect MUSICA chemical species concentrations to PartMC
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

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> PartMC configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "PartMC"
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

  !> Connect MUSICA environmental parameters to the PartMC mechanism
  subroutine connect_environment( this, config, domain, output )

    use musica_data_type,              only : kDouble
    use musica_domain,                 only : domain_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_property,               only : property_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> PartMC configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "PartMC environment connector"
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

!    prop => property_t( my_name, name = "number density air",                 &
!                        units = "mol m-3", applies_to = all_cells,            &
!                        data_type = kDouble )
!    this%number_density_air__mol_m3_ => domain%accessor( prop )
!    deallocate( prop )

    ! TODO: Add box height and other variables that music-box controls

  end subroutine connect_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Connect external emissions rates to PartMC
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

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> PartMC configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "PartMC emissions connector"
    integer(kind=musica_ik) :: i_rxn, i_mech, n_rxn, i_updater
    class(rxn_data_t), pointer :: rxn
    type(property_t), pointer :: prop
    type(domain_target_cells_t) :: all_cells
    character(len=:), allocatable :: key, temp_str

  end subroutine connect_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update PartMC with MUSICA species concentrations
  subroutine update_partmc_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec, i_part
    real(kind=musica_dk) :: number_density, new_value

    do i_part = 1,aero_state_n_part(this%aero_state)
       associate (part => this%aero_state%apa%particle(i_part))
       do i_spec = 1,aero_data_n_spec(this%aero_data)
         ! What is new_value ?
         ! part%vol(i_spec) = new_value / aero_data%density(i_spec)
       end do
      end associate
    end do

  end subroutine update_partmc_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update PartMC with MUSICA environmental parameters
  subroutine update_partmc_environment( this, domain_state, domain_element, &
       time_step__s )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element
    !> Time step to advance state by [s]
    real(kind=musica_dk), intent(in) :: time_step__s

    real(kind=musica_dk) :: new_value
    type(env_state_t) :: old_env_state

    old_env_state = this%env_state
    ! TODO: If MUSICA has control of the environment, we will want to replace
    ! this by grabbing temperature, pressure, and box height (?). We will
    ! need to compute rel_humid and elapsed_time.
    call scenario_update_env_state(this%scenario, this%env_state, &
         this%env_state%elapsed_time + time_step__s)

    ! This will not work until MUSICA has control rather than reading the
    ! time series from PartMC input files
    call domain_state%get( domain_element, this%temperature__K_, new_value )
!    this%env_state%temp = new_value
    call domain_state%get( domain_element, this%pressure__Pa_, new_value )
!    this%env_state%pressure = new_value

  end subroutine update_partmc_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update PartMC with externally provided emissions rate constants
  subroutine update_partmc_emissions( this, domain_state, domain_element )

    use musica_assert,                 only : die
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_pair
    real(kind=musica_dk) :: update_value, number_density

  end subroutine update_partmc_emissions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update MUSICA with PartMC species concentrations
  subroutine update_musica_species_state( this, domain_state, domain_element )

    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> PartMC interface
    class(partmc_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element

    integer(kind=musica_ik) :: i_spec, i_part
    real(kind=musica_dk) :: number_density, new_value

    do i_part = 1, aero_state_n_part(this%aero_state)
       associate (part => this%aero_state%apa%particle(i_part))
       do i_spec = 1, aero_data_n_spec(this%aero_data)
          ! Index is something like...
          ! (i_part - 1) * n_spec  + i_spec
          new_value = part%vol(i_spec) * this%aero_data%density(i_spec)
       end do
       end associate
    end do

  end subroutine update_musica_species_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes a partmc_t object
  elemental subroutine finalize( this )

    !> CAMP interface
    type(partmc_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_elem

    if( associated( this%temperature__K_ ) ) deallocate( this%temperature__K_ )
    if( associated( this%pressure__Pa_   ) ) deallocate( this%pressure__Pa_   )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_partmc
