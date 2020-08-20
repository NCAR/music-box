! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_netcdf_updater module

!> The netcdf_updater_t type and related functions
module musica_netcdf_updater

  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain,                   only : domain_state_accessor_t,        &
                                              domain_state_mutator_t
  use musica_netcdf_variable,          only : netcdf_variable_t
  use netcdf

  implicit none
  private

  public :: netcdf_updater_t, netcdf_updater_ptr

  !> Max length of staged data array
  integer(kind=musica_ik), parameter :: kMaxStagedData = 100

  !> Updater for a paired MUSICA <-> NetCDF variable
  !!
  !! Staging data and functions for updating MUSICA state variables from input
  !! data and updating output files from the MUSICA state.
  !!
  type :: netcdf_updater_t
    private
    !> Mutator for the variable
    class(domain_state_mutator_t), pointer :: mutator_ => null( )
    !> Accessor for the variable
    class(domain_state_accessor_t), pointer :: accessor_ => null( )
    !> Variable information
    type(netcdf_variable_t) :: variable_
    !> Index of first staged data
    integer(kind=musica_ik) :: first_staged_index_ = 1
    !> Number of staged data
    integer(kind=musica_ik) :: number_staged_ = 0
    !> Staged data
    real(kind=musica_dk) :: staged_data_(kMaxStagedData) = -huge(1.0_musica_dk)
  contains
    !> Updates the state for a given index in the temporal dimension
    procedure :: update_state
    !> Prints the properties of the updater
    procedure :: print => do_print
    !> Updates the staged data
    procedure, private :: update_staged_data
    !> Finalize the updater
    final :: finalize
  end type netcdf_updater_t

  !> Constructor
  interface netcdf_updater_t
    module procedure :: constructor
  end interface netcdf_updater_t

  !> Pointer to netcdf_updater_t objects
  type :: netcdf_updater_ptr
    type(netcdf_updater_t), pointer :: val_
  end type netcdf_updater_ptr

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a MUSICA <-> NetCDF variable match
  function constructor( file, domain, variable ) result( new_obj )

    use musica_assert,                 only : die
    use musica_domain,                 only : domain_t
    use musica_netcdf_file,            only : netcdf_file_t
    use musica_netcdf_variable,        only : netcdf_variable_t
    use musica_string,                 only : string_t

    !> New MUSICA<->NetCDF variable match
    type(netcdf_updater_t), pointer :: new_obj
    !> NetCDF file
    class(netcdf_file_t), intent(in) :: file
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: variable

    character(len=*), parameter :: my_name = "NetCDF updater constructor"
    type(string_t) :: std_units, var_name

    allocate( new_obj )
    new_obj%variable_ = variable
    var_name = variable%musica_name( )
    std_units = domain%cell_state_units( var_name%to_char( ) )
    if( file%is_input( ) ) then
      new_obj%mutator_ => domain%cell_state_mutator( var_name%to_char( ),     & !- state variable name
                                                     std_units%to_char( ),    & !- MUSICA units
                                                     my_name )
    else
      call die( 386789282 )
    end if

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates a domain state for a given index in the temporal dimension
  subroutine update_state( this, file, index, iterator, state )

    use musica_assert,                 only : assert
    use musica_domain,                 only : domain_iterator_t,              &
                                              domain_state_t
    use musica_netcdf_file,            only : netcdf_file_t

    !> NetCDF updater
    class(netcdf_updater_t), intent(inout) :: this
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file
    !> Index in the temporal dimension to update from
    integer(kind=musica_ik), intent(in) :: index
    !> Domain state iterator
    class(domain_iterator_t), intent(inout) :: iterator
    !> Domain state to update
    class(domain_state_t), intent(inout) :: state

    if( index .lt. this%first_staged_index_ .or.                             &
        index .gt. ( this%first_staged_index_ + this%number_staged_ ) - 1 )  &
      call this%update_staged_data( file, index )
    call assert( 269276238, associated( this%mutator_ ) )
    call iterator%reset( )
    do while( iterator%next( ) )
      call state%update( iterator, this%mutator_,                             &
                    this%staged_data_( index - this%first_staged_index_ + 1 ) )
    end do

  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints the contents of the updater
  subroutine do_print( this )

    !> NetCDF updater
    class(netcdf_updater_t), intent(in) :: this

    call this%variable_%print( )

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the staged data to start from a given index
  subroutine update_staged_data( this, file, index )

    use musica_assert,                 only : assert
    use musica_netcdf_file,            only : netcdf_file_t

    !> NetCDF updater
    class(netcdf_updater_t), intent(inout) :: this
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file
    !> New starting index
    integer(kind=musica_ik), intent(in) :: index

    integer(kind=musica_ik) :: n_times

    n_times = min( kMaxStagedData,                                            &
                   this%variable_%time_dimension_size( ) - index + 1 )
    call file%check_open( )
    call assert( 382334001, index .gt. 0 .and. n_times .ge. 1 )
    this%staged_data_(:) = -huge( 1.0_musica_dk )
    call file%check_status( 142628652,                                        &
                            nf90_get_var( file%id( ), this%variable_%id( ),   &
                                          this%staged_data_,                  &
                                          start = (/ index /),                &
                                          count = (/ n_times /) ),            &
                            "Error staging variable data" )
    this%first_staged_index_ = index
    this%number_staged_      = n_times

  end subroutine update_staged_data

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize the NetCDF updater
  subroutine finalize( this )

    !> NetCDF updater
    type(netcdf_updater_t), intent(inout) :: this

    if( associated( this%mutator_  ) ) deallocate( this%mutator_  )
    if( associated( this%accessor_ ) ) deallocate( this%accessor_ )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_netcdf_updater
