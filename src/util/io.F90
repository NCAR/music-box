! Portions copyright (C) 2005-2016 Nicole Riemer and Matthew West
! Licensed under the GNU General Public License version 2 or (at your
! option) any later version. See the file COPYING for details.
!
! Portions Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io module

!> Utility IO functions
module musica_io

  implicit none
  private

  public :: get_file_unit, free_file_unit

  !> Maximum number of IO units
  integer, parameter :: kMaxFileUnits = 200
  !> Minimum unit number
  integer, parameter :: kMinFileUnit = 10
  !> Currently used file units
  logical, save :: units_used(kMaxFileUnits) = .false.

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an unused file unit
  integer function get_file_unit( )

    use musica_assert,                 only : die_msg

    integer :: i
    logical :: found

    found = .false.
    do i = 1, kMaxFileUnits
      if( .not. units_used(i) ) then
        found = .true.
        exit
      end if
    end do
    if( .not. found ) then
      call die_msg( 895680497, "Maximum number of open file units reached" )
    end if
    units_used(i) = .true.
    get_file_unit = i + kMinFileUnit

  end function get_file_unit

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Free a file unit
  subroutine free_file_unit( unit )

    !> File unit to free
    integer, intent(in) :: unit

    units_used( unit ) = .false.

  end subroutine free_file_unit

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io
