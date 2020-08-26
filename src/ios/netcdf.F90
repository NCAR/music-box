! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io_netcdf module

!> The io_netcdf_t type and related functions
module musica_io_netcdf

  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain,                   only : domain_iterator_t
  use musica_io,                       only : io_t
  use musica_netcdf_dimension,         only : netcdf_dimension_t
  use musica_netcdf_file,              only : netcdf_file_t
  use musica_netcdf_updater,           only : netcdf_updater_ptr
  use netcdf

  implicit none
  private

  public :: io_netcdf_t

  !> NetCDF file input/output
  !!
  !! Sets up a NetCDF file for input and/or output
  !!
  !! \todo add example for \c io_netcdf_t usage
  !!
  type, extends(io_t) :: io_netcdf_t
    private
    !> NetCDF file
    type(netcdf_file_t) :: file_
    !> Time dimension
    type(netcdf_dimension_t), pointer :: time_
    !> Last time index used
    integer(kind=musica_ik) :: last_time_index_ = 1
    !> Updaters for successfully paired NetCDF <-> MUSICA variables
    type(netcdf_updater_ptr), allocatable :: updaters_(:)
    !> Iterator over all domain cells
    class(domain_iterator_t), pointer :: iterator_ => null( )
  contains
    !> Registers a state variable for input/output
    procedure :: register
    !> Gets the times corresponding to entries (for input data) [s]
    procedure :: entry_times__s
    !> Updates the model state with input data
    procedure :: update_state
    !> Outputs the current domain state
    procedure :: output
    !> Prints the text file configuration information
    procedure :: print => do_print
    !> Closes the file stream
    procedure :: close
    !> Finalizes the output
    final :: finalize
    !> Loads input file variable names and units
    procedure, private :: load_input_variables
  end type io_netcdf_t

  !> Constructor
  interface io_netcdf_t
    module procedure :: constructor
  end interface io_netcdf_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a connection to a NetCDF input/output file
  !!
  !! At minimum, \c config must include a top-level key-value pair "intent",
  !! which can be any of: "input", "output", or "input/output". Currently,
  !! only input NetCDF files are supported.
  !!
  !! A "file name" is also required for files opened for input. This is
  !! optional for output files, with the default name being "output.nc".
  !!
  !! Input files require the model domain object for mapping between model
  !! domain and file variables.
  !!
  function constructor( config, domain ) result( new_obj )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_string,                 only : string_t

    !> New NetCDF file
    type(io_netcdf_t), pointer :: new_obj
    !> Configuration data
    class(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout), optional :: domain

    character(len=*), parameter :: my_name = 'NetCDF file constructor'
    type(string_t) :: temp_str
    logical :: found, is_input
    type(config_t) :: properties

    ! file intent
    is_input = .false.
    call config%get( "intent", temp_str, my_name )
    temp_str = temp_str%to_lower( )
    if( temp_str .eq. "input" ) then
      is_input = .true.
    else if( temp_str .eq. "output" ) then
      call die_msg( 447504298, "NetCDF output files are not yet supported" )
    else if( temp_str .eq. "input/output" ) then
      call die_msg( 328468407, "NetCDF input/output files are not supported" )
    else
      call die_msg( 165481344, "Invalid type specified for NetCDF file: "//   &
                    temp_str%to_char( ) )
    end if

    allocate( new_obj )

    ! load the variable names and units
    if( is_input ) then
      call config%get( "file name", temp_str, my_name )
      new_obj%file_ = netcdf_file_t( temp_str, is_input = .true. )
      if( present( domain ) ) then
        call config%get( "properties", properties, my_name, found = found )
        if( found ) then
          call new_obj%load_input_variables( domain, config )
          call properties%finalize( )
        else
          call new_obj%load_input_variables( domain )
        end if
      else
        call die_msg( 264651720, "Input files require the model domain "//    &
                                 "during initialization for mapping." )
      end if
    end if

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Regsiters a state variable for output
  subroutine register( this, domain, domain_variable_name, units,             &
      io_variable_name )

    use musica_assert,                 only : die_msg
    use musica_domain,                 only : domain_t

    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Model domain variable to register
    character(len=*), intent(in) :: domain_variable_name
    !> Units used in the file for this variable
    character(len=*), intent(in) :: units
    !> Optional custom name in file (if different from domain_variable_name)
    character(len=*), intent(in), optional :: io_variable_name

    call die_msg( 232443713, "NetCDF output is not yet supported." )

  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the times corresponding to entries (for input data) [s]
  !!
  !! These time include and adjustments specified in the configuration data
  function entry_times__s( this )

    !> Input data entry times [s]
    real(kind=musica_dk), allocatable :: entry_times__s(:)
    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this

    entry_times__s = this%time_%get_values( )

  end function entry_times__s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the model state with input data
  !!
  !! If no time is included, the first record is used to update the state
  subroutine update_state( this, domain, domain_state, time__s )

    use musica_assert,                 only : assert_msg
    use musica_domain,                 only : domain_t,                      &
                                              domain_state_t

    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Model domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in), optional :: time__s

    integer(kind=musica_ik) :: i_data, i_pair
    logical :: found

    call assert_msg( 141624450, this%file_%is_input( ), "Cannot update "//    &
                     "model state from non-input NetCDF file." )
    if( present( time__s ) ) then
      i_data = this%time_%get_index( time__s, is_exact = found,               &
                                     guess = this%last_time_index_ )
      if( .not. found ) return
    else
      i_data = 1
    end if
    if( .not. associated( this%iterator_ ) ) then
      this%iterator_ => domain%cell_iterator( )
    end if
    do i_pair = 1, size( this%updaters_ )
      call this%updaters_( i_pair )%val_%update_state( this%file_, i_data,    &
                                                 this%iterator_, domain_state )
    end do

  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Outputs the current domain state
  subroutine output( this, time__s, domain, domain_state )

    use musica_assert,                 only : die_msg
    use musica_domain,                 only : domain_t, domain_state_t

    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state

    call die_msg( 114404342, "Output to NetCDF files is not yet supported." )

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints the NetCDF file configuration information
  subroutine do_print( this )

    !> NetCDF file
    class(io_netcdf_t), intent(in) :: this

    integer(kind=musica_ik) :: i

    write(*,*) "***** NetCDF File Configuration *****"
    write(*,*) ""
    call this%file_%print( )
    write(*,*) ""
    call this%time_%print( )
    write(*,*) ""
    write(*,*) "---------------------"
    write(*,*) " State/File Updaters"
    write(*,*) "---------------------"
    if( allocated( this%updaters_ ) ) then
      do i = 1, size( this%updaters_ )
        call this%updaters_( i )%val_%print( )
      end do
    end if
    write(*,*) ""
    write(*,*) "***** End NetCDF File Configuration *****"

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Closes the NetCDF file
  subroutine close( this )

    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this

    call this%file_%close( )

  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes the NetCDF file object, including closing the file if needed.
  subroutine finalize( this )

    !> NetCDF file
    type(io_netcdf_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_var

    call this%file_%close( )
    if( associated( this%iterator_ ) ) deallocate( this%iterator_ )
    if( allocated( this%updaters_ ) ) then
      do i_var = 1, size( this%updaters_ )
        if( associated( this%updaters_( i_var )%val_ ) )                      &
          deallocate( this%updaters_( i_var )%val_ )
      end do
      deallocate( this%updaters_ )
    end if
    if( associated( this%time_ ) ) deallocate( this%time_ )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Loads input file variable names and units and id
  subroutine load_input_variables( this, domain, config )

    use musica_assert,                 only : assert, assert_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_netcdf_updater,         only : netcdf_updater_t
    use musica_netcdf_variable,        only : netcdf_variable_ptr,            &
                                              netcdf_variable_t
    use musica_string,                 only : string_t, to_char

    !> NetCDF file
    class(io_netcdf_t), intent(inout) :: this
    !> MUSICA domain
    class(domain_t), intent(inout) :: domain
    !> NetCDF configuration
    type(config_t), intent(inout), optional :: config

    character(len=*), parameter :: my_name = "NetCDF load input variables"
    integer(kind=musica_ik) :: n_dimensions, n_variables, n_attributes
    integer(kind=musica_ik) :: time_varid, n_match, i_match, i_var
    character(len=NF90_MAX_NAME) :: name, units
    type(string_t) :: att_name, file_name
    logical :: found
    type(netcdf_variable_ptr), allocatable :: vars(:)

    call this%file_%check_open( )
    file_name = this%file_%name( )
    call this%file_%check_status( 639211977,                                  &
                                  nf90_inquire( this%file_%id( ),             &
                                                nDimensions = n_dimensions,   &
                                                nVariables = n_variables ),   &
                       "Error getting dimension and variable information "//  &
                       "for NetCDF file '"//file_name%to_char( )//"'" )
    call assert_msg( 938882534, n_dimensions .eq. 1,                          &
                     "NetCDF files are currently only set up for one "//      &
                     "dimension of time. File '"//file_name%to_char( )//&
                     "' has "//to_char( n_dimensions )//" dimensions" )
    allocate( vars( n_variables ) )
    n_match = 0
    do i_var = 1, n_variables
    vars( i_var )%val_ => netcdf_variable_t( domain, this%file_, i_var,       &
                                             config )
      if( associated( vars( i_var )%val_ ) ) then
        if( vars( i_var )%val_%name( ) .ne. "time" ) n_match = n_match + 1
      end if
    end do
    allocate( this%updaters_( n_match ) )
    i_match = 0
    do i_var = 1, n_variables
      if( associated( vars( i_var )%val_ ) ) then
        if( vars( i_var )%val_%musica_name( ) .eq. "time" ) then
          this%time_ => netcdf_dimension_t( this%file_, vars( i_var )%val_ )
          cycle
        end if
        i_match = i_match + 1
        this%updaters_( i_match )%val_ =>                                     &
            netcdf_updater_t( this%file_, domain, vars( i_var )%val_ )
      end if
    end do
    do i_var = 1, n_variables
      if( associated( vars( i_var )%val_ ) ) deallocate( vars( i_var )%val_ )
    end do
    call assert( 177448848, i_match .eq. n_match )
    deallocate( vars )

  end subroutine load_input_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io_netcdf
