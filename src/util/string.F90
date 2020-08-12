! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_string module

!> The string_t type and related functions
module musica_string

  use musica_constants,                only : musica_ik, musica_rk, musica_dk

  implicit none
  private

  public :: string_t, operator(//), operator(==), operator(/=), to_char

  !> Length of character array for to_char conversions
  integer(kind=musica_ik), parameter :: kConvertCharLength = 100

  !> Generic tring type
  type :: string_t
    !> the string
    character(len=:), allocatable :: val_
  contains
    !> @name String assignment
    !! @{
    procedure, private, pass(to) :: string_assign_char
    procedure, private, pass(to) :: string_assign_int
    procedure, private, pass(to) :: string_assign_real
    procedure, private, pass(to) :: string_assign_double
    procedure, private, pass(to) :: string_assign_logical
    procedure, private, pass(from) :: assign_string
    generic :: assignment(=) => string_assign_char, string_assign_int,        &
                                string_assign_real, string_assign_double,     &
                                string_assign_logical, assign_string
    !> @}
    !> @name Joins to a string
    !! @{
    procedure, private, pass(a) :: string_join_string
    procedure, private, pass(a) :: string_join_char
    procedure, private, pass(a) :: string_join_int
    procedure, private, pass(a) :: string_join_real
    procedure, private, pass(a) :: string_join_double
    procedure, private, pass(a) :: string_join_logical
    procedure, private, pass(b) :: char_join_string
    procedure, private, pass(b) :: int_join_string
    procedure, private, pass(b) :: real_join_string
    procedure, private, pass(b) :: double_join_string
    procedure, private, pass(b) :: logical_join_string
    generic :: operator(//) => string_join_string, string_join_char,          &
                               string_join_int, string_join_real,             &
                               string_join_double, string_join_logical,       &
                               char_join_string, int_join_string,             &
                               real_join_string, double_join_string,          &
                               logical_join_string
    !> @}
    !> @name String equality
    !! @{
    procedure, private, pass(a) :: string_equals_string
    procedure, private, pass(a) :: string_equals_char
    procedure, private, pass(a) :: string_equals_int
    procedure, private, pass(a) :: string_equals_real
    procedure, private, pass(a) :: string_equals_double
    procedure, private, pass(a) :: string_equals_logical
    procedure, private, pass(b) :: char_equals_string
    procedure, private, pass(b) :: int_equals_string
    procedure, private, pass(b) :: real_equals_string
    procedure, private, pass(b) :: double_equals_string
    procedure, private, pass(b) :: logical_equals_string
    generic :: operator(==) => string_equals_string, string_equals_char,      &
                               string_equals_int, string_equals_real,         &
                               string_equals_double, string_equals_logical,   &
                               char_equals_string, int_equals_string,         &
                               real_equals_string, double_equals_string,      &
                               logical_equals_string
    procedure, private, pass(a) :: string_not_equals_string
    procedure, private, pass(a) :: string_not_equals_char
    procedure, private, pass(a) :: string_not_equals_int
    procedure, private, pass(a) :: string_not_equals_real
    procedure, private, pass(a) :: string_not_equals_double
    procedure, private, pass(a) :: string_not_equals_logical
    procedure, private, pass(b) :: char_not_equals_string
    procedure, private, pass(b) :: int_not_equals_string
    procedure, private, pass(b) :: real_not_equals_string
    procedure, private, pass(b) :: double_not_equals_string
    procedure, private, pass(b) :: logical_not_equals_string
    generic :: operator(/=) => string_not_equals_string,                      &
                               string_not_equals_char,                        &
                               string_not_equals_int,                         &
                               string_not_equals_real,                        &
                               string_not_equals_double,                      &
                               string_not_equals_logical,                     &
                               char_not_equals_string,                        &
                               int_not_equals_string,                         &
                               real_not_equals_string,                        &
                               double_not_equals_string,                      &
                               logical_not_equals_string
    !> @}
    !> @name Outputs a string
    !! @{
    procedure :: write_string_unformatted
    procedure :: write_string_formatted
    generic :: write(unformatted) => write_string_unformatted
    generic :: write(formatted) => write_string_formatted
    !> @}
    !> Returns the string length
    procedure :: length
    !> Converts a string to upper case
    procedure :: to_upper
    !> Converts a string to lower case
    procedure :: to_lower
    !> Gets a substring
    procedure :: substring
    !> @name Splits a string on a sub-string
    !! @{
    procedure, private :: split_char
    procedure, private :: split_string
    generic :: split => split_char, split_string
    !> @}

    !> Replaces substrings within a string
    procedure :: replace
    !> Converts a string to a character array
    procedure :: to_char => string_to_char
  end type string_t

  !> Converts values to character arrays
  interface to_char
    module procedure int_to_char
    module procedure real_to_char
    module procedure double_to_char
    module procedure logical_to_char
  end interface to_char

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns a string from a character array
  subroutine string_assign_char( to, from )

    !> String to assign
    class(string_t), intent(out) :: to
    !> New string value
    character(len=*), intent(in) :: from

    to%val_ = trim( from )

  end subroutine string_assign_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns a string from an integer
  subroutine string_assign_int( to, from )

    !> String to assign
    class(string_t), intent(out) :: to
    !> New string value
    integer(kind=musica_ik), intent(in) :: from

    character(len=30) :: new_val

    write( new_val, '(i30)' ) from
    to%val_ = adjustl( new_val )

  end subroutine string_assign_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns a string from a real number
  subroutine string_assign_real( to, from )

    !> String to assign
    class(string_t), intent(out) :: to
    !> New string value
    real(kind=musica_rk), intent(in) :: from

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) from
    to%val_ = adjustl( new_val )

  end subroutine string_assign_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns a string from a double precision real number
  subroutine string_assign_double( to, from )

    !> String to assign
    class(string_t), intent(out) :: to
    !> New string value
    real(kind=musica_dk), intent(in) :: from

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) from
    to%val_ = adjustl( new_val )

  end subroutine string_assign_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns a string from a logical
  subroutine string_assign_logical( to, from )

    !> String to assign
    class(string_t), intent(out) :: to
    !> New string value
    logical, intent(in) :: from

    if( from ) then
      to%val_ = "true"
    else
      to%val_ = "false"
    end if

  end subroutine string_assign_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assigns from a string
  subroutine assign_string( to, from )

    use musica_assert,                 only : die_msg, assert_msg

    !> Object to assign
    class(*), intent(inout) :: to
    !> String
    class(string_t), intent(in) :: from

    integer :: ios, len_char, len_str

    select type( to )
      type is( string_t )
        to%val_ = from%val_
      type is( character(len=*) )
        len_char = len( to )
        len_str  = len( from%val_ )
        if( len_char .lt. len_str ) then
          to = from%val_(1:len_char)
        else
          to = from%val_
        end if
      type is( real )
        call assert_msg( 621504169, len( from%val_ ) .le. 40,                 &
                         "Error converting '"//from%val_//"' to real: "//     &
                         "string too long" )
        read( from%val_, '(f40.0)', iostat=ios ) to
        call assert_msg( 102862672, ios .eq. 0,                               &
                         "Error converting '"//from%val_//"' to real: "//     &
                         "IOSTAT = "//trim( to_char( ios ) ) )
      type is( double precision)
        call assert_msg( 156176342, len( from%val_ ) .le. 40,                 &
                         "Error converting '"//from%val_//"' to double: "//   &
                         "string too long" )
        read( from%val_, '(f40.0)', iostat=ios ) to
        call assert_msg( 445821432, ios .eq. 0,                               &
                         "Error converting '"//from%val_//"' to double: "//   &
                         "IOSTAT = "//trim( to_char( ios ) ) )
      type is( integer )
        call assert_msg( 822629448, len( from%val_ ) .le. 20,                 &
                         "Error converting '"//from%val_//"' to integer: "//  &
                         "string too long" )
        read( from%val_, '(i20)', iostat=ios ) to
        call assert_msg( 484221174, ios .eq. 0,                               &
                         "Error converting '"//from%val_//"' to integer: "//  &
                         "IOSTAT = "//trim( to_char( ios ) ) )
      type is( logical )
        if( from .eq. "true" ) then
          to = .true.
        else if( from .eq. "false" ) then
          to = .false.
        else
          call die_msg( 359920976, "Cannot convert '"//from%val_//            &
                        "' to logical" )
        end if
      class default
        call die_msg( 383270832, "Invalid type for assignment from string" )
    end select

  end subroutine assign_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to a string
  elemental function string_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    c%val_ = a%val_//b%val_

  end function string_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to a character array
  elemental function string_join_char( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> Character array to join
    character(len=*), intent(in) :: b

    c%val_ = a%val_//trim( b )

  end function string_join_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to an integer
  elemental function string_join_int( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> Integer to join
    integer(kind=musica_ik), intent(in) :: b

    character(len=30) :: new_val

    write( new_val, '(i30)' ) b
    c%val_ = a%val_//adjustl( new_val )

  end function string_join_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to a real number
  elemental function string_join_real( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> Real number to join
    real(kind=musica_rk), intent(in) :: b

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) b
    c%val_ = a%val_//adjustl( new_val )

  end function string_join_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to a double precision real number
  elemental function string_join_double( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> Double precision real number to join
    real(kind=musica_dk), intent(in) :: b

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) b
    c%val_ = a%val_//adjustl( new_val )

  end function string_join_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a string to a logical
  elemental function string_join_logical( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> String to join
    class(string_t), intent(in) :: a
    !> Logical to join
    logical, intent(in) :: b

    if( b ) then
      c%val_ = a%val_//"true"
    else
      c%val_ = a%val_//"false"
    end if

  end function string_join_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a string for equality
  logical elemental function string_equals_string( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = trim( a%val_ ) .eq. trim( b%val_ )

  end function string_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a character array for equality
  logical elemental function string_equals_char( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Character array b
    character(len=*), intent(in) :: b

    equals = trim( a%val_ ) .eq. trim( b )

  end function string_equals_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a integer for equality
  logical elemental function string_equals_int( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Integer b
    integer(kind=musica_ik), intent(in) :: b

    character(len=30) :: comp_val

    write( comp_val, '(i30)' ) b
    equals = trim( a%val_ ) .eq. adjustl( comp_val )

  end function string_equals_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a real number for equality
  logical elemental function string_equals_real( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Real number b
    real(kind=musica_rk), intent(in) :: b

    character(len=60) :: comp_val

    write( comp_val, '(g30.20)' ) b
    equals = trim( a%val_ ) .eq. adjustl( comp_val )

  end function string_equals_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a double-precision real number for equality
  logical elemental function string_equals_double( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Double-precition real number b
    real(kind=musica_dk), intent(in) :: b

    character(len=60) :: comp_val

    write( comp_val, '(g30.20)' ) b
    equals = trim( a%val_ ) .eq. adjustl( comp_val )

  end function string_equals_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a logical for equality
  logical elemental function string_equals_logical( a, b ) result( equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Logical b
    logical, intent(in) :: b

    equals = ( trim( a%val_ ) .eq. "true"  .and.       b ) .or.                &
             ( trim( a%val_ ) .eq. "false" .and. .not. b )

  end function string_equals_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a string for equality
  logical elemental function string_not_equals_string( a, b )                 &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a character array for equality
  logical elemental function string_not_equals_char( a, b )                   &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Character array b
    character(len=*), intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a integer for equality
  logical elemental function string_not_equals_int( a, b )                    &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Integer b
    integer(kind=musica_ik), intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a real number for equality
  logical elemental function string_not_equals_real( a, b )                   &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Real number b
    real(kind=musica_rk), intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a double-precision real number for equality
  logical elemental function string_not_equals_double( a, b )                 &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Double-precition real number b
    real(kind=musica_dk), intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a string to a logical for equality
  logical elemental function string_not_equals_logical( a, b )                &
      result( not_equals )

    !> String a
    class(string_t), intent(in) :: a
    !> Logical b
    logical, intent(in) :: b

    not_equals = .not. a .eq. b

  end function string_not_equals_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Writes a string
  subroutine write_string_unformatted( this, unit, iostat, iomsg )

    !> String to read into
    class(string_t), intent(in) :: this
    !> File unit
    integer(kind=musica_ik), intent(in) :: unit
    !> I/O status
    integer(kind=musica_ik), intent(out) :: iostat
    !> I/O error message
    character(len=*), intent(inout) :: iomsg

    write( unit, iostat=iostat, iomsg=iomsg ) this%val_

  end subroutine write_string_unformatted

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Writes a string
  subroutine write_string_formatted( this, unit, iotype, v_list, iostat,      &
      iomsg )

    !> String to read into
    class(string_t), intent(in) :: this
    !> File unit
    integer(kind=musica_ik), intent(in) :: unit
    !> Format string
    character(len=*), intent(in) :: iotype
    !> V list
    integer(kind=musica_ik), intent(in) :: v_list(:)
    !> I/O status
    integer(kind=musica_ik), intent(out) :: iostat
    !> I/O error message
    character(len=*), intent(inout) :: iomsg

    write( unit, fmt=*, iostat=iostat, iomsg=iomsg ) this%val_

  end subroutine write_string_formatted

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the length of the string
  elemental integer function length( this )

    !> String
    class(string_t), intent(in) :: this

    length = len( this%val_ )

  end function length

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a string to upper case
  !!
  !! Adapted from http://www.star.le.ac.uk/~cgp/fortran.html (25 May 2012)
  !! Original author: Clive Page
  function  to_upper( this ) result( cap_string )

    !> Converted string
    type(string_t) :: cap_string
    !> String to convert
    class(string_t), intent(in) :: this

    character(26), parameter :: cap = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    character(26), parameter :: low = 'abcdefghijklmnopqrstuvwxyz'
    integer :: i_str, i_char

    cap_string%val_ = this%val_
    do i_str = 1, len( cap_string%val_ )
      i_char = index( low, cap_string%val_(i_str:i_str) )
      if( i_char .gt. 0 ) cap_string%val_(i_str:i_str) = cap(i_char:i_char)
    end do

  end function to_upper

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a string to lower case
  !!
  !! Adapted from http://www.star.le.ac.uk/~cgp/fortran.html (25 May 2012)
  !! Original author: Clive Page
  function to_lower( this ) result( low_string )

    !> Converted string
    type(string_t) :: low_string
    !> String to convert
    class(string_t), intent(in) :: this

    character(26), parameter :: cap = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    character(26), parameter :: low = 'abcdefghijklmnopqrstuvwxyz'
    integer :: i_str, i_char

    low_string%val_ = this%val_
    do i_str = 1, len( low_string%val_ )
      i_char = index( cap, low_string%val_(i_str:i_str) )
      if( i_char .gt. 0 ) low_string%val_(i_str:i_str) = low(i_char:i_char)
    end do

  end function to_lower

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns a substring
  !!
  !! Example:
  !! \code{f90}
  !!   type(string_t) :: my_string, sub_string
  !!   my_string = "Hi there!"
  !!   sub_string = my_string%substring( 4, 5 )
  !!   write(*,*) sub_string
  !!   sub_string = my_string%substring( 9, 50 )
  !!   write(*,*) sub_string
  !! \endcode
  !!
  !! Output:
  !! \code{bash}
  !!   there
  !!   !
  !! \endcode
  !!
  function substring( this, start_index, length )

    !> Substring
    type(string_t) :: substring
    !> Full string
    class(string_t), intent(in) :: this
    !> Starting character index
    integer(kind=musica_ik), intent(in) :: start_index
    !> Length of the substring to return
    integer(kind=musica_ik), intent(in) :: length

    integer :: l

    if( start_index + length - 1 .gt. len( this%val_ ) ) then
      l = len( this%val_ ) - start_index + 1
    else
      l = length
    end if
    substring%val_ = this%val_(start_index:l+start_index-1)

  end function substring

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Splits a string on a substring
  !!
  !! Example:
  !! \code{f90}
  !!   type(string_t) :: my_string
  !!   type(string_t), allocatable :: sub_strings(:)
  !!   integer :: i
  !!   my_string = "my original    string"
  !!   sub_strings = my_string%split( ' ' )
  !!   do i = 1, size( sub_strings )
  !!     write(*,*) i, sub_strings( i )
  !!   end do
  !!   sub_strings = my_string%split( ' ', .true. )
  !!   do i = 1, size( sub_strings )
  !!     write(*,*) i, sub_strings( i )
  !!   end do
  !! \endcode
  !!
  !! Output:
  !! \code{bash}
  !!            1  my
  !!            2  original
  !!            3
  !!            4
  !!            5
  !!            6  string
  !!            1  my
  !!            2  original
  !!            3  string
  !! \endcode
  !!
  function split_char( this, splitter, compress ) result( sub_strings )

    !> Split string
    type(string_t), allocatable :: sub_strings(:)
    !> Full string
    class(string_t), intent(in) :: this
    !> String to split on
    character(len=*), intent(in) :: splitter
    !> Compress (default = false)
    !!
    !! No 0-length substrings will be returned (adjacent tokens will be
    !! merged; tokens at the beginning and end of the original string will be
    !! ignored)
    logical, intent(in), optional :: compress

    integer :: i, start_str, i_substr, sl, count
    logical :: l_comp, is_string

    if( .not. allocated( this%val_ ) ) return
    if( present( compress ) ) then
      l_comp = compress
    else
      l_comp = .false.
    end if

    sl        = len( splitter )
    if( sl .eq. 0 ) then
      allocate( sub_strings( 1 ) )
      sub_strings(1)%val_ = this%val_
      return
    end if

    count     = 0
    i         = 1
    start_str = 1
    is_string = .not. l_comp
    do while( i .le. len( this%val_ ) - sl + 1 )
      if( this%val_(i:i+sl-1) .eq. splitter ) then
        if( is_string ) then
          count = count + 1
        end if
        i = i + sl
        is_string = .not. l_comp
      else
        i = i + 1
        is_string = .true.
      end if
    end do
    if( is_string ) count = count + 1

    allocate( sub_strings( count ) )

    i         = 1
    start_str = 1
    i_substr  = 1
    is_string = .not. l_comp
    do while( i .le. len( this%val_ ) - sl + 1 )
      if( this%val_(i:i+sl-1) .eq. splitter ) then
        if( is_string ) then
          if( i .eq. start_str ) then
            sub_strings( i_substr ) = ""
          else
            sub_strings( i_substr ) = this%val_(start_str:i-1)
          end if
          i_substr = i_substr + 1
        end if
        i = i + sl
        start_str = i
        is_string = .not. l_comp
      else
        i = i + 1
        is_string = .true.
      end if
    end do

    if( is_string ) then
      if( i .eq. start_str ) then
        sub_strings( i_substr ) = ""
      else
        sub_strings( i_substr ) = this%val_( start_str:len( this%val_ ) )
      end if
    end if

  end function split_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Splits a string on a substring
  !!
  !! See \c string_split_char for description and example
  !!
  function split_string( this, splitter, compress ) result( sub_strings )

    !> Split string
    type(string_t), allocatable :: sub_strings(:)
    !> Full string
    class(string_t), intent(in) :: this
    !> String to split on
    type(string_t), intent(in) :: splitter
    !> Compress (default = false)
    !!
    !! No 0-length substrings will be returned (adjacent tokens will be
    !! merged; tokens at the beginning and end of the original string will be
    !! ignored)
    logical, intent(in), optional :: compress

    sub_strings = this%split_char( splitter%to_char( ), compress )

  end function split_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!> Replaces substrings within a string
  !!
  !! Example:
  !! \code{f90}
  !!   type(string_t) :: my_string
  !!   my_string = "foo bar foobar"
  !!   my_string = my_string%replace( 'foo', 'bar' )
  !!   write(*,*) my_string
  !! \endcode
  !!
  !! Output:
  !! \code{bash}
  !!   bar bar barbar
  !! \endcode
  !!
  function replace( this, from, to )

    !> String with replacements
    type(string_t) :: replace
    !> Original string
    class(string_t) :: this
    !> Sub-string to replace
    character(len=*), intent(in) :: from
    !> Replacement string
    character(len=*), intent(in) :: to

    integer :: i_char, start_str, s
    logical :: is_string

    start_str = 1
    s = len( from )
    is_string = .false.
    replace = ""
    i_char = 1
    do while( i_char .le. len( this%val_ ) - s + 1 )
      if( this%val_( i_char:i_char+s-1 ) .eq. from ) then
        if( is_string .and. i_char .gt. start_str ) then
          replace%val_ = replace%val_//this%val_( start_str:i_char-1 )
        end if
        replace = replace//to
        i_char = i_char + s
        start_str = i_char
        is_string = .false.
      else
        i_char = i_char + 1
        is_string = .true.
      end if
    end do

    if( start_str .le. len( this%val_ ) ) then
      replace%val_ = replace%val_//this%val_( start_str:len( this%val_ ) )
    end if

  end function replace

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a string to a character array
  function string_to_char( this ) result( char_array )

    !> Converted string
    character(len=:), allocatable :: char_array
    !> String to convert
    class(string_t), intent(in) :: this

    char_array = this%val_

  end function string_to_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a character array to a string
  elemental function char_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> Character array to join
    character(len=*), intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    c%val_ = trim( a )//b%val_

  end function char_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins an integer to a string
  elemental function int_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> Integer to join
    integer(kind=musica_ik), intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    character(len=30) :: new_val

    write( new_val, '(i30)' ) a
    c%val_ = trim( adjustl( new_val ) )//b%val_

  end function int_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a real number to a string
  elemental function real_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> Real number to join
    real(kind=musica_rk), intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) a
    c%val_ = trim( adjustl( new_val ) )//b%val_

  end function real_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a double precision real number to a string
  elemental function double_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> Double precision real number to join
    real(kind=musica_dk), intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    character(len=60) :: new_val

    write( new_val, '(g30.20)' ) a
    c%val_ = trim( adjustl( new_val ) )//b%val_

  end function double_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Joins a logical to a string
  elemental function logical_join_string( a, b ) result( c )

    !> Joined string
    type(string_t) :: c
    !> Logical to join
    logical, intent(in) :: a
    !> String to join
    class(string_t), intent(in) :: b

    if( a ) then
      c%val_ = "true"//b%val_
    else
      c%val_ = "false"//b%val_
    end if

  end function logical_join_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a character array to a string for equality
  logical elemental function char_equals_string( a, b ) result( equals )

    !> Character array a
    character(len=*), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = b .eq. a

  end function char_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares an integer to a string for equality
  logical elemental function int_equals_string( a, b ) result( equals )

    !> Integer a
    integer(kind=musica_ik), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = b .eq. a

  end function int_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a real number to a string for equality
  logical elemental function real_equals_string( a, b ) result( equals )

    !> Real number a
    real(kind=musica_rk), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = b .eq. a

  end function real_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a double-precision real number to a string for equality
  logical elemental function double_equals_string( a, b ) result( equals )

    !> Double-precision real number a
    real(kind=musica_dk), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = b .eq. a

  end function double_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a logical to a string for equality
  logical elemental function logical_equals_string( a, b ) result( equals )

    !> Logical a
    logical, intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    equals = b .eq. a

  end function logical_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a character array to a string for equality
  logical elemental function char_not_equals_string( a, b )                   &
      result( not_equals )

    !> Character array a
    character(len=*), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. b .eq. a

  end function char_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares an integer to a string for equality
  logical elemental function int_not_equals_string( a, b )                    &
      result( not_equals )

    !> Integer a
    integer(kind=musica_ik), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. b .eq. a

  end function int_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a real number to a string for equality
  logical elemental function real_not_equals_string( a, b )                   &
      result( not_equals )

    !> Real number a
    real(kind=musica_rk), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. b .eq. a

  end function real_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a double-precision real number to a string for equality
  logical elemental function double_not_equals_string( a, b )                 &
      result( not_equals )

    !> Double-precition real number a
    real(kind=musica_dk), intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. b .eq. a

  end function double_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Compares a logical to a string for equality
  logical elemental function logical_not_equals_string( a, b )                &
      result( not_equals )

    !> Logical a
    logical, intent(in) :: a
    !> String b
    class(string_t), intent(in) :: b

    not_equals = .not. b .eq. a

  end function logical_not_equals_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts an integer to a char array
  character(len=kConvertCharLength) function int_to_char( val )               &
      result( ret_val )

    !> Value to convert
    integer(kind=musica_ik), intent(in) :: val

    write( ret_val, '(i30)' ) val
    ret_val = adjustl( ret_val )

  end function int_to_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a real number to a char array
  character(len=kConvertCharLength) function real_to_char( val )              &
      result( ret_val )

    !> Value to convert
    real(kind=musica_rk), intent(in) :: val

    write( ret_val, '(g30.20)' ) val
    ret_val = adjustl( ret_val )

  end function real_to_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a double-precision real number to a char array
  character(len=kConvertCharLength) function double_to_char( val )            &
      result( ret_val )

    !> Value to convert
    real(kind=musica_dk), intent(in) :: val

    write( ret_val, '(g30.20)' ) val
    ret_val = adjustl( ret_val )

  end function double_to_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a logical to a char array
  character(len=kConvertCharLength) function logical_to_char( val )           &
      result( ret_val )

    !> Value to convert
    logical, intent(in) :: val

    if( val ) then
      write( ret_val, '(a4)' ) "true"
    else
      write( ret_val, '(a5)' ) "false"
    end if

  end function logical_to_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_string
