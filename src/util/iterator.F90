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
    procedure(next_default), deferred, private :: next_default
    generic :: next => next_default
    !> Reset the iterator
    procedure(reset_default), deferred, private  :: reset_default
    procedure :: reset => reset_default
  end type iterator_t

interface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the iterator
  !!
  !! Returns false if the end of the collection has been reached
  logical function next_default( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end function next_default

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Reset the iterator
  subroutine reset_default( this )
    import iterator_t
    !> Iterator
    class(iterator_t), intent(inout) :: this
  end subroutine reset_default

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

end module musica_iterator
