! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_array module

!> Functions for working with allocatable arrays
module musica_array

  use musica_constants,                only : musica_ik, musica_rk, musica_dk

  implicit none
  private

  public :: add_to_array, find_string_in_array, find_string_in_split_array,   &
            merge_series

  !> Add to array interface
  interface add_to_array
    module procedure :: add_char_to_array
    module procedure :: add_string_to_array
    module procedure :: add_integer_to_array
    module procedure :: add_logical_to_array
    module procedure :: add_real_to_array
    module procedure :: add_double_to_array
  end interface add_to_array

  ! Find a string in an array of strings
  interface find_string_in_array
    module procedure :: find_string_in_array_string
    module procedure :: find_string_in_array_char
  end interface find_string_in_array

  ! Find a string in an array of split strings
  interface find_string_in_split_array
    module procedure :: find_string_in_split_array_string
    module procedure :: find_string_in_split_array_char
  end interface find_string_in_split_array

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a string to an array of strings
  subroutine add_char_to_array( array, new_string )

    use musica_assert,                 only : assert
    use musica_string,                 only : string_t

    !> Array to add to
    type(string_t), allocatable, intent(inout) :: array(:)
    !> String to add to array
    character(len=*), intent(in) :: new_string

    type(string_t), allocatable :: temp_strings(:)

    ! this could be made more efficient if necessary

    call assert( 229830677, allocated( array ) )
    allocate( temp_strings( size( array ) ) )
    temp_strings(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_strings ) + 1 ) )
    array( :size( temp_strings ) ) = temp_strings(:)
    array( size( array ) ) = trim( new_string )

  end subroutine add_char_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a string to an array of strings
  subroutine add_string_to_array( array, new_string )

    use musica_assert,                 only : assert
    use musica_string,                 only : string_t

    !> Array to add to
    type(string_t), allocatable, intent(inout) :: array(:)
    !> String to add to array
    type(string_t), intent(in) :: new_string

    call add_char_to_array( array, new_string%to_char( ) )

  end subroutine add_string_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a integer to an array of integers
  subroutine add_integer_to_array( array, new_integer )

    use musica_assert,                 only : assert

    !> Array to add to
    integer, allocatable, intent(inout) :: array(:)
    !> Logical to add to array
    integer, intent(in) :: new_integer

    integer, allocatable :: temp_integers(:)

    ! this could be make more efficient if necessary

    call assert( 440827023, allocated( array ) )
    allocate( temp_integers( size( array ) ) )
    temp_integers(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_integers ) + 1 ) )
    array( :size( temp_integers ) ) = temp_integers(:)
    array( size( array ) ) = new_integer

  end subroutine add_integer_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a logical to an array of logicals
  subroutine add_logical_to_array( array, new_logical )

    use musica_assert,                 only : assert

    !> Array to add to
    logical, allocatable, intent(inout) :: array(:)
    !> Logical to add to array
    logical, intent(in) :: new_logical

    logical, allocatable :: temp_logicals(:)

    ! this could be make more efficient if necessary

    call assert( 217010450, allocated( array ) )
    allocate( temp_logicals( size( array ) ) )
    temp_logicals(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_logicals ) + 1 ) )
    array( :size( temp_logicals ) ) = temp_logicals(:)
    array( size( array ) ) = new_logical

  end subroutine add_logical_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a real to an array of reals
  subroutine add_real_to_array( array, new_real )

    use musica_assert,                 only : assert

    !> Array to add to
    real(kind=musica_rk), allocatable, intent(inout) :: array(:)
    !> Real number to add to array
    real(kind=musica_rk), intent(in) :: new_real

    real(kind=musica_rk), allocatable :: temp_reals(:)

    ! this could be made more efficient if necessary

    call assert( 626692375, allocated( array ) )
    allocate( temp_reals( size( array ) ) )
    temp_reals(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_reals ) + 1 ) )
    array( :size( temp_reals ) ) = temp_reals(:)
    array( size( array ) ) = new_real

  end subroutine add_real_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds a double to an array of doubles
  subroutine add_double_to_array( array, new_double )

    use musica_assert,                 only : assert

    !> Array to add to
    real(kind=musica_dk), allocatable, intent(inout) :: array(:)
    !> Real number to add to array
    real(kind=musica_dk), intent(in) :: new_double

    real(kind=musica_dk), allocatable :: temp_doubles(:)

    ! this could be made more efficient if necessary

    call assert( 153539762, allocated( array ) )
    allocate( temp_doubles( size( array ) ) )
    temp_doubles(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_doubles ) + 1 ) )
    array( :size( temp_doubles ) ) = temp_doubles(:)
    array( size( array ) ) = new_double

  end subroutine add_double_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finds a string in a string array (case insensitive by default)
  logical function find_string_in_array_char( array, string, id,              &
      case_sensitive )

    use musica_string,                 only : string_t

    !> Array to search
    type(string_t), intent(in) :: array(:)
    !> String to search for
    character(len=*), intent(in) :: string
    !> Index of located string
    integer(kind=musica_ik), intent(out) :: id
    !> Do a case sensitive search
    logical, intent(in), optional :: case_sensitive

    type(string_t) :: temp_string, array_string
    integer :: i_str
    logical :: is_case_sensitive

    is_case_sensitive = .false.
    if( present( case_sensitive ) ) then
      is_case_sensitive = case_sensitive
    end if
    id = 0
    find_string_in_array_char = .false.
    temp_string = trim( string )
    if( .not. is_case_sensitive ) temp_string = temp_string%to_lower( )
    do i_str = 1, size( array )
      array_string = array( i_str )
      if( .not. is_case_sensitive ) array_string = array_string%to_lower( )
      if( temp_string .eq. array_string ) then
        id = i_str
        find_string_in_array_char = .true.
        exit
      end if
    end do

  end function find_string_in_array_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finds a string in an array ( case insensitive by default)
  logical function find_string_in_array_string( array, string, id,            &
      case_sensitive )

    use musica_string,                 only : string_t

    !> Array to search
    type(string_t), intent(in) :: array(:)
    !> String to search for
    type(string_t), intent(in) :: string
    !> Index of located string
    integer(kind=musica_ik), intent(out) :: id
    !> Do a case sensitive search
    logical, intent(in), optional :: case_sensitive

    find_string_in_array_string = find_string_in_array_char( array,           &
        string%to_char( ), id, case_sensitive )

  end function find_string_in_array_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Find a string in an array of strings after splitting the array elements
  !!
  !! Case insensitive by default
  logical function find_string_in_split_array_char( array, string, splitter,  &
      element_id, id, case_sensitive )

    use musica_string,                 only : string_t

    !> Array to search
    type(string_t), intent(in) :: array(:)
    !> String to search for
    character(len=*), intent(in) :: string
    !> Splitting characters
    character(len=*), intent(in) :: splitter
    !> Element to compare in split strings
    integer(kind=musica_ik), intent(in) :: element_id
    !> Index of located string
    integer(kind=musica_ik), intent(out) :: id
    !> Do a case sensitive search
    logical, intent(in), optional :: case_sensitive

    type(string_t) :: temp_string, array_string
    type(string_t), allocatable :: split_string(:)
    integer :: i_str
    logical :: is_case_sensitive

    is_case_sensitive = .false.
    if( present( case_sensitive ) ) then
      is_case_sensitive = case_sensitive
    end if
    id = 0
    find_string_in_split_array_char = .false.
    temp_string = trim( string )
    if( .not. is_case_sensitive ) temp_string = temp_string%to_lower( )
    do i_str = 1, size( array )
      array_string = array( i_str )
      if( .not. is_case_sensitive ) array_string = array_string%to_lower( )
      split_string = array_string%split( splitter )
      if( size( split_string ) .ge. element_id ) then
        array_string = split_string( element_id )
      else
        cycle
      end if
      if( temp_string .eq. array_string ) then
        id = i_str
        find_string_in_split_array_char = .true.
        exit
      end if
    end do

  end function find_string_in_split_array_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Find a string in an array of strings after splitting the array elements
  !!
  !! Case insensitive by default
  logical function find_string_in_split_array_string( array, string, splitter, &
      element_id, id, case_sensitive )

    use musica_string,                 only : string_t

    !> Array to search
    type(string_t), intent(in) :: array(:)
    !> String to search for
    type(string_t), intent(in) :: string
    !> Splitting characters
    character(len=*), intent(in) :: splitter
    !> Element to compare in split strings
    integer(kind=musica_ik), intent(in) :: element_id
    !> Index of located string
    integer(kind=musica_ik), intent(out) :: id
    !> Do a case sensitive search
    logical, intent(in), optional :: case_sensitive

    find_string_in_split_array_string =                                       &
        find_string_in_split_array_char( array, string%to_char( ), splitter,  &
                                         element_id, id, case_sensitive )

  end function find_string_in_split_array_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Merge to sets of values into a single set without duplicates
  !!
  !! Both sets must be arranged in increasing order
  !!
  function merge_series( a, b, with_bounds_from ) result( new_set )

    !> New series
    real(kind=musica_dk), allocatable :: new_set(:)
    !> First series
    real(kind=musica_dk), intent(in) :: a(:)
    !> Second series
    real(kind=musica_dk), intent(in) :: b(:)
    !> Restricts series to bounds in this array
    real(kind=musica_dk), intent(in), optional :: with_bounds_from(:)

    real(kind=musica_dk) :: curr_val, val_a, val_b, min_val, max_val
    integer :: n_total, i_a, i_b, i_c, n_a, n_b

    if( present( with_bounds_from ) ) then
      min_val = with_bounds_from( 1 )
      max_val = with_bounds_from( size( with_bounds_from ) )
    else
      min_val = -huge( 0.0_musica_dk )
      max_val =  huge( 0.0_musica_dk )
    endif

    n_a = size( a )
    n_b = size( b )
    if( n_a + n_b .eq. 0 ) then
      allocate( new_set( 0 ) )
      return
    end if

    curr_val = huge( 1.0_musica_dk )
    if( n_a .gt. 0 ) curr_val = a( 1 )
    if( n_b .gt. 0 ) then
      if( b( 1 ) .lt. curr_val ) curr_val = b( 1 )
    end if
    if( curr_val .lt. min_val ) curr_val = min_val
    if( curr_val .gt. max_val ) curr_val = max_val

    i_a = 1
    i_b = 1
    n_total = 0
    do while( i_a .le. n_a )
      if( a( i_a ) .ge. min_val ) exit
      i_a = i_a + 1
    end do
    do while( i_b .le. n_b )
      if( b( i_b ) .ge. min_val ) exit
      i_b = i_b + 1
    end do
    do while( i_a .le. n_a .or. i_b .le. n_b )
      if( i_a .le. n_a ) then
        val_a = a( i_a )
        if( val_a .gt. max_val ) then
          i_a = n_a + 1
          cycle
        end if
      else
        val_a = huge( 1.0_musica_dk )
      end if
      if( i_b .le. n_b ) then
        val_b = b( i_b )
        if( val_b .gt. max_val ) then
          i_b = n_b + 1
          cycle
        end if
      else
        val_b = huge( 1.0_musica_dk )
      end if
      curr_val = min( val_a, val_b )
      n_total = n_total + 1
      if( val_a .le. curr_val ) i_a = i_a + 1
      if( val_b .le. curr_val ) i_b = i_b + 1
    end do

    allocate( new_set( n_total ) )

    i_a = 1
    i_b = 1
    n_total = 0
    do while( i_a .le. n_a )
      if( a( i_a ) .ge. min_val ) exit
      i_a = i_a + 1
    end do
    do while( i_b .le. n_b )
      if( b( i_b ) .ge. min_val ) exit
      i_b = i_b + 1
    end do
    do while( i_a .le. n_a .or. i_b .le. n_b )
      if( i_a .le. n_a ) then
        val_a = a( i_a )
        if( val_a .gt. max_val ) then
          i_a = n_a + 1
          cycle
        end if
      else
        val_a = huge( 1.0_musica_dk )
      end if
      if( i_b .le. n_b ) then
        val_b = b( i_b )
        if( val_b .gt. max_val ) then
          i_b = n_b + 1
          cycle
        end if
      else
        val_b = huge( 1.0_musica_dk )
      end if
      curr_val = min( val_a, val_b )
      n_total = n_total + 1
      new_set( n_total ) = curr_val
      if( val_a .le. curr_val ) i_a = i_a + 1
      if( val_b .le. curr_val ) i_b = i_b + 1
    end do

  end function merge_series

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_array
