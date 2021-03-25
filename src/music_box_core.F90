! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_core module

!> The core_t type and related functions
module music_box_core

  use musica_component_set,            only : component_set_t
  use musica_constants,                only : musica_ik, musica_dk
  use musica_datetime,                 only : datetime_t
  use musica_domain,                   only : domain_t
  use musica_domain_state_mutator,     only : domain_state_mutator_ptr
  use musica_domain_state_accessor,    only : domain_state_accessor_ptr
  use musica_emissions,                only : emissions_t
  use musica_evolving_conditions,      only : evolving_conditions_t
  use musica_initial_conditions,       only : initial_conditions_t
  use musica_input_output_processor,   only : input_output_processor_t
  use musica_loss,                     only : loss_t

  implicit none
  private

  public :: core_t

  !> MusicBox core
  !!
  !! Top-level model object. The core manages model initialization, grids,
  !! science packages, output, and finalization.
  type :: core_t
    private
    !> Model domain
    class(domain_t), pointer :: domain_ => null( )
    !> Base time step for the model [s]
    real(kind=musica_dk) :: model_base_time_step__s_
    !> Chemistry solve times [s]
    real(kind=musica_dk), allocatable :: simulation_times__s_(:)
    !> Output time step [s]
    real(kind=musica_dk) :: output_time_step__s_
    !> Next output time [s]
    real(kind=musica_dk) :: next_output_time__s_ = 0.0_musica_dk
    !> Simulation start
    type(datetime_t) :: simulation_start_
    !> Simulation length [s]
    real(kind=musica_dk) :: simulation_length__s_
    !> Standard state variable mutators
    type(domain_state_mutator_ptr), allocatable :: mutators_(:)
    !> Standard state variable accessor
    type(domain_state_accessor_ptr), allocatable :: accessors_(:)
    !> Initial model conditions
    class(initial_conditions_t), pointer :: initial_conditions_ => null( )
    !> Evolving model conditions
    class(evolving_conditions_t), pointer :: evolving_conditions_ => null( )
    !> Output
    class(input_output_processor_t), pointer :: output_ => null( )
    !> Model components
    type(component_set_t), pointer :: components_ => null( )
  contains
    !> Run the model
    procedure :: run
    !> Preprocess input data
    procedure :: preprocess_input
    !> Register standard state variables
    procedure, private :: register_standard_state_variables
    !> Register output variables
    procedure, private :: register_output_variables
    !> Update the environmental conditions for a new time step
    procedure, private :: update_environment
    !> Output the current model state
    procedure, private :: output
    !> Clean up the memory
    final :: finalize
  end type core_t

  !> Constructor
  interface core_t
    module procedure constructor
  end interface core_t

  !> Private indices for standard state variables
  !! @{

  !> Number of standard state variables
  integer, parameter :: kNumberOfStandardVariables = 3

  !> Temperature [K]
  integer, parameter :: kTemperature = 1
  !> Pressuse [Pa]
  integer, parameter :: kPressure = 2
  !> Number density of air [mol m-3]
  integer, parameter :: kNumberDensityAir = 3

  !> @}

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> MusicBox core constructor
  !!
  !! Loads input data and initializes model components.
  function constructor( config_file_path ) result( new_obj )

    use musica_array,                  only : merge_series
    use musica_component,              only : component_t
    use musica_component_factory,      only : component_builder
    use musica_config,                 only : config_t
    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_factory,         only : domain_builder
    use musica_iterator,               only : iterator_t
    use musica_string,                 only : string_t

    !> New MusicBox core
    class(core_t), pointer :: new_obj
    !> Path to the configuration file
    character(len=*), intent(in) :: config_file_path

    character(len=*), parameter :: my_name = "MusicBox core constructor"
    type(config_t) :: config, model_opts, domain_opts, output_opts,           &
                      evolving_opts, datetime_data, components,               &
                      component_config
    class(component_t), pointer :: component
    type(string_t) :: domain_type
    logical :: found
    real(kind=musica_dk), allocatable :: update_times(:)
    integer(kind=musica_ik) :: i_step, n_time_steps
    class(iterator_t), pointer :: iter

    allocate( core_t :: new_obj )

    call print_header( )

    ! load configuration data
    call config%from_file( config_file_path )
    call config%get( "box model options", model_opts, my_name )

    ! build the domain
    call model_opts%get( "grid", domain_type, my_name )
    domain_opts = '{ "type" : "'//domain_type//'" }'
    new_obj%domain_ => domain_builder( domain_opts )

    ! register the accessors and mutators for the standard state variables
    call new_obj%register_standard_state_variables( )

    ! set up the output for the model
    call config%get( "output file", output_opts, my_name, found = found )
    if( .not. found ) output_opts = '{ "type" : "CSV" }'
    call output_opts%add( "intent", "output", my_name )
    new_obj%output_ => input_output_processor_t( output_opts )
    call new_obj%register_output_variables( )

    ! simulation time parameters
    call model_opts%get( "chemistry time step", "s",                          &
                         new_obj%model_base_time_step__s_, my_name )
    call model_opts%get( "output time step", "s",                             &
                         new_obj%output_time_step__s_, my_name )
    call model_opts%get( "simulation length", "s",                            &
                         new_obj%simulation_length__s_, my_name )
    call model_opts%get( "simulation start", datetime_data, my_name,          &
                         found = found )
    if( found ) then
      new_obj%simulation_start_ = datetime_t( datetime_data )
    end if

    ! set the default solver times
    n_time_steps = ceiling( new_obj%simulation_length__s_ /                   &
                            new_obj%model_base_time_step__s_ ) + 1
    allocate( new_obj%simulation_times__s_( n_time_steps ) )
    do i_step = 1, n_time_steps
      new_obj%simulation_times__s_( i_step ) =                                &
        new_obj%simulation_start_%in_seconds( ) +                             &
        min( ( i_step - 1 ) * new_obj%model_base_time_step__s_,               &
             new_obj%simulation_length__s_ )
    end do

    ! include output times in solver times
    n_time_steps = ceiling( new_obj%simulation_length__s_ /                   &
                            new_obj%output_time_step__s_ ) + 1
    allocate( update_times( n_time_steps ) )
    do i_step = 1, n_time_steps
      update_times( i_step ) =                                                &
        new_obj%simulation_start_%in_seconds( ) +                             &
        min( ( i_step - 1 ) * new_obj%output_time_step__s_,                   &
             new_obj%simulation_length__s_ )
    end do
    new_obj%simulation_times__s_ =                                            &
      merge_series( new_obj%simulation_times__s_, update_times )

    ! set up the model components
    new_obj%components_ => component_set_t( )
    call config%get( "model components", components, my_name )
    iter => components%get_iterator( )
    do while( iter%next( ) )
      call components%get( iter, component_config, my_name )
      component => component_builder( component_config,                       &
                                      new_obj%domain_,                        &
                                      new_obj%output_ )
      call new_obj%components_%add( component )
      component => null( )
    end do
    deallocate( iter )

    ! set up the initial conditions
    new_obj%initial_conditions_ => initial_conditions_t( config,              &
                                                         new_obj%domain_ )

    ! set up the evolving conditions
    call config%get( "evolving conditions", evolving_opts, my_name,           &
                     found = found )
    if( found ) then
      new_obj%evolving_conditions_ => evolving_conditions_t( evolving_opts,   &
                                                             new_obj%domain_ )
      update_times = new_obj%evolving_conditions_%get_update_times__s( )
      new_obj%simulation_times__s_ =                                          &
        merge_series( new_obj%simulation_times__s_, update_times,             &
                      with_bounds_from = new_obj%simulation_times__s_ )
    end if

    ! lock the domain against further changes
    call new_obj%domain_%lock( )

    ! output the registered domain state variables
    call new_obj%domain_%output_registry( )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Run the model
  subroutine run( this )

    use musica_component,              only : component_t
    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_state,           only : domain_state_t
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_logger,                 only : logger_t

    !> MusicBox core
    class(core_t), intent(inout) :: this

    ! Current model simulation time [s]
    real(kind=musica_dk) :: sim_time__s
    ! Current model simulation time step [s]
    real(kind=musica_dk) :: time_step__s

    ! model domain state
    class(domain_state_t), pointer :: state

    ! domain iterator over every cell
    type(domain_target_cells_t) :: all_cells
    class(domain_iterator_t), pointer :: cell_iter

    ! model component pointer
    class(component_t), pointer :: component

    type(logger_t) :: logger
    integer(kind=musica_ik) :: i_step, i_component

    logger = logger_t( this%simulation_times__s_( 1 ),                        &
            this%simulation_times__s_( size( this%simulation_times__s_ ) ) )

    ! set up theiterators
    cell_iter      => this%domain_%iterator( all_cells )

    ! reset to initial conditions
    sim_time__s = this%simulation_times__s_( 1 )

    ! reset the next output time
    this%next_output_time__s_ = 0.0_musica_dk

    ! get a new model state and set the initial conditions
    state => this%initial_conditions_%get_state( this%domain_ )
    if( associated( this%evolving_conditions_ ) ) then
      call this%evolving_conditions_%update_state( this%domain_,              &
                                                   state,                     &
                                                   sim_time__s )
    end if
    call cell_iter%reset( )
    do while( cell_iter%next( ) )
      call this%update_environment( state, cell_iter )
    end do

    ! start simulation
    do i_step = 2, size( this%simulation_times__s_ )

      call logger%progress( sim_time__s )

      ! output initial conditions for this time step
      call this%output( state, sim_time__s )

      ! determine the current time step
      time_step__s = this%simulation_times__s_( i_step ) -                    &
                     this%simulation_times__s_( i_step - 1 )

      ! update variables tethered to initial conditions
      call this%initial_conditions_%update_state( this%domain_, state )

      ! update evolving conditions from input data
      if( associated( this%evolving_conditions_ ) ) then
        call this%evolving_conditions_%update_state( this%domain_,            &
                                                     state,                   &
                                                     sim_time__s )
      end if

      ! iterate over cells in the domain
      call cell_iter%reset( )
      do while( cell_iter%next( ) )

        ! update environmental conditions
        call this%update_environment( state, cell_iter )

        ! run model components for current cell
        do i_component = 1, this%components_%size( )
          component => this%components_%get( i_component )
          call component%advance_state( state, cell_iter, sim_time__s,        &
                                        time_step__s )
        end do

      end do

      ! advance the simulation time
      sim_time__s  = this%simulation_times__s_( i_step )

    end do

    ! output the final model state
    call this%output( state, sim_time__s, force_output = .true. )

    ! clean up
    deallocate( state          )
    deallocate( cell_iter      )

    write(*,*) ""
    write(*,*) "MusicBox simulation complete!"

  end subroutine run

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Preprocess input data
  subroutine preprocess_input( this, output_path )

    use musica_assert,                 only : assert
    use musica_component,              only : component_t
    use musica_config,                 only : config_t
    use musica_iterator,               only : iterator_t

    !> MusicBox core
    class(core_t), intent(inout) :: this
    !> Directory to save model configuration to
    character(len=*), intent(in) :: output_path

    character(len=*), parameter :: my_name = "Model input preprocessor"
    type(config_t) :: config, box_model, init_cond, evolv_cond, date_config
    type(config_t), allocatable :: component_config(:)
    integer(kind=musica_ik) :: i_component
    class(component_t), pointer :: component
    class(iterator_t), pointer :: component_iter

    write(*,*) "MusicBox configuration will saved be to: "//trim( output_path )
    write(*,*)
    write(*,*) "Preprocessing input data..."

    call assert( 215400742, associated( this%domain_ ) )
    call box_model%add( "grid", this%domain_%type( ), my_name )
    call box_model%add( "chemistry time step", "s",                           &
                        this%model_base_time_step__s_, my_name )
    call box_model%add( "output time step", "s", this%output_time_step__s_,   &
                        my_name )
    call box_model%add( "simulation length", "s", this%simulation_length__s_, &
                        my_name )
    if( this%simulation_start_%in_seconds( ) .gt. 0.0_musica_dk ) then
      call this%simulation_start_%to_config( date_config )
      call box_model%add( "simulation start", date_config, my_name )
    end if
    call config%add( "box model options", box_model, my_name )

    call this%initial_conditions_%preprocess_input( init_cond, this%domain_,  &
                                                    output_path )
    call config%add( "initial conditions", init_cond, my_name )

    if( associated( this%evolving_conditions_ ) ) then
      call this%evolving_conditions_%preprocess_input( evolv_cond,            &
          this%domain_,                                                       &
          this%simulation_start_%in_seconds( ),                               &
          this%simulation_start_%in_seconds( ) + this%simulation_length__s_,  &
          output_path )
      call config%add( "evolving conditions", evolv_cond, my_name )
    end if

    allocate( component_config( this%components_%size( ) ) )
    do i_component = 1, this%components_%size( )
      component => this%components_%get( i_component )
      call component%preprocess_input( component_config( i_component ),       &
                                       output_path )
    end do
    call config%add( "model components", component_config, my_name )

    call config%to_file( output_path//"config.json" )

    write(*,*)
    write(*,*) "MusicBox preprocessing complete!"
    write(*,*)

  end subroutine preprocess_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register the standard state variable accessors and mutators with the
  !! domain.
  subroutine register_standard_state_variables( this )

    use musica_assert,                 only : assert
    use musica_data_type,              only : kDouble
    use musica_domain_target_cells,    only : domain_target_cells_t
    use musica_property,               only : property_t

    !> MusicBox core
    class(core_t), intent(inout) :: this

    character(len=*), parameter :: my_name = "MUSICA core registrar"
    type(property_t), pointer :: prop
    type(domain_target_cells_t) :: all_cells

    call assert( 943402309, associated( this%domain_ ) )

    allocate( this%accessors_( kNumberOfStandardVariables ) )
    allocate( this%mutators_(  kNumberOfStandardVariables ) )

    ! register variables and get mutators

    ! temperature
    prop => property_t( my_name, name = "temperature", units = "K",           &
                        applies_to = all_cells, data_type = kDouble,          &
                        default_value = 0.0_musica_dk )
    call this%domain_%register( prop )
    this%mutators_(  kTemperature )%val_ => this%domain_%mutator(  prop )
    this%accessors_( kTemperature )%val_ => this%domain_%accessor( prop )
    deallocate( prop )

    ! pressure
    prop => property_t( my_name, name = "pressure", units = "Pa",             &
                        applies_to = all_cells, data_type = kDouble,          &
                        default_value = 0.0_musica_dk )
    call this%domain_%register( prop )
    this%mutators_(  kPressure )%val_ => this%domain_%mutator(  prop )
    this%accessors_( kPressure )%val_ => this%domain_%accessor( prop )
    deallocate( prop )

    ! number density of air
    prop => property_t( my_name, name = "number density air",                 &
                        units = "mol m-3", applies_to = all_cells,            &
                        data_type = kDouble, default_value = 0.0_musica_dk )
    call this%domain_%register( prop )
    this%mutators_(  kNumberDensityAir )%val_ => this%domain_%mutator(  prop )
    this%accessors_( kNumberDensityAir )%val_ => this%domain_%accessor( prop )
    deallocate( prop )

  end subroutine register_standard_state_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register output variables
  subroutine register_output_variables( this )

    !> MusicBox core
    class(core_t), intent(inout) :: this

    call this%output_%register_output_variable( this%domain_,                 &
                                                "temperature",                & !- variable name
                                                "K",                          & !- units
                                                "ENV.temperature"  )            !- output name
    call this%output_%register_output_variable( this%domain_,                 &
                                                "pressure",                   & !- variable name
                                                "Pa",                         & !- units
                                                "ENV.pressure"     )            !- output name
    call this%output_%register_output_variable( this%domain_,                 &
                                                "number density air",         & !- variable name
                                                "mol m-3",                    & !- units
                                                "ENV.number_density_air" )      !- output name

  end subroutine register_output_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update environmental conditions for a new time step
  !!
  !! Updates diagnosed environmental conditions.
  !!
  subroutine update_environment( this, domain_state, cell )

    use musica_constants,              only : kUniversalGasConstant
    use musica_domain_state,           only : domain_state_t
    use musica_domain_iterator,        only : domain_iterator_t

    !> MusicBox core
    class(core_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Cell to update
    class(domain_iterator_t), intent(in) :: cell

    real(kind=musica_dk) :: t, p, n

    call domain_state%get( cell, this%accessors_( kTemperature )%val_, t )
    call domain_state%get( cell, this%accessors_( kPressure )%val_, p )

    ! calculate the number density of air [mol m-3]
    n = p / t / kUniversalGasConstant

    call domain_state%update( cell, this%mutators_( kNumberDensityAir )%val_, &
                              n )

  end subroutine update_environment

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Output the model state
  !!
  !! Outputs the model state when the simulation time corresponds to an
  !! output time
  subroutine output( this, state, simulation_time__s, force_output )

    use musica_domain_state,           only : domain_state_t

    !> MusicBox core
    class(core_t), intent(inout) :: this
    !> Model domain state
    class(domain_state_t), intent(in) :: state
    !> Current model simulation time [s]
    real(kind=musica_dk), intent(in) :: simulation_time__s
    !> Force output at this time step
    logical, intent(in), optional :: force_output

    logical :: l_force

    l_force = .false.
    if( present( force_output ) ) l_force = force_output

    if( simulation_time__s .ge. this%next_output_time__s_ .or. l_force ) then
      call this%output_%output( simulation_time__s,                           &
                                this%domain_,                                 &
                                state )
      this%next_output_time__s_ = this%next_output_time__s_ +                 &
                                  this%output_time_step__s_
    end if

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine finalize( this )

    !> MusicBox core
    type(core_t), intent(inout) :: this

    integer :: i

    if( associated( this%domain_ ) ) deallocate( this%domain_ )
    if( associated( this%evolving_conditions_ ) )                             &
        deallocate( this%evolving_conditions_ )
    if( associated( this%initial_conditions_ ) )                              &
        deallocate( this%initial_conditions_ )
    if( associated( this%components_) ) deallocate( this%components_ )
    if( associated( this%output_         ) ) deallocate( this%output_         )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Print the MusicBox model header
  subroutine print_header( )

    write(*,*)
    write(*,*) ",---.    ,---.  ___    _    .-'''-. .-./`)     _______    _______       ,-----.     _____     __"
    write(*,*) "|    \  /    |.'   |  | |  / _     \\ .-.')   /   __  \  \  ____  \   .'  .-,  '.   \   _\   /  /"
    write(*,*) "|  ,  \/  ,  ||   .'  | | (`' )/`--'/ `-' \  | ,_/  \__) | |    \ |  / ,-.|  \ _ \  .-./ ). /  '"
    write(*,*) "|  |\_   /|  |.'  '_  | |(_ o _).    `-'`'`,-./  )       | |____/ / ;  \  '_ /  | : \ '_ .') .'"
    write(*,*) "|  _( )_/ |  |'   ( \.-.| (_,_). '.  .---. \  '_ '`)     |   _ _ '. |  _`,/ \ _/  |(_ (_) _) '"
    write(*,*) "| (_ o _) |  |' (`. _` /|.---.  \  : |   |  > (_)  )  __ |  ( ' )  \: (  '\_/ \   ;  /    \   \"
    write(*,*) "|  (_,_)  |  || (_ (_) _)\    `-'  | |   | (  .  .-'_/  )| (_{;}_) | \ `'/  \  ) /   `-'`-'    \"
    write(*,*) "|  |      |  | \ /  . \ / \       /  |   |  `-'`-'     / |  (_,_)  /  '. \_/``'.'   /  /   \    \"
    write(*,*) "'--'      '--'  ``-'`-''   `-...-'   '---'    `._____.'  /_______.'     '-----'    '--'     '----'"
    write(*,*)

  end subroutine print_header

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_core
