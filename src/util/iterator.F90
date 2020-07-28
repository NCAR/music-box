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
  !!
  !! Extending types should provide a constructor that returns a pointer to a
  !! iterator_t that references a newly allocated iterator of the extending
  !! type. The iterator must be in the state it would be in after a call to
  !! \c reset.
  !!
  !! Example usage:
  !! \code{f90}
  !!   use musica_foo_iterator,             only : foo_iterator_t
  !!   use musica_iterator,                 only : iterator_t
  !!
  !!   class(iterator), pointer :: my_iterator
  !!
  !!   my_iterator => foo_iterator_t( )    ! can accept arguments if necessary
  !!   do while( my_iterator%next( ) )
  !!     some_function( my_iterator, ... ) ! use a function that uses a foo_iterator_t
  !!   end do
  !!   call my_iterator%reset( )           ! reset the iterator
  !!   do while( my_iterator%next( ) )
  !!     some_other_function( my_iterator, ... )
  !!   end do
  !!   deallocate( my_iterator )
  !! \endcode
  !!
  type, abstract :: iterator_t
  contains
    !> Advances the iterator
    procedure(next), deferred :: next
    !> Resets the iterator to the beginning of the collection
    procedure(reset), deferred :: reset
  end type iterator_t

interface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advances the iterator
  !!
  !! Returns true if the iterator was advanced to the next record, returns
  !! false if the end of the collection has been reached.
  logical function next( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end function next

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Resets the iterator to the beginning of the collection
  subroutine reset( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end subroutine reset

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

end module musica_iterator
