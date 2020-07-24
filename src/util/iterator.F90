! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_iterator module

!> The abstract iterator_t type and related functions
module musica_iterator

  implicit none
  private

  public :: iterator_t

  !> An abstract iterator
  type, abstract :: iterator_t
  contains
    !> Advance the iterator
    procedure(next), deferred :: next
    !> Reset the iterator
    procedure(reset), deferred :: reset
  end type iterator_t

interface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the iterator
  !!
  !! Returns false if the end of the collection has been reached
  logical function next( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end function next

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Reset the iterator
  subroutine reset( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end subroutine reset

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

end module musica_iterator
