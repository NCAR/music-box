! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io module

!> The abstract io_t type and related functions
module musica_io

  implicit none
  private

  public :: io_t, io_ptr, get_file_unit, free_file_unit

  !> Maximum number of IO units
  integer, parameter :: kMaxFileUnits = 200
  !> Minimum unit number
  integer, parameter :: kMinFileUnit = 10
  !> Currently used file units
  logical, save :: units_used(kMaxFileUnits) = .false.

  !> An abstract input/output
  type, abstract :: io_t
  contains
    !> Registers a state variable for output
    procedure(register), deferred :: register
    !> Get the times corresponding to entries (for input data) [s]
    procedure(entry_times__s), deferred :: entry_times__s
    !> Updates the model state with input data
    procedure(update_state), deferred :: update_state
    !> Outputs the current domain state
    procedure(output), deferred :: output
    !> Print the input/output configuration information
    procedure(do_print), deferred :: print
    !> Closes the output stream
    procedure(close), deferred :: close
  end type io_t

  !> Input/output pointer
  type :: io_ptr
    class(io_t), pointer :: val_ => null( )
  contains
    final :: io_ptr_finalize
  end type io_ptr

interface

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a state variable for input/output
  !!
  !! Any scaling, conversion, or interpolation for the variable should be
  !! set up by extending types when this function is called.
  !!
  subroutine register( this, domain, domain_variable_name, units,             &
      io_variable_name )
    use musica_domain,                 only : domain_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to register
    character(len=*), intent(in) :: domain_variable_name
    !> Units used for intput/output data
    character(len=*), intent(in) :: units
    !> Optional custom name for input/output variable
    character(len=*), intent(in), optional :: io_variable_name
  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the times corresponding to entries (for input data) [s]
  function entry_times__s( this )
    use musica_constants,              only : musica_dk
    import io_t
    !> Entry times [s]
    real(kind=musica_dk), allocatable :: entry_times__s(:)
    !> Input/output
    class(io_t), intent(inout) :: this
  end function entry_times__s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the model state with input data
  !!
  !! If a time is included, input data for the specified time (with any
  !! necessary interpolation) will be used to update domain state variables
  !! registered with the \c io_t type during intialization.
  !!
  !! If no time is provided the first entry in the input data will be used
  !! to update the domain state (used for initial conditions).
  !!
  subroutine update_state( this, domain, domain_state, time__s )
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state to update
    class(domain_state_t), intent(inout) :: domain_state
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in), optional :: time__s
  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Outputs the current domain state
  !!
  !! Domain state variables registered with the \c io_t type during
  !! initialization will be output for the current simulation time.
  !!
  subroutine output( this, time__s, domain, domain_state )
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state
  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Print the input/output configuration information
  subroutine do_print( this )
    import io_t
    !> Input/output
    class(io_t), intent(in) :: this
  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Closes any input/output streams/files/services/etc.
  subroutine close( this )
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

contains
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize an input/output pointer
  subroutine io_ptr_finalize( this )

    !> Input/output pointer
    type(io_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine io_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets an unused file unit
  integer function get_file_unit( )

    use musica_assert,                 only : die_msg

    integer :: i
    logical :: found

    found = .false.
    do i = 1, kMaxFileUnits
      if( .not. units_used( i ) ) then
        found = .true.
        exit
      end if
    end do
    if( .not. found ) then
      call die_msg( 895680497, "Maximum number of open file units reached" )
    end if
    units_used( i ) = .true.
    get_file_unit = i + kMinFileUnit

  end function get_file_unit

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Frees a file unit
  subroutine free_file_unit( unit )

    !> File unit to free
    integer, intent(in) :: unit

    units_used( unit ) = .false.

  end subroutine free_file_unit

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io
