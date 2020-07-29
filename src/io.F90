! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io module

!> The abstract io_t type and related functions
module musica_io

  implicit none
  private

  public :: io_t, get_file_unit, free_file_unit

  !> Maximum number of IO units
  integer, parameter :: kMaxFileUnits = 200
  !> Minimum unit number
  integer, parameter :: kMinFileUnit = 10
  !> Currently used file units
  logical, save :: units_used(kMaxFileUnits) = .false.

  !> An abstract input/output
  type, abstract :: io_t
  contains
    !> Auto-maps input/output variables to model state variables
    procedure(auto_map_variables), deferred :: auto_map_variables
    !> Registers a state variable for input/output
    procedure(register), deferred :: register
    !> Updates the model state with input data
    procedure(update_state), deferred :: update_state
    !> Outputs the current domain state
    procedure(output), deferred :: output
    !> Closes the output stream
    procedure(close), deferred :: close
  end type io_t

interface

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Auto-maps input/output variables to model state variables
  !!
  !! Extending types can determine how to map to model state variables, but
  !! \c io_t types should try to match by model state variable name and do
  !! standard unit conversions using \c convert_t objects.
  !!
  !! Any scaling, conversion, or interpolation for the variable should be
  !! set up by extending types when this function is called.
  !!
  subroutine auto_map_variables( this, domain )
    use musica_domain,                 only : domain_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
  end subroutine auto_map_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a state variable for input/output
  !!
  !! Any scaling, conversion, or interpolation for the variable should be
  !! set up by extending types when this function is called.
  !!
  subroutine register( this, domain, variable_name, units, io_name )
    use musica_domain,                 only : domain_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to register
    character(len=*), intent(in) :: variable_name
    !> Units used for intput/output data
    character(len=*), intent(in) :: units
    !> Optional custom name for input/output variable
    character(len=*), intent(in), optional :: io_name
  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the model state with input data
  !!
  !! Input data for the specified time (with any necessary interpolation)
  !! will be used to update domain state variables registered with the
  !! \c io_t type during intialization.
  !!
  subroutine update_state( this, time__s, domain, domain_state )
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state to update
    class(domain_state_t), intent(inout) :: domain_state
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

  !> Closes any input/output streams/files/servies/etc.
  subroutine close( this )
    import io_t
    !> Input/output
    class(io_t), intent(inout) :: this
  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

contains
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
