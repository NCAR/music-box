!> \file
!> The musica_core module

!> The core_t type and related functions
module music_box_core

  use musica_constants,                only : musica_ik, musica_dk

  implicit none
  private

  public :: core_t

  !> MUSICA core
  !!
  !! Top-level model object. The core manages model initialization, grids,
  !! science packages, output, and finalization.
  type :: core_t
    private
    !> Chemistry time step [s]
    real(kind=musica_dk) :: chemistry_time_step__s_
    !> Output time step [s]
    real(kind=musica_dk) :: output_time_step__s_
    !> Simulation length [s]
    real(kind=musica_dk) :: simulation_length__s_
  contains
    !> Run the model
    procedure :: run
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

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> MUSICA Core constructor
  !!
  !! Loads input data and initializes model components.
  function constructor( config_file_path ) result( new_obj )

    use musica_config,                 only : config_t

    !> New MUSICA Core
    type(core_t) :: new_obj
    !> Path to the configuration file
    character(len=*), intent(in) :: config_file_path

    character(len=*), parameter :: my_name = "MUSICA core constructor"
    type(config_t) :: config, model_opts

    ! load configuration data

    call config%from_file( config_file_path )
    call config%get( "box model options", model_opts, my_name )

    ! simulation time parameters

    call model_opts%get( "chemistry time step", "s",                          &
                         new_obj%chemistry_time_step__s_, my_name )
    call model_opts%get( "output time step", "s",                             &
                         new_obj%output_time_step__s_, my_name )
    call model_opts%get( "simulation length", "s",                            &
                         new_obj%simulation_length__s_, my_name )

    ! clean up

    call config%finalize( )
    call model_opts%finalize( )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Run the model
  subroutine run( this )

    !> MUSICA Core
    class(core_t), intent(inout) :: this

    ! Current model simulation time [s]
    real(kind=musica_dk) :: sim_time__s
    ! Current model simulation time step [s]
    real(kind=musica_dk) :: time_step__s

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

      sim_time__s = sim_time__s + time_step__s

      ! output the model state
      call this%output( sim_time__s )

    end do

  end subroutine run

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

    write(*,*) "Finalizing core"

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_core
