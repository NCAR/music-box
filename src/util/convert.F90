! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_convert module

!> The convert_t type and related functions for conversion between standard
!! and non-standard MUSICA units
module musica_convert

  use musica_constants,                only : dk => musica_dk
  use musica_string,                   only : string_t

  implicit none
  private

  public :: convert_t

  !> @name Conversion equation types
  !!
  !! The names describe the conversion from standard to non-standard units.
  !! @{

  !> An unspecified conversion
  integer, parameter :: kInvalid = 0
  !> \f$ nonStd = (std + offset) * scale \f$
  integer, parameter :: kOffsetThenScale = 1
  !> \f$ nonStd = std * scale + offset \f$
  integer, parameter :: kScaleThenOffset = 2
  !> \f$ nonStd = ( longitude * scale ) + std \f$
  integer, parameter :: kScaleLongitudeThenOffset = 3
  !> \f$ nonStd = ( std * cellHeight * scale ) + offset \f$
  integer, parameter :: kScaleWithHeightThenOffset = 4

  !> @}

  !> Converts values to and from standard MUSICA units (mks units)
  !!
  !! Create a convert object by providing the standard MUSICA unit for the
  !! property and the unit to convert from (can be standard or non-standard).
  !! Units can be provided as character arrays or \c string_t objects. Units
  !! are case-insensitive.
  !!
  !! Use a convert object by calling the \c to_standard and \c to_non_standard
  !! type-bound functions.
  !!
  !! Convert objects can be used multiple times with different values and can
  !! be re-built for different combinations of units.
  !!
  !! Some conversions require additional information (e.g., conversion between
  !! UTC and local solar time requires a longitude). This information must be
  !! provided or the conversion will fail with an error.
  !!
  !! Example:
  !! \code{F90}
  !!   use musica_constants,                only : dk => musica_dk
  !!   use musica_convert,                  only : convert_t
  !!   use musica_string,                   only : string_t
  !!
  !!   type(convert_t) :: convert
  !!   type(string_t) :: str
  !!   real(kind=dk) :: a, long
  !!
  !!   convert = convert_t( "Pa", "atm" )     ! convert between [Pa] and [atm]
  !!   a = convert%to_standard( 0.915_dk )
  !!   write(*,*) 0.915, " atm is ", a, " Pa"
  !!   a = convert%to_non_standard( 103657.0_dk )
  !!   write(*,*) 103657.0, " Pa is ", a, " atm"
  !!
  !!   str = "Local solar time"
  !!   convert = convert_t( "UTC", str )      ! converts between [UTC] and [LST]
  !!   long = 2.564_dk                        ! a longitude in radians
  !!   a = convert%to_standard( 6.5_dk, longitude__rad = long )
  !!   write(*,*) 6.5_dk, " UTC [s] is ", a, " LST [s] at ", long / 3.14159265359 * 180.0, " deg W"
  !! \endcode
  !! Output:
  !! \code{bash}
  !!   0.915000021      atm is    92712.375000000000       Pa
  !!   103657.000      Pa is    1.0230150505798175       atm
  !!   6.5000000000000000       UTC [s] is    51148.969118829657       LST [s] at    146.90637458350079       deg W
  !! \endcode
  !!
  type :: convert_t
    private
    !> Conversion type
    integer :: conversion_type_ = kInvalid
    !> Scaling factor
    real(kind=dk) :: scale_factor_ = 1.0_dk
    !> Offset
    real(kind=dk) :: offset_ = 0.0_dk
    !> Standard units
    type(string_t) :: standard_units_
  contains
    private
    !> Converts to the standard units
    procedure, public :: to_standard
    !> Converts to the non-standard units
    procedure, public :: to_non_standard
    !> Returns the standard units for this conversion
    procedure, public :: standard_units
    !> @name Private setup functions
    !! @{
    procedure :: set_up_for_UTC
    procedure :: set_up_for_K
    procedure :: set_up_for_Pa
    procedure :: set_up_for_mol_per_m3
    procedure :: set_up_for_s
    procedure :: set_up_for_mol_per_m3_per_s
    procedure :: set_up_for_per_s
    !> @}
  end type convert_t

  ! Constructor for a conversion
  interface convert_t
    procedure :: constructor, constructor_char, constructor_str_char,         &
                 constructor_char_str
  end interface convert_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor that accepts character arrays
  function constructor_char_str( standard_units, non_standard_units )         &
      result( new_obj )


    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    character(len=*), intent(in) :: standard_units
    !> Non-standard units
    type(string_t), intent(in) :: non_standard_units

    type(string_t) :: std

    std     = standard_units
    new_obj = constructor( std, non_standard_units )

  end function constructor_char_str

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor that accepts character arrays
  function constructor_str_char( standard_units, non_standard_units )         &
      result( new_obj )


    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    type(string_t), intent(in) :: standard_units
    !> Non-standard units
    character(len=*), intent(in) :: non_standard_units

    type(string_t) :: non_std

    non_std = non_standard_units
    new_obj = constructor( standard_units, non_std )

  end function constructor_str_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor that accepts character arrays
  function constructor_char( standard_units, non_standard_units )             &
      result( new_obj )


    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    character(len=*), intent(in) :: standard_units
    !> Non-standard units
    character(len=*), intent(in) :: non_standard_units

    type(string_t) :: std, non_std

    std     = standard_units
    non_std = non_standard_units
    new_obj = constructor( std, non_std )

  end function constructor_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor for a conversion
  function constructor( standard_units, non_standard_units ) result( new_obj )

    use musica_assert,                 only : die_msg

    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    type(string_t), intent(in) :: standard_units
    !> Non-standard units
    type(string_t), intent(in) :: non_standard_units

    type(string_t) :: std, non_std

    std                     = standard_units%to_lower( )
    non_std                 = non_standard_units%to_lower( )
    new_obj%standard_units_ = std
    if( std .eq. "utc" ) then
      call new_obj%set_up_for_UTC( non_std )
    else if( std .eq. "k" ) then
      call new_obj%set_up_for_K( non_std )
    else if( std .eq. "pa" ) then
      call new_obj%set_up_for_Pa( non_std )
    else if( std .eq. "mol m-3" ) then
      call new_obj%set_up_for_mol_per_m3( non_std )
    else if( std .eq. "s" ) then
      call new_obj%set_up_for_s( non_std )
    else if( std .eq. "mol m-3 s-1" ) then
      call new_obj%set_up_for_mol_per_m3_per_s( non_std )
    else if( std .eq. "s-1" ) then
      call new_obj%set_up_for_per_s( non_std )
    else
      call die_msg( 224485497,                                                &
                    "Invalid standard units: '"//standard_units%to_char( )    &
                    //"'" )
    end if

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a non-standard value to a standard value
  function to_standard( this, non_standard_value, longitude__rad,             &
      cell_height__m ) result( standard_value )

    use musica_assert,                 only : die_msg

    !> Converted value
    real(kind=dk) :: standard_value
    !> Converter
    class(convert_t), intent(in) :: this
    !> Non-standard value to convert
    real(kind=dk), intent(in) :: non_standard_value
    !> Longitude [radians]
    real(kind=dk), intent(in), optional :: longitude__rad
    !> Surface area [m2]
    real(kind=dk), intent(in), optional :: cell_height__m

    select case( this%conversion_type_ )
      case( kOffsetThenScale )
        standard_value = ( non_standard_value / this%scale_factor_ ) -        &
          this%offset_
      case( kScaleThenOffset )
        standard_value = ( non_standard_value - this%offset_ ) /              &
          this%scale_factor_
      case( kScaleLongitudeThenOffset )
        if( present( longitude__rad ) ) then
          standard_value = mod( non_standard_value -                          &
            ( longitude__rad * this%scale_factor_ ) + this%offset_,           &
            this%offset_ )
        else
          call die_msg( 873956386, "Missing longitude in conversion" )
        end if
      case( kScaleWithHeightThenOffset )
        if( present( cell_height__m ) ) then
          standard_value = ( non_standard_value - this%offset_ ) /            &
            cell_height__m / this%scale_factor_
        else
          call die_msg( 171367003, "Missing surface area in conversion" )
        end if
      case default
        call die_msg( 425135301, "Trying to use uninitialized conversion" )
    end select

  end function  to_standard

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Converts a standard value to a non-standard value
  function to_non_standard( this, standard_value, longitude__rad,             &
      cell_height__m ) result( non_standard_value )

    use musica_assert,                 only : die_msg

    !> Converted value
    real(kind=dk) :: non_standard_value
    !> Converter
    class(convert_t), intent(in) :: this
    !> Standard value to convert
    real(kind=dk), intent(in) :: standard_value
    !> Longitude [radians]
    real(kind=dk), intent(in), optional :: longitude__rad
    !> Surface area [m2]
    real(kind=dk), intent(in), optional :: cell_height__m

    select case( this%conversion_type_ )
      case( kOffsetThenScale )
        non_standard_value = ( standard_value + this%offset_ ) *              &
          this%scale_factor_
      case( kScaleThenOffset )
        non_standard_value = ( standard_value * this%scale_factor_ ) +        &
          this%offset_
      case( kScaleLongitudeThenOffset )
        if( present( longitude__rad ) ) then
          non_standard_value = mod( ( longitude__rad * this%scale_factor_ ) + &
            standard_value + this%offset_, this%offset_ )
        else
          call die_msg( 353861650, "Missing longitude in conversion" )
        end if
      case( kScaleWithHeightThenOffset )
        if( present( cell_height__m ) ) then
          non_standard_value = ( standard_value * cell_height__m *            &
            this%scale_factor_ ) + this%offset_
        else
          call die_msg( 171367003, "Missing surface area in conversion" )
        end if
      case default
        call die_msg( 401171595, "Invalid conversion" )
    end select

  end function to_non_standard

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the standard units for this conversion
  function standard_units( this )

    !> Standard units
    type(string_t) :: standard_units
    !> Conversion
    class(convert_t), intent(in) :: this

    if( this%conversion_type_ .eq. kInvalid ) then
      standard_units = "unknown"
    else
      standard_units = this%standard_units_
    end if

  end function standard_units

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for datetime [UTC]
  subroutine set_up_for_UTC( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_constants,              only : kPi

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    real(kind=dk) :: utc_offset

    if( non_standard .eq. "utc" ) then
      this%conversion_type_ = kScaleThenOffset
      return
    else if( non_standard%substring(1,3) .eq. "utc" ) then
      this%conversion_type_ = kScaleThenOffset
      utc_offset = non_standard%substring(4,10)
      this%offset_ = utc_offset * 3600.0_dk
    else if( non_standard .eq. "local solar time" .or.                        &
             non_standard .eq. "lst" ) then
      this%conversion_type_ = kScaleLongitudeThenOffset
      this%offset_ = 24.0_dk * 60.0_dk * 60.0_dk ! 24 hours in seconds
      this%scale_factor_ = this%offset_ / ( 2.0_dk * kPi )
    else
      call die_msg( 532226526, "Invalid non-standard units for conversion "// &
                    "to UTC: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_UTC

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for temperature [K]
  subroutine set_up_for_K( this, non_standard )

    use musica_assert,                 only : die_msg

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    if( non_standard .eq. "k" ) then
      this%conversion_type_ = kScaleThenOffset
      return
    else if( non_standard .eq. "degrees c" .or.                               &
             non_standard .eq. "deg_c" .or.                                   &
             non_standard .eq. "deg c" .or.                                   &
             non_standard .eq. "°c" .or.                                      &
             non_standard .eq. "℃" .or.                                       &
             non_standard .eq. "c" ) then
      this%conversion_type_ = kScaleThenOffset
      this%offset_ = -273.15_dk
    else if( non_standard .eq. "degrees f" .or.                               &
             non_standard .eq. "deg_f" .or.                                   &
             non_standard .eq. "deg f" .or.                                   &
             non_standard .eq. "°f" .or.                                      &
             non_standard .eq. "℉" .or.                                       &
             non_standard .eq. "f" ) then
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 9.0_dk / 5.0_dk
      this%offset_ = -273.15_dk * 9.0_dk / 5.0_dk + 32_dk
    else
      call die_msg( 565100435, "Invalid non-standard units for conversion "// &
                    "to K: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_K

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for pressure [Pa]
  subroutine set_up_for_Pa( this, non_standard )

    use musica_assert,                 only : die_msg

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    if( non_standard .eq. "pa" ) then
      this%conversion_type_ = kScaleThenOffset
      return
    else if( non_standard .eq. "hpa" .or.                                     &
             non_standard .eq. "mbar" ) then
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 1.0d-2
    else if( non_standard .eq. "kpa" ) then
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 1.0d-3
    else if( non_standard .eq. "atm" ) then
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 1.0_dk / 101325.0_dk
    else if( non_standard .eq. "bar" ) then
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 1.0d-5
    else if( non_standard .eq. "mmhg" .or.                                    &
             non_standard .eq. "torr" ) then
      !> \bug The conversion between torr/mmHg and Pa is approximate
      this%conversion_type_ = kScaleThenOffset
      this%scale_factor_ = 1.0_dk / 133.0_dk
    else
      call die_msg( 268023978, "Invalid non-standard units for conversion "// &
                    "to Pa: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_Pa

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for number concentration [mol m-3]
  subroutine set_up_for_mol_per_m3( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_constants,              only : kAvagadro

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    type(string_t), allocatable :: base_units(:)
    real(kind=dk) :: num_scale, space_scale
    logical :: use_slash

    use_slash = .false.
    base_units = non_standard%split( " " )
    if( size( base_units ) .eq. 1 ) then
      base_units = non_standard%split( "/" )
      use_slash = .true.
    end if

    if( size( base_units ) .eq. 2 ) then
      this%conversion_type_ = kScaleThenOffset
      if( base_units(1) .eq. "mol" .or.                                       &
          base_units(1) .eq. "mole" .or.                                      &
          base_units(1) .eq. "moles" ) then
        num_scale = 1.0_dk
      else if( base_units(1) .eq. "molec" .or.                                &
               base_units(1) .eq. "molecule" .or.                             &
               base_units(1) .eq. "molecules" ) then
        num_scale = kAvagadro
      else
        call die_msg( 209497195, "Invalid non-standard units for conversion " &
                      //"to mol m-3: '"//non_standard%to_char( )//"'" )
      end if
      if( ( base_units(2) .eq. "m-3" .and. .not. use_slash ) .or.             &
          ( base_units(2) .eq. "m3" .and. use_slash ) ) then
        space_scale = 1.0_dk
      else if( ( base_units(2) .eq. "cm-3" .and. .not. use_slash ) .or.       &
               ( base_units(2) .eq. "cm3" .and. use_slash ) ) then
        space_scale = 1.0d6
      else
        call die_msg( 180294779, "Invalid non-standard units for conversion " &
                      //"to mol m-3: '"//non_standard%to_char( )//"'" )
      end if
    else
      call die_msg( 990774023, "Invalid non-standard units for conversion "// &
                    "to mol m-3: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_mol_per_m3

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for time [s]
  subroutine set_up_for_s( this, non_standard )

    use musica_assert,                 only : die_msg

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    this%conversion_type_ = kScaleThenOffset
    if( non_standard .eq. "s" .or.                                            &
        non_standard .eq. "sec" .or.                                          &
        non_standard .eq. "second" .or.                                       &
        non_standard .eq. "seconds" ) then
      return
    else if( non_standard .eq. "m" .or.                                       &
             non_standard .eq. "min" .or.                                     &
             non_standard .eq. "minute" .or.                                  &
             non_standard .eq. "minutes" ) then
      this%scale_factor_ = 1.0_dk / 60.0_dk
    else if( non_standard .eq. "h" .or.                                       &
             non_standard .eq. "hr" .or.                                      &
             non_standard .eq. "hour" .or.                                    &
             non_standard .eq. "hours" ) then
      this%scale_factor_ = 1.0_dk / 60.0_dk / 60.0_dk
    else if( non_standard .eq. "d" .or.                                       &
             non_standard .eq. "day" .or.                                     &
             non_standard .eq. "days" ) then
      this%scale_factor_ = 1.0_dk / 60.0_dk / 60.0_dk / 24.0_dk
    else
      call die_msg( 542240061,"Invalid non-standard units for conversion "//  &
                    "to s: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for emissions rates [mol m-3 s-1]
  subroutine set_up_for_mol_per_m3_per_s( this, non_standard )

    use musica_assert,                 only : die_msg, assert_msg
    use musica_constants,              only : kAvagadro

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    type(string_t), allocatable :: base_units(:)
    real(kind=dk) :: num_scale, space_scale
    logical :: use_slash
    type(convert_t) :: time_convert

    use_slash = .false.
    base_units = non_standard%split( " " )
    if( size( base_units ) .eq. 1 ) then
      base_units = non_standard%split( "/" )
      use_slash = .true.
    end if
    call assert_msg( 960928594, size( base_units ) .eq. 3,                    &
                     "Invalid units for emissions rates: '"//                 &
                     non_standard%to_char( )//"'" )

    ! The last element should be inverse time units
    if( use_slash ) base_units(3) = "1/"//base_units(3)
    call time_convert%set_up_for_per_s( base_units(3) )

    ! Number in moles or molecules
    if( base_units(1) .eq. "mol" .or.                                         &
        base_units(1) .eq. "mole" .or.                                        &
        base_units(1) .eq. "moles" ) then
      num_scale = 1.0_dk
    else if( base_units(1) .eq. "molec" .or.                                  &
             base_units(1) .eq. "molecule" .or.                               &
             base_units(1) .eq. "molecules" ) then
      num_scale = kAvagadro
    else
      call die_msg( 179250665, "Invalid non-standard units for conversion "   &
                    //"to mol m-3: '"//non_standard%to_char( )//"'" )
    end if

    ! Space in m or cm (per surface area or air volume)
    if( ( base_units(2) .eq. "m-3" .and. .not. use_slash ) .or.               &
        ( base_units(2) .eq. "m3" .and. use_slash ) ) then
      this%conversion_type_ = kScaleThenOffset
      space_scale = 1.0_dk
    else if( ( base_units(2) .eq. "cm-3" .and. .not. use_slash ) .or.         &
             ( base_units(2) .eq. "cm3" .and. use_slash ) ) then
      this%conversion_type_ = kScaleThenOffset
      space_scale = 1.0d6
    else if( ( base_units(2) .eq. "m-2" .and. .not. use_slash ) .or.          &
        ( base_units(2) .eq. "m2" .and. use_slash ) ) then
      this%conversion_type_ = kScaleWithHeightThenOffset
      space_scale = 1.0_dk
    else if( ( base_units(2) .eq. "cm-2" .and. .not. use_slash ) .or.         &
             ( base_units(2) .eq. "cm2" .and. use_slash ) ) then
      this%conversion_type_ = kScaleWithHeightThenOffset
      space_scale = 1.0d4
    else
      call die_msg( 173986358, "Invalid non-standard units for conversion "   &
                    //"to mol m-3: '"//non_standard%to_char( )//"'" )
    end if

    ! combined scale factor
    this%scale_factor_ = num_scale / space_scale * time_convert%scale_factor_

  end subroutine set_up_for_mol_per_m3_per_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a conversion for first order decay rate constants [s-1]
  subroutine set_up_for_per_s( this, non_standard )

    use musica_assert,                 only : die_msg, assert_msg

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    integer :: str_len
    type(string_t) :: non_std

    str_len = non_standard%length( )
    if( non_standard%substring(1,2) .eq. "1/" ) then
      non_std = non_standard%substring(3,100)
    else if( non_standard%substring(str_len-1,str_len) .eq. "-1" ) then
      non_std = non_standard%substring(1,str_len-2)
    else
      call die_msg( 219911831, "Invalid non-standard units for conversion "// &
                    "to per s: '"//non_standard%to_char( )//"'" )
    end if
    call set_up_for_s( this, non_std )
    this%scale_factor_ = 1.0_dk / this%scale_factor_

  end subroutine set_up_for_per_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_convert
