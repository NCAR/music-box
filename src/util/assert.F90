! Portions Copyright (C) 2005-2016 Nicole Riemer and Matthew West
! Licensed under the GNU General Public License version 2 or (at your
! option) any later version. See the file COPYING for details.
!
! Portions Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_assert module.

!> Assertion functions
module musica_assert

  implicit none

  !> Error output id
  integer, parameter :: kErrorId = 0

  interface almost_equal
    module procedure almost_equal_real
    module procedure almost_equal_double
  end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Asserts condition to be true or fails with provided message
  subroutine assert_msg( code, condition, error_message )

    !> Unique code for the assertion
    integer, intent(in) :: code
    !> Condition to evaluate
    logical, intent(in) :: condition
    !> Message to display on failure
    character(len=*), intent(in) :: error_message

    character(len=50) :: str_code

    if( .not. condition ) then
      write(str_code,'(i30)') code
      write(kErrorId,*) "ERROR (MusicBox-"//trim( adjustl( str_code ) )//"): "&
                        //error_message
      stop 3
    end if

  end subroutine assert_msg

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Asserts condition to be true or fails
  subroutine assert( code, condition )

    !> Unique code for the assertion
    integer, intent(in) :: code
    !> Condition to evaluate
    logical, intent(in) :: condition

    call assert_msg( code, condition, 'assertion failed' )

  end subroutine assert

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Asserts condition to be true or prints a provided warning message
  subroutine assert_warn_msg( code, condition, warning_message )

    !> Unique code for the assertion
    integer, intent(in) :: code
    !> Condition to evaluate
    logical, intent(in) :: condition
    !> Message to display on failure
    character(len=*), intent(in) :: warning_message

    character(len=50) :: str_code

    if( .not. condition ) then
      write(str_code,'(i30)') code
      write(kErrorId,*) "WARNING (MusicBox-"//trim( adjustl( str_code ) )//   &
                        "): "//warning_message
    end if

  end subroutine assert_warn_msg

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Errors immediately and prints a provided message
  subroutine die_msg( code, error_message )

    !> Unique code for the failure
    integer, intent(in) :: code
    !> Message to display with failure
    character(len=*), intent(in) :: error_message

    call assert_msg( code, .false., error_message )

  end subroutine die_msg

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Errors immediately
  subroutine die( code )

    !> Unique code for the failure
    integer, intent(in) :: code

    call die_msg( code, "Internal error" )

  end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines whether two real numbers are equal within a provided or
  !! standard tolerance
  logical function almost_equal_real( a, b, relative_tolerance,               &
      absolute_tolerance ) result( almost_equal )

    use musica_constants,              only : musica_rk

    !> First number to compare
    real(kind=musica_rk), intent(in) :: a
    !> Second number to compare
    real(kind=musica_rk), intent(in) :: b
    !> Relative tolerance
    real(kind=musica_rk), intent(in), optional :: relative_tolerance
    !> Absolute tolerance
    real(kind=musica_rk), intent(in), optional :: absolute_tolerance

    real(kind=musica_rk) :: rel_tol, abs_tol

    rel_tol = 1.0e-10
    abs_tol = 1.0e-30
    if( present( relative_tolerance ) ) rel_tol = relative_tolerance
    if( present( absolute_tolerance ) ) abs_tol = absolute_tolerance

    almost_equal = .false.
    if( a .eq. b ) then
      almost_equal = .true.
    else
      if( abs( a - b ) / ( abs( a ) + abs( b ) ) .lt. rel_tol ) then
        almost_equal = .true.
      else if( abs( a - b ) .le. abs_tol ) then
        almost_equal = .true.
      end if
    end if

  end function almost_equal_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines whether two real numbers are equal within a provided or
  !! standard tolerance
  logical function almost_equal_double( a, b, relative_tolerance,             &
      absolute_tolerance ) result( almost_equal )

    use musica_constants,              only : musica_dk

    !> First number to compare
    real(kind=musica_dk), intent(in) :: a
    !> Second number to compare
    real(kind=musica_dk), intent(in) :: b
    !> Relative tolerance
    real(kind=musica_dk), intent(in), optional :: relative_tolerance
    !> Absolute tolerance
    real(kind=musica_dk), intent(in), optional :: absolute_tolerance

    real(kind=musica_dk) :: rel_tol, abs_tol

    rel_tol = 1.0d-10
    abs_tol = 1.0d-30
    if( present( relative_tolerance ) ) rel_tol = relative_tolerance
    if( present( absolute_tolerance ) ) abs_tol = absolute_tolerance

    almost_equal = .false.
    if( a .eq. b ) then
      almost_equal = .true.
    else
      if( abs( a - b ) / ( abs( a ) + abs( b ) ) .lt. rel_tol ) then
        almost_equal = .true.
      else if( abs( a - b ) .le. abs_tol ) then
        almost_equal = .true.
      end if
    end if

  end function almost_equal_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_assert
