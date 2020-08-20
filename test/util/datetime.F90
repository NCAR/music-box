!> \file
!> Tests for the musica_datetime module

!> Test module for the musica_datetime module
program test_datetime

  use musica_assert
  use musica_datetime

  implicit none

  call test_datetime_t( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Test datetime_t functionality
  subroutine test_datetime_t( )

    use musica_config,                 only : config_t
    use musica_constants,              only : musica_dk, musica_ik
    use musica_string,                 only : string_t

    integer(kind=musica_ik), parameter :: leap_year_in_seconds =              &
        366 * 24 * 60 * 60
    integer(kind=musica_ik), parameter :: non_leap_year_in_seconds =          &
        365 * 24 * 60 * 60
    integer(kind=musica_ik), parameter :: day_in_seconds = 24 * 60 * 60
    integer(kind=musica_ik), parameter :: hour_in_seconds = 60 * 60
    type(config_t) :: config
    type(datetime_t) :: a, b, c
    real(kind=musica_dk) :: temp_real, temp_real_2
    integer(kind=musica_ik) :: temp_int
    type(string_t) :: temp_str

    ! date times default to the reference date-time 01/01/0001 00:00:00 UTC
    call assert( 784462574, a%in_seconds( ) .eq. 0.0 )
    temp_str = a%to_string( )
    call assert( 206552476, temp_str .eq. "01/01/0001 00:00:00.000 UTC" )

    ! year 1 is not a leap year
    call assert( 893422146, .not. a%is_leap_year( ) )

    ! add several years worth of seconds (should arrive at 1/1/5)
    temp_real = 3 * non_leap_year_in_seconds + leap_year_in_seconds
    b = a%add_seconds( temp_real )
    call assert( 136708867, b%in_seconds( ) .eq. temp_real )
    temp_str = b%to_string( )
    call assert( 445338079, temp_str .eq. "01/01/0005 00:00:00.000 UTC" )

    ! ... and again (should arrive at 6/13/9 12:05:13.251 UTC)
    ! (day 164 of the year)
    temp_real_2 = 3.0 * non_leap_year_in_seconds + leap_year_in_seconds
    temp_real_2 = temp_real_2 + ( 164.0 - 1.0 ) * day_in_seconds
    temp_real_2 = temp_real_2 + 12.0 * hour_in_seconds
    temp_real_2 = temp_real_2 + 5.0 * 60 + 13.251
    c = b%add_seconds( temp_real_2 )
    call assert( 516161835, c%in_seconds( ) .eq. temp_real + temp_real_2 )
    call assert( 288166372,                                                   &
                 c%in_seconds( ) .eq. b%in_seconds( ) + temp_real_2 )
    temp_str = c%to_string( )
    call assert( 857664956, temp_str .eq. "06/13/0009 12:05:13.251 UTC" )

    ! now substract
    a = c%add_seconds( -temp_real_2 )
    call assert( 226705114, a%in_seconds( ) .eq. temp_real )
    call assert( 281184900, a .eq. b )
    temp_str = a%to_string( )
    call assert( 730458280, temp_str .eq. "01/01/0005 00:00:00.000 UTC" )
    a = a%add_seconds( -temp_real )
    call assert( 493839737, a%in_seconds( ) .eq. 0.0 )
    temp_str = a%to_string( )
    call assert( 204646942, temp_str .eq. "01/01/0001 00:00:00.000 UTC" )

    ! check add year and months
    c = c%add_months( 30 )
    temp_str = c%to_string( )
    call assert( 542341395, temp_str .eq. "12/13/0011 12:05:13.251 UTC" )
    c = c%add_months( -30 )
    temp_str = c%to_string( )
    call assert( 148000096, temp_str .eq. "06/13/0009 12:05:13.251 UTC" )
    c = c%add_years( 2010 )
    temp_str = c%to_string( )
    call assert( 874484418, temp_str .eq. "06/13/2019 12:05:13.251 UTC" )
    c = c%add_years( -2010 )
    temp_str = c%to_string( )
    call assert( 358749399, temp_str .eq. "06/13/0009 12:05:13.251 UTC" )


    ! check the comparison operators
    call assert( 822623987, a .ne. b .and. b .ne. c .and. a .ne. c )
    call assert( 424471620, a .lt. b .and. a .lt. c .and. b .lt. c )
    call assert( 424471620, .not. ( b .lt. a .or. c .lt. a .or. c .lt. b ) )
    call assert( 912884160, b .gt. a .and. c .gt. a .and. c .gt. b )
    call assert( 174417985, .not. ( a .gt. b .or. a .gt. c .or. b .gt. c ) )
    call assert( 513278554, a .le. b .and. a .le. c .and. b .le. c )
    call assert( 960646400, .not. ( b .le. a .or. c .le. a .or. c .le. b ) )
    call assert( 790489496, b .ge. a .and. c .ge. a .and. c .ge. b )
    call assert( 902807841, .not. ( a .ge. b .or. a .ge. c .or. b .ge. c ) )
    a = b
    call assert( 224085759, a .eq. b .and. a .ne. c .and. b .ne. c )
    call assert( 108408641, a .le. b .and. .not. a .lt. b )
    call assert( 275206772, a .ge. b .and. .not. a .gt. b )

    ! an online tool (https://www.epochconverter.com/seconds-days-since-y0)
    ! was used to calculate the seconds since 01/01/0001 00:00:00 UTC
    ! for August 19, 2020 22:56:11 UTC: 63733474571 s
    config = '{ "year" : 2020, "month" : 8, "day" : 19, "hour" : 22, '//      &
             ' "minute" : 56, "second" : 11.0 }'
    a = datetime_t( config )
    call assert( 257223594, a%in_seconds( ) .eq. 63733474571.0_musica_dk )
    call config%finalize( )

    ! check leap years
    config = '{ "year" : 2015, "month" : 3, "day" : 23 }'
    a = datetime_t( config )
    call assert( 625147004, .not. a%is_leap_year( ) )
    call config%finalize( )
    config = '{ "year" : 2020, "month" : 1, "day" : 1 }'
    a = datetime_t( config )
    call assert( 953478959, a%is_leap_year( ) )
    call config%finalize( )
    config = '{ "year" : 1000, "month" : 7, "day" : 12 }'
    a = datetime_t( config )
    call assert( 124036390, .not. a%is_leap_year( ) ) ! multiple of 100
    call config%finalize( )
    config = '{ "year" : 1200, "month" : 7, "day" : 12 }'
    a = datetime_t( config )
    call assert( 852426246, a%is_leap_year( ) ) ! multiple of 400
    call config%finalize( )

    ! check UTC offsets
    config = '{ "year" : 2020, "month" : 1, "day" : 1, "hour" : 3 }'
    a = datetime_t( config )
    call config%finalize( )
    config = '{ "year" : 2020, "month" : 1, "day" : 1, "hour" : 3,            &
                "UTC offset" : -9.5 }'
    b = datetime_t( config )
    call config%finalize( )
    config = '{ "year" : 2020, "month" : 1, "day" : 1, "hour" : 3,            &
                "UTC offset" : 6.0 }'
    c = datetime_t( config )
    call config%finalize( )
    call assert( 261683299, a%in_seconds( ) .eq. b%in_seconds( )              &
                                                 + 9.5 * hour_in_seconds )
    call assert( 261683299, a%in_seconds( ) .eq. c%in_seconds( )              &
                                                 - 6.0 * hour_in_seconds )
    temp_str = b%to_string( )
    call assert( 646400574, temp_str .eq. "01/01/2020 12:30:00.000 UTC" )
    temp_str = c%to_string( )
    call assert( 875161052, temp_str .eq. "12/31/2019 21:00:00.000 UTC" )

    ! check for precision loss
    config = '{ "year" : 3000, "month" : 1, "day" : 1 }'
    a = datetime_t( config )
    call config%finalize( )
    b = a%add_seconds( 0.001_musica_dk )
    call assert( 844935336, almost_equal( a%in_seconds( ) + 0.001_musica_dk,  &
                                          b%in_seconds( ) ) )

  end subroutine test_datetime_t

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program test_datetime
