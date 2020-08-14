!> \file
!> Tests for the musica_array module

!> Tests for the musica_array module
program test_util_array

  use musica_assert,                   only : assert
  use musica_array
  use musica_constants,                only : musica_ik, musica_rk, musica_dk
  use musica_string,                   only : string_t

  implicit none

  call test_array_functions( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Tests array functions
  subroutine test_array_functions( )

    type(string_t), allocatable :: str_array(:)
    real(kind=musica_dk), allocatable :: dbl_array(:)
    real(kind=musica_rk), allocatable :: flt_array(:)
    integer(kind=musica_ik), allocatable :: int_array(:)
    logical, allocatable :: bool_array(:)
    type(string_t) :: str
    integer(kind=musica_ik) :: idx

    allocate( str_array(  0 ) )
    allocate( dbl_array(  0 ) )
    allocate( flt_array(  0 ) )
    allocate( int_array(  0 ) )
    allocate( bool_array( 0 ) )

    str = "bar"
    call add_to_array( str_array, "foo"      )
    call add_to_array( str_array, str        )
    call add_to_array( str_array, "foO"//str )

    call assert( 301097835, size( str_array ) .eq. 3 )
    call assert( 184681299, find_string_in_array( str_array, "foo", idx ) )
    call assert( 360841928, idx .eq. 1 )
    call assert( 520470218, find_string_in_array( str_array, "foObar", idx,   &
                                                  case_sensitive = .true. ) )
    call assert( 745106908, idx .eq. 3 )
    call assert( 239900503, .not. find_string_in_array( str_array, "fooBar",  &
                                              idx, case_sensitive = .true. ) )
    call assert( 234636196, .not. find_string_in_array( str_array,            &
                                                        "not there", idx ) )
    call assert( 911905039, find_string_in_array( str_array, str, idx ) )
    call assert( 689173883, idx .eq. 2 )
    str = "Bar"
    call assert( 183967478, .not. find_string_in_array( str_array, str, idx,  &
                                                   case_sensitive = .true. ) )
    str = "not there"
    call assert( 231277423, .not. find_string_in_array( str_array, str, idx ) )

    deallocate( str_array )
    allocate( str_array( 3 ) )

    str_array( 1 ) = "foo.BaR"
    str_array( 2 ) = "Bar.foO"
    str_array( 3 ) = "justfoo"

    call assert( 100527721, find_string_in_split_array( str_array, "foo", ".",&
                                                        1, idx ) )
    call assert( 253438465, idx .eq. 1 )
    call assert( 192693428, find_string_in_split_array( str_array, "foo", ".",&
                                                        2, idx ) )
    call assert( 522478622, idx .eq. 2 )
    call assert( 634796967, .not. find_string_in_split_array( str_array,      &
                              "foo", ".", 2, idx, case_sensitive = .true. ) )
    call assert( 747115312, find_string_in_split_array( str_array, "BaR", ".",&
                              2, idx, case_sensitive = .true. ) )
    call assert( 859433657, idx .eq. 1 )

    call add_to_array( dbl_array, 43.0_musica_dk )
    call add_to_array( dbl_array, 31.5_musica_dk )
    call add_to_array( dbl_array, 82.4_musica_dk )

    call assert( 291021516, size( dbl_array ) .eq. 3 )
    call assert( 510393899, dbl_array( 1 ) .eq. 43.0_musica_dk )
    call assert( 235088491, dbl_array( 2 ) .eq. 31.5_musica_dk )
    call assert( 282398436, dbl_array( 3 ) .eq. 82.4_musica_dk )

    call add_to_array( flt_array, 43.0_musica_rk )
    call add_to_array( flt_array, 31.5_musica_rk )
    call add_to_array( flt_array, 82.4_musica_rk )

    call assert( 624617778, size( flt_array ) .eq. 3 )
    call assert( 336878222, flt_array( 1 ) .eq. 43.0_musica_rk )
    call assert( 508940660, flt_array( 2 ) .eq. 31.5_musica_rk )
    call assert( 621259005, flt_array( 3 ) .eq. 82.4_musica_rk )

    call add_to_array( int_array, 43_musica_ik )
    call add_to_array( int_array, 31_musica_ik )
    call add_to_array( int_array, 82_musica_ik )

    call assert( 398527849, size( int_array ) .eq. 3 )
    call assert( 445837794, int_array( 1 ) .eq. 43_musica_ik )
    call assert( 840631388, int_array( 2 ) .eq. 31_musica_ik )
    call assert( 952949733, int_array( 3 ) .eq. 82_musica_ik )

    call add_to_array( bool_array, .true.  )
    call add_to_array( bool_array, .false. )
    call add_to_array( bool_array, .true.  )

    call assert( 112693827, size( bool_array ) .eq. 3 )
    call assert( 160003772,       bool_array( 1 ) )
    call assert( 272322117, .not. bool_array( 2 ) )
    call assert( 667115711,       bool_array( 3 ) )

  end subroutine test_array_functions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program test_util_array
