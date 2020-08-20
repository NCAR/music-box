! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_datetime module

!> The datetime_t type and related functions
module musica_datetime

  use musica_constants,                only : musica_dk, musica_ik

  implicit none
  private

  public :: datetime_t

  !> Days in each month in a non-leap year
  integer(kind=musica_ik), parameter :: kDaysInMonthNonLeapYear(12) =         &
      (/ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /)
  !> Days in each month in a leap year
  integer(kind=musica_ik), parameter :: kDaysInMonthLeapYear(12) =            &
      (/ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /)

  !> A date-time
  !!
  !! \todo add example for working with datetime_t objects
  !!
  type :: datetime_t
    private
    !> Calendar year
    integer(kind=musica_ik) :: year_ = 1
    !> Calendar month
    integer(kind=musica_ik) :: month_ = 1
    !> Calendar day
    integer(kind=musica_ik) :: day_ = 1
    !> Hour
    integer(kind=musica_ik) :: hour_ = 0
    !> Minute
    integer(kind=musica_ik) :: minute_ = 0
    !> Second
    real(kind=musica_dk) :: second_ = 0.0
    !> Difference from UTC [hr]
    real(kind=musica_dk) :: utc_offset__hr_ = 0.0
  contains
    !> Gets the date-time as seconds since 01/01/0001 00:00:00 UTC
    procedure :: in_seconds
    !> Adds years
    procedure :: add_years
    !> Adds months
    procedure :: add_months
    !> Adds days
    procedure :: add_days
    !> Adds hours
    procedure :: add_hours
    !> Adds minutes
    procedure :: add_minutes
    !> Adds seconds
    procedure :: add_seconds
    !> Returns a flag indicating whether this is in a leap year
    procedure :: is_leap_year
    !> Validates the date-time
    procedure, private :: validate
    !> @name Date-time comparisons
    !! @{
    procedure, private, pass(a) :: equals
    generic :: operator(==) => equals
    procedure, private, pass(a) :: not_equals
    generic :: operator(/=) => not_equals
    procedure, private, pass(a) :: greater_than
    generic :: operator(>) => greater_than
    procedure, private, pass(a) :: greater_than_equal_to
    generic :: operator(>=) => greater_than_equal_to
    procedure, private, pass(a) :: less_than
    generic :: operator(<) => less_than
    procedure, private, pass(a) :: less_than_equal_to
    generic :: operator(<=) => less_than_equal_to
    !> @}
    !> Gets the date-time as a string in MM/DD/YYYY HH:MM:SS.SSS UTC form
    procedure :: to_string
    !> Prints a date time
    procedure :: print => do_print
  end type datetime_t

  !> Constructor
  interface datetime_t
    module procedure :: constructor
  end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a datetime
  function constructor( config ) result( new_obj )

    use musica_assert,                 only : assert_msg
    use musica_config,                 only : config_t
    use musica_string,                 only : to_char

    !> New date-time
    type(datetime_t) :: new_obj
    !> Configuration
    type(config_t), intent(inout) :: config

    character(len=*), parameter :: my_name = "Date-Time constructor"

    call config%get( "year",   new_obj%year_,   my_name )
    call config%get( "month",  new_obj%month_,  my_name )
    call config%get( "day",    new_obj%day_,    my_name )
    call config%get( "hour",   new_obj%hour_,   my_name, default = 0 )
    call config%get( "minute", new_obj%minute_, my_name, default = 0 )
    call config%get( "second", new_obj%second_, my_name,                      &
                     default = 0.0_musica_dk )
    call config%get( "UTC offset", new_obj%utc_offset__hr_, my_name,          &
                     default = 0.0_musica_dk )
    call new_obj%validate( )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the date-time in seconds since 01/01/0001 00:00:00 UTC
  function in_seconds( this ) result( time__s )

    !> Time since 01/01/0001 00:00:00 UTC [s]
    real(kind=musica_dk) :: time__s
    !> Date-time
    class(datetime_t), intent(in) :: this

    time__s = ( ( ( days_until_year( this%year_ ) +                           &
                    days_until_month( this%month_, this%is_leap_year( ) ) +   &
                    this%day_ - 1 ) * 24.0_musica_dk +                        &
                  this%hour_ + this%utc_offset__hr_ ) * 60.0_musica_dk +      &
                this%minute_ ) * 60.0_musica_dk + this%second_

  end function in_seconds

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds years to a date-time
  function add_years( this, years ) result( new_datetime )

    !> New date-time
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Years to add
    integer(kind=musica_ik), intent(in) :: years

    new_datetime = this
    new_datetime%year_ = new_datetime%year_ + years

  end function add_years

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds months to a date-time
  function add_months( this, months ) result( new_datetime )

    !> New datetime
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Months to add
    integer(kind=musica_ik), intent(in) :: months

    integer(kind=musica_ik) :: years

    new_datetime = this
    years = floor( real( months + this%month_ - 1, kind=musica_dk ) / 12.0 )
    new_datetime%month_ = this%month_ + months - years * 12
    if( years .ne. 0 ) new_datetime = new_datetime%add_years( years )

  end function add_months

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds days to a date-time
  !!
  !! Accounts for days-per-month and leap years to calculate new date-time.
  !!
  function add_days( this, days ) result( new_datetime )

    !> New datetime
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Days to add
    integer(kind=musica_ik), intent(in) :: days

    type(datetime_t) :: prev
    integer(kind=musica_ik) :: l_day, month_days

    l_day = days + this%day_
    new_datetime = this
    if( l_day .gt. 0 ) then
      month_days = days_in_month( new_datetime%month_,                        &
                                  new_datetime%is_leap_year( ) )
      do while( l_day .ge. month_days )
        l_day = l_day - month_days
        if( new_datetime%month_ .lt. 12 ) then
          new_datetime%month_ = new_datetime%month_ + 1
        else
          new_datetime%month_ = 1
          new_datetime%year_ = new_datetime%year_ + 1
        end if
        month_days = days_in_month( new_datetime%month_,                      &
                                    new_datetime%is_leap_year( ) )
      end do
    else
      if( new_datetime%month_ .eq. 1 ) then
        prev%month_ = 12
        prev%year_ = new_datetime%year_ - 1
      else
        prev%month_ = new_datetime%month_ - 1
        prev%year_ = new_datetime%year_
      end if
      month_days = days_in_month( prev%month_, prev%is_leap_year( ) )
      do while( l_day .lt. 1 )
        l_day = l_day + month_days
        new_datetime%month_ = prev%month_
        new_datetime%year_  = prev%year_
        if( new_datetime%month_ .eq. 1 ) then
          prev%month_ = 12
          prev%year_ = new_datetime%year_ - 1
        else
          prev%month_ = new_datetime%month_ - 1
          prev%year_ = new_datetime%year_
        end if
        month_days = days_in_month( prev%month_, prev%is_leap_year( ) )
      end do
    end if
    new_datetime%day_ = l_day

  end function add_days

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds hours to a date-time
  function add_hours( this, hours ) result( new_datetime )

    !> New date-time
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Hours to add
    integer(kind=musica_ik), intent(in) :: hours

    integer(kind=musica_ik) :: days

    new_datetime = this
    days = floor( real( hours + this%hour_, kind=musica_dk ) / 24.0 )
    new_datetime%hour_ = this%hour_ + hours - days * 24
    if( days .ne. 0 ) new_datetime = new_datetime%add_days( days )

  end function add_hours

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds minutes to a date-time
  function add_minutes( this, minutes ) result( new_datetime )

    !> New date-time
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Minutes to add
    integer(kind=musica_ik), intent(in) :: minutes

    integer(kind=musica_ik) :: hours

    new_datetime = this
    hours = floor( real( minutes + this%minute_, kind=musica_dk ) / 60.0 )
    new_datetime%minute_ = this%minute_ + minutes - hours * 60
    if( hours .ne. 0 ) new_datetime = new_datetime%add_hours( hours )

  end function add_minutes

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Adds seconds to a date-time
  function add_seconds( this, seconds ) result( new_datetime )

    !> New date-time
    type(datetime_t) :: new_datetime
    !> Date-time
    class(datetime_t), intent(in) :: this
    !> Seconds to add
    real(kind=musica_dk), intent(in) :: seconds

    integer(kind=musica_ik) :: minutes
    real(kind=musica_dk) :: l_sec

    new_datetime = this
    minutes = floor( ( seconds + this%second_ ) / 60.0_musica_dk )
    l_sec = seconds - real( minutes, kind=musica_dk ) * 60.0_musica_dk
    new_datetime%second_ = this%second_ + l_sec
    if( minutes .ne. 0 ) new_datetime = new_datetime%add_minutes( minutes )

  end function add_seconds

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Validates the date-time
  subroutine validate( this )

    use musica_assert,                 only : assert_msg
    use musica_string,                 only : to_char

    !> Date-time
    class(datetime_t), intent(in) :: this

    call assert_msg( 216003338, this%month_ .ge. 1 .and.                      &
                                this%month_ .le. 12,                          &
                     "Invalid date-time month: "//to_char( this%month_ ) )
    if( this%is_leap_year( ) ) then
      call assert_msg( 772783051, this%day_ .ge. 1 .and.                      &
                    this%day_ .le. kDaysInMonthLeapYear( this%month_ ),       &
                    "Invalid date-time day: "//to_char( this%day_ )//         &
                    " for leap-year month: "//to_char( this%month_ ) )
    else
      call assert_msg( 334325408, this%day_ .ge. 1 .and.                      &
                 this%day_ .le. kDaysInMonthNonLeapYear( this%month_ ),       &
                 "Invalid date-time day: "//to_char( this%day_ )//            &
                 " for leap-year month: "//to_char( this%month_ ) )
    end if
    call assert_msg( 142110332, this%hour_ .ge. 0 .and.                       &
                                this%hour_ .lt. 24,                           &
                     "Invalid date-time hour: "//to_char( this%hour_ ) )
    call assert_msg( 535450687, this%minute_ .ge. 0 .and.                     &
                                this%minute_ .lt. 60,                         &
                     "Invalid date-time minute: "//to_char( this%minute_ ) )
    call assert_msg( 647769032, this%second_ .ge. 0.0 .and.                   &
                                this%second_ .lt. 60.0,                       &
                     "Invalid date-time second: "//to_char( this%second_ ) )
    call assert_msg( 858970630, this%utc_offset__hr_ .ge. -12.0 .and.         &
                                this%utc_offset__hr_ .le. 12.0,               &
                     "Invalid date-time UTC offset: "//                       &
                     to_char( this%utc_offset__hr_ ) )

  end subroutine validate

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns whether a year is a leap year
  logical function is_leap_year( this )

    !> Date-time
    class(datetime_t), intent(in) :: this

    is_leap_year = mod( this%year_,   4 ) .eq. 0 .and.                        &
                   ( mod( this%year_, 100 ) .ne. 0 .or.                       &
                     mod( this%year_, 400 ) .eq. 0 )

  end function is_leap_year

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the number of days from 01/01/0001 up to a given year
  function days_until_year( year ) result( days )

    !> Number of days until given year
    integer(kind=musica_ik) :: days
    !> Calendar year
    integer(kind=musica_ik), intent(in) :: year

    integer(kind=musica_ik) :: y

    y = year - 1
    days = y * 365 + y / 4 - y / 100 + y / 400

  end function days_until_year

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the number of days in a year up to a given month
  function days_until_month( month, is_leap_year ) result( days )

    !> Number of days until given month
    integer(kind=musica_ik) :: days
    !> Calendar month
    integer(kind=musica_ik), intent(in) :: month
    !> Flag indicating whether this is a leap year
    logical, intent(in) :: is_leap_year

    integer(kind=musica_ik) :: i_month

    days = 0
    if( is_leap_year ) then
      do i_month = 1, month - 1
        days = days + kDaysInMonthLeapYear( i_month )
      end do
    else
      do i_month = 1, month - 1
        days = days + kDaysInMonthNonLeapYear( i_month )
      end do
    end if

  end function days_until_month

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the number of days in a month
  function days_in_month( month, is_leap_year ) result( days )

    !> Number of days in the month
    integer(kind=musica_ik) :: days
    !> Calendar month
    integer(kind=musica_ik) :: month
    !> Flag indicating whether this is a leap year
    logical, intent(in) :: is_leap_year

    if( is_leap_year ) then
      days = kDaysInMonthLeapYear( month )
    else
      days = kDaysInMonthNonLeapYear( month )
    end if

  end function days_in_month

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Equality comparison
  logical function equals( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    equals = a%in_seconds( ) .eq. b%in_seconds( )

  end function equals

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Inequality comparison
  logical function not_equals( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    not_equals = .not. a%in_seconds( ) .eq. b%in_seconds( )

  end function not_equals

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Greater-than comparison
  logical function greater_than( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    greater_than = a%in_seconds( ) .gt. b%in_seconds( )

  end function greater_than

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Greater-than or equal-to comparison
  logical function greater_than_equal_to( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    greater_than_equal_to = a%in_seconds( ) .ge. b%in_seconds( )

  end function greater_than_equal_to

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Less-than comparison
  logical function less_than( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    less_than = a%in_seconds( ) .lt. b%in_seconds( )

  end function less_than

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Less-than or equal-to comparison
  logical function less_than_equal_to( a, b )

    !> Date-time
    class(datetime_t), intent(in) :: a
    !> Date-time
    class(datetime_t), intent(in) :: b

    less_than_equal_to = a%in_seconds( ) .le. b%in_seconds( )

  end function less_than_equal_to

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets a string containing the date-time in MM/DD/YYYY HH:MM:SS.SSS UTC
  !! form
  function to_string( this )

    !> String with date-time
    character(len=27) :: to_string
    !> Date-time
    class(datetime_t), intent(in) :: this

    character(len=*), parameter :: fmt =                                      &
        '(I2.2,"/",I2.2,"/",I4.4," ",I2.2,":",I2.2,":",I2.2,F4.3," UTC")'
    type(datetime_t) :: in_utc

    in_utc = this%add_seconds( -this%utc_offset__hr_ * 60.0 * 60.0 )
    write(to_string, fmt) in_utc%month_, in_utc%day_, in_utc%year_,           &
                          in_utc%hour_, in_utc%minute_, int(in_utc%second_),  &
                          in_utc%second_ - int(in_utc%second_)

  end function to_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints a date-time in MM/DD/YYYY HH:MM:SS.S UTC form
  subroutine do_print( this )

    !> Date-time
    class(datetime_t), intent(in) :: this

    write(*,*) this%to_string( )

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_datetime
