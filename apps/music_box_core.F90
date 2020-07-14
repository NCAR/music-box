!> \file
!> The musica_core module

!> The core_t type and related functions
module music_box_core

  use musica_constants,                only : musica_ik, musica_dk
  use musica_domain,                   only : domain_t, domain_state_t,       &
                                              domain_state_mutator_ptr,       &
                                              domain_state_accessor_ptr

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
  contains
    !> Run the model
    procedure :: run
    !> Register standard state variables
    procedure, private :: register_standard_state_variables
    !> Get the current time step [s]
    procedure, private :: get_current_time_step__s
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
  integer, parameter :: kNumberOfStandardVariables = 2

  !> Temperature
  integer, parameter :: kTemperature = 1
  !> Pressuse
  integer, parameter :: kPressure = 2

  !> @}

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> MUSICA Core constructor
  !!
  !! Loads input data and initializes model components.
  function constructor( config_file_path ) result( new_obj )

    use musica_config,                 only : config_t
    use musica_domain_factory,         only : domain_builder
    use musica_string,                 only : string_t

    !> New MUSICA Core
    type(core_t) :: new_obj
    !> Path to the configuration file
    character(len=*), intent(in) :: config_file_path

    character(len=*), parameter :: my_name = "MUSICA core constructor"
    type(config_t) :: config, model_opts, domain_opts
    type(string_t) :: domain_type

    ! load configuration data

    call config%from_file( config_file_path )
    call config%get( "box model options", model_opts, my_name )

    ! build the domain

    call model_opts%get( "grid", domain_type, my_name )
    domain_opts = '{ "type" : "'//domain_type//'" }'
    new_obj%domain_ => domain_builder( domain_opts )

    ! register the accessors and mutators for the standard state variables

    call new_obj%register_standard_state_variables( )

    ! simulation time parameters

    call model_opts%get( "chemistry time step", "s",                          &
                         new_obj%chemistry_time_step__s_, my_name )
    call model_opts%get( "output time step", "s",                             &
                         new_obj%output_time_step__s_, my_name )
    call model_opts%get( "simulation length", "s",                            &
                         new_obj%simulation_length__s_, my_name )

    ! get a domain state

    new_obj%state_ => new_obj%domain_%new_state( )

    ! clean up

    call config%finalize( )
    call domain_opts%finalize( )
    call model_opts%finalize( )

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

    ! output initial conditions
    call this%output( sim_time__s )

    ! start simulation
    do while( sim_time__s .lt. this%simulation_length__s_ )

      ! determine the current time step
      time_step__s = this%get_current_time_step__s( sim_time__s )

      ! solve the system for the current time step
      write(*,*) "Solving chemistry at time ", sim_time__s, " s"

      ! iterate over cells in the domain
      call cell_iter%reset( )
      do while( cell_iter%next( ) )

        ! solve the system for the current time and cell
        write(*,*) "Solving domain cell"

      end do

      sim_time__s = sim_time__s + time_step__s

      ! output the model state
      call this%output( sim_time__s )

    end do

    ! clean up
    deallocate( cell_iter )

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

    this%mutators_( kTemperature )%val =>                                     &
      this%domain_%register_cell_state_variable( "temperature", "K", my_name )
    this%mutators_( kPressure    )%val =>                                     &
      this%domain_%register_cell_state_variable( "pressure",   "Pa", my_name )

    ! get accessors

    this%accessors_( kTemperature )%val =>                                    &
      this%domain_%cell_state_accessor( "temperature", "K", my_name )
    this%accessors_( kPressure    )%val =>                                    &
      this%domain_%cell_state_accessor( "pressure",   "Pa", my_name )

  end subroutine register_standard_state_variables

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

  !> Output the model state
  !!
  !! Outputs the model state when the simulation time corresponds to an
  !! output time
  subroutine output( this, simulation_time__s )

    !> MUSICA Core
    class(core_t), intent(inout) :: this
    !> Current model simulation time [s]
    real(kind=musica_dk), intent(in) :: simulation_time__s

    if( mod( simulation_time__s, this%output_time_step__s_ ) .eq. 0.0 ) then
      write(*,*) "Outputting model state at ", simulation_time__s, " s"
    end if

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine finalize( this )

    !> MUSICA Core
    type(core_t), intent(inout) :: this

    integer :: i

    write(*,*) "Finalizing core"

    if( associated( this%domain_ ) ) deallocate( this%domain_ )
    if( associated( this%state_  ) ) deallocate( this%state_  )
    if( allocated( this%mutators_ ) ) then
      do i = 1, size( this%mutators_ )
        if( associated( this%mutators_( i )%val ) )                           &
          deallocate( this%mutators_( i )%val )
      end do
    end if
    if( allocated( this%accessors_ ) ) then
      do i = 1, size( this%accessors_ )
        if( associated( this%accessors_( i )%val ) )                          &
          deallocate( this%accessors_( i )%val )
      end do
    end if

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_core
