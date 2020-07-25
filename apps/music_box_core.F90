! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_core module

!> The core_t type and related functions
module music_box_core

  use micm_core,                       only : chemistry_core_t => core_t
  use musica_constants,                only : musica_ik, musica_dk
  use musica_domain,                   only : domain_t, domain_state_t,       &
                                              domain_state_mutator_ptr,       &
                                              domain_state_accessor_ptr
  use musica_output,                   only : output_t

  implicit none
  private

  public :: core_t

  !> MUSICA core
  !!
  !! Top-level model object. The core manages model initialization, grids,
  !! science packages, output, and finalization.
  type :: core_t
    private
    !> Model domain
    class(domain_t), pointer :: domain_ => null( )
    !> Chemistry time step [s]
    real(kind=musica_dk) :: chemistry_time_step__s_
    !> Output time step [s]
    real(kind=musica_dk) :: output_time_step__s_
    !> Simulation length [s]
    real(kind=musica_dk) :: simulation_length__s_
    !> Domain state
    class(domain_state_t), pointer :: state_ => null( )
    !> Standard state variable mutators
    type(domain_state_mutator_ptr), allocatable :: mutators_(:)
    !> Standard state variable accessor
    type(domain_state_accessor_ptr), allocatable :: accessors_(:)
    !> Chemistry core
    class(chemistry_core_t), pointer :: chemistry_core_ => null( )
    !> Output stream
    class(output_t), pointer :: output_ => null( )
  contains
    !> Run the model
    procedure :: run
    !> Register standard state variables
    procedure, private :: register_standard_state_variables
    !> Register output variables
    procedure, private :: register_output_variables
    !> Get the current time step [s]
    procedure, private :: get_current_time_step__s
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

  !> MUSICA Core constructor
  !!
  !! Loads input data and initializes model components.
  function constructor( config_file_path ) result( new_obj )

    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_iterator_t
    use musica_domain_factory,         only : domain_builder
    use musica_initial_conditions,     only : set_initial_conditions
    use musica_output_factory,         only : output_builder
    use musica_string,                 only : string_t

    !> New MUSICA Core
    type(core_t) :: new_obj
    !> Path to the configuration file
    character(len=*), intent(in) :: config_file_path

    character(len=*), parameter :: my_name = "MUSICA core constructor"
    type(config_t) :: config, model_opts, domain_opts, output_opts, chem_opts
    type(string_t) :: domain_type
    logical :: found
    class(domain_iterator_t), pointer :: cell_iter

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
    if( .not. found ) output_opts = '{ "format" : "CSV" }'
    new_obj%output_ => output_builder( output_opts )
    call new_obj%register_output_variables( )

    ! simulation time parameters
    call model_opts%get( "chemistry time step", "s",                          &
                         new_obj%chemistry_time_step__s_, my_name )
    call model_opts%get( "output time step", "s",                             &
                         new_obj%output_time_step__s_, my_name )
    call model_opts%get( "simulation length", "s",                            &
                         new_obj%simulation_length__s_, my_name )

    ! initialize the chemistry module
    call config%get( "chemistry", chem_opts, my_name )
    call chem_opts%add( "chemistry time step", "s",                           &
                        new_obj%chemistry_time_step__s_, my_name )
    new_obj%chemistry_core_ => chemistry_core_t( chem_opts, new_obj%domain_,  &
                                                 new_obj%output_ )

    ! get a domain state
    new_obj%state_ => new_obj%domain_%new_state( )

    ! set the initial conditions
    call set_initial_conditions( config, new_obj%domain_, new_obj%state_ )
    cell_iter => new_obj%domain_%cell_iterator( )
    do while( cell_iter%next( ) )
      call new_obj%update_environment( new_obj%state_, cell_iter )
    end do

    ! output the registered domain state variables
    call new_obj%domain_%output_registry( )

    ! clean up
    call config%finalize( )
    call domain_opts%finalize( )
    call model_opts%finalize( )
    call output_opts%finalize( )
    call chem_opts%finalize( )
    deallocate( cell_iter )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Run the model
  subroutine run( this )

    use musica_domain,                 only : domain_iterator_t

    !> MUSICA Core
    class(core_t), intent(inout) :: this

    ! Current model simulation time [s]
    real(kind=musica_dk) :: sim_time__s
    ! Current model simulation time step [s]
    real(kind=musica_dk) :: time_step__s

    ! domain iterator over every cell
    class(domain_iterator_t), pointer :: cell_iter

    ! set up the domain iterators
    cell_iter => this%domain_%cell_iterator( )

    ! reset to initial conditions
    sim_time__s = 0.0d0

    ! start simulation
    do while( sim_time__s .lt. this%simulation_length__s_ )

      ! output initial conditions for this time step
      call this%output( sim_time__s )

      ! determine the current time step
      time_step__s = this%get_current_time_step__s( sim_time__s )

      ! iterate over cells in the domain
      call cell_iter%reset( )
      do while( cell_iter%next( ) )

        ! update environmental conditions
        call this%update_environment( this%state_, cell_iter )

        ! solve the system for the current time and cell
        call this%chemistry_core_%solve( this%state_, cell_iter,              &
                                         sim_time__s, time_step__s )

      end do

      sim_time__s = sim_time__s + time_step__s

    end do

    ! output the final model state
    call this%output( sim_time__s )

    ! clean up
    deallocate( cell_iter )

    write(*,*) ""
    write(*,*) "MusicBox simulation complete!"

  end subroutine run

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register the standard state variable accessors and mutators with the
  !! domain.
  subroutine register_standard_state_variables( this )

    use musica_assert,                 only : assert

    !> MUSICA Core
    class(core_t), intent(inout) :: this

    character(len=*), parameter :: my_name = "MUSICA core registrar"

    call assert( 943402309, associated( this%domain_ ) )

    allocate( this%accessors_( kNumberOfStandardVariables ) )
    allocate( this%mutators_(  kNumberOfStandardVariables ) )

    ! register variables and get mutators

    ! temperature
    this%mutators_(  kTemperature      )%val_ =>                              &
      this%domain_%register_cell_state_variable( "temperature",               & !- variable name
                                                 "K",                         & !- units
                                                 298.15d0,                    & !- default value
                                                 my_name )
    this%accessors_( kTemperature      )%val_ =>                              &
      this%domain_%cell_state_accessor( "temperature", "K", my_name )

    ! pressure
    this%mutators_( kPressure          )%val_ =>                              &
      this%domain_%register_cell_state_variable( "pressure",                  & !- variable name
                                                 "Pa",                        & !- units
                                                 101325.0d0,                  & !- default value
                                                 my_name )
    this%accessors_( kPressure         )%val_ =>                              &
      this%domain_%cell_state_accessor( "pressure", "Pa", my_name )

    ! number density of air
    this%mutators_( kNumberDensityAir  )%val_ =>                              &
      this%domain_%register_cell_state_variable( "number density air",        & !- variable name
                                                 "mol m-3",                   & !- units
                                                 0.0d0,                       & !- default value
                                                 my_name )
    this%accessors_( kNumberDensityAir )%val_ =>                              &
      this%domain_%cell_state_accessor( "number density air", "mol m-3",      &
                                        my_name )

  end subroutine register_standard_state_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register output variables
  subroutine register_output_variables( this )

    !> MUSICA Core
    class(core_t), intent(inout) :: this

    call this%output_%register( this%domain_,                                 &
                                "temperature",                                & !- variable name
                                "K",                                          & !- units
                                "ENV.temperature"  )                            !- output name
    call this%output_%register( this%domain_,                                 &
                                "pressure",                                   & !- variable name
                                "Pa",                                         & !- units
                                "ENV.pressure"     )                            !- output name
    call this%output_%register( this%domain_,                                 &
                                "number density air",                         & !- variable name
                                "mol m-3",                                    & !- units
                                "ENV.number_density_air" )                      !- output name

  end subroutine register_output_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the current time step [s]
  function get_current_time_step__s( this, simulation_time__s )               &
      result( time_step )

    !> Calculated time step [s]
    real(kind=musica_dk) :: time_step
    !> MUSICA Core
    class(core_t), intent(in) :: this
    !> Current model simulation time [s]
    real(kind=musica_dk), intent(in) :: simulation_time__s

    real(kind=musica_dk) :: tmp_step

    ! chemistry
    time_step = this%chemistry_time_step__s_ -                                &
                mod( simulation_time__s, this%chemistry_time_step__s_ )

    ! output
    tmp_step  = this%output_time_step__s_ -                                   &
                mod( simulation_time__s, this%output_time_step__s_ )
    if( tmp_step .lt. time_step ) time_step = tmp_step

    ! total simulation time
    tmp_step  = this%simulation_length__s_ - simulation_time__s
    if( tmp_step .lt. time_step ) time_step = tmp_step

  end function get_current_time_step__s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update environmental conditions for a new time step
  subroutine update_environment( this, domain_state, cell )

    use musica_constants,              only : kUniversalGasConstant
    use musica_domain,                 only : domain_state_t,                 &
                                              domain_iterator_t

    !> MUSICA Core
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
  subroutine output( this, simulation_time__s )

    !> MUSICA Core
    class(core_t), intent(inout) :: this
    !> Current model simulation time [s]
    real(kind=musica_dk), intent(in) :: simulation_time__s

    if( mod( simulation_time__s, this%output_time_step__s_ ) .eq. 0.0 .or.    &
        simulation_time__s .ge. this%simulation_length__s_ ) then
      call this%output_%output( simulation_time__s,                           &
                                this%domain_,                                 &
                                this%state_ )
    end if

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine finalize( this )

    !> MUSICA Core
    type(core_t), intent(inout) :: this

    integer :: i

    if( associated( this%domain_ ) ) deallocate( this%domain_ )
    if( associated( this%state_  ) ) deallocate( this%state_  )
    if( allocated( this%mutators_ ) ) then
      do i = 1, size( this%mutators_ )
        if( associated( this%mutators_( i )%val_ ) )                          &
          deallocate( this%mutators_( i )%val_ )
      end do
    end if
    if( allocated( this%accessors_ ) ) then
      do i = 1, size( this%accessors_ )
        if( associated( this%accessors_( i )%val_ ) )                         &
          deallocate( this%accessors_( i )%val_ )
      end do
    end if
    if( associated( this%chemistry_core_ ) ) deallocate( this%chemistry_core_ )
    if( associated( this%output_         ) ) deallocate( this%output_ )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Print the MusicBox model header
  subroutine print_header( )

    write(*,*) ""
    write(*,*) ",---.    ,---.  ___    _    .-'''-. .-./`)     _______    _______       ,-----.     _____     __   "
    write(*,*) "|    \  /    |.'   |  | |  / _     \\ .-.')   /   __  \  \  ____  \   .'  .-,  '.   \   _\   /  /  "
    write(*,*) "|  ,  \/  ,  ||   .'  | | (`' )/`--'/ `-' \  | ,_/  \__) | |    \ |  / ,-.|  \ _ \  .-./ ). /  '   "
    write(*,*) "|  |\_   /|  |.'  '_  | |(_ o _).    `-'`'`,-./  )       | |____/ / ;  \  '_ /  | : \ '_ .') .'    "
    write(*,*) "|  _( )_/ |  |'   ( \.-.| (_,_). '.  .---. \  '_ '`)     |   _ _ '. |  _`,/ \ _/  |(_ (_) _) '     "
    write(*,*) "| (_ o _) |  |' (`. _` /|.---.  \  : |   |  > (_)  )  __ |  ( ' )  \: (  '\_/ \   ;  /    \   \    "
    write(*,*) "|  (_,_)  |  || (_ (_) _)\    `-'  | |   | (  .  .-'_/  )| (_{;}_) | \ `'/  \  ) /   `-'`-'    \   "
    write(*,*) "|  |      |  | \ /  . \ / \       /  |   |  `-'`-'     / |  (_,_)  /  '. \_/``'.'   /  /   \    \  "
    write(*,*) "'--'      '--'  ``-'`-''   `-...-'   '---'    `._____.'  /_______.'     '-----'    '--'     '----' "
    write(*,*) ""

  end subroutine print_header

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_core
