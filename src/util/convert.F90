!> \file
!> The musica_convert module

!> The convert_t type and related functions for conversion between standard
!! and non-standard MUSICA units
module musica_convert

  use musica_constants,                only : musica_dk

  implicit none
  private

  public :: convert_t

  !> @defgroup convert_eq_types Conversion equation types
  !!
  !! The names describe the conversion from standard to non-standard units.
  !! @{

  !> An unspecified conversion
  integer, parameter :: CONV_INVALID = 0
  !> \f$ nonStd = (std + offset) * scale \f$
  integer, parameter :: CONV_OFFSET_THEN_SCALE = 1
  !> \f$ nonStd = std * scale + offset \f$
  integer, parameter :: CONV_SCALE_THEN_OFFSET = 2
  !> \f$ nonStd = ( longitude * scale ) + std \f$
  integer, parameter :: CONV_SCALE_LONGITUDE_THEN_MOD_OFFSET = 3
  !> \f$ nonStd = ( std * cellHeight * scale ) + offset \f$
  integer, parameter :: CONV_SCALE_WITH_HEIGHT_THEN_OFFSET = 4

  !> @}

  !> Conversion to and from standard MUSICA units
  type :: convert_t
    private
    !> Conversion type
    integer :: conversion_type_ = CONV_INVALID
    !> Scaling factor
    real(kind=musica_dk) :: scale_factor_ = 1.0d0
    !> Offset
    real(kind=musica_dk) :: offset_ = 0.0d0
  contains
    !> Convert to the standard units
    procedure, public :: to_standard
    !> Convert to the non-standard units
    procedure, public :: to_non_standard
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

  !> Constructor for a conversion
  interface convert_t
    procedure :: constructor, constructor_char
  end interface convert_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor that accepts character arrays
  function constructor_char( standard_units, non_standard_units )             &
      result( new_obj )

    use musica_string,                 only : string_t

    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    character(len=*), intent(in) :: standard_units
    !> Non-standard units
    character(len=*), intent(in) :: non_standard_units

    type(string_t) :: std, non_std

    std = standard_units
    non_std = non_standard_units

    new_obj = constructor( std, non_std )

  end function constructor_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor for a conversion
  function constructor( standard_units, non_standard_units ) result( new_obj )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> New conversion
    type(convert_t) :: new_obj
    !> Standard units
    type(string_t), intent(in) :: standard_units
    !> Non-standard units
    type(string_t), intent(in) :: non_standard_units

    type(string_t) :: std, non_std

    std     = standard_units%to_lower( )
    non_std = non_standard_units%to_lower( )

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

  !> Convert a non-standard value to a standard value
  function to_standard( this, non_standard_value, longitude__rad,             &
      cell_height__m ) result( standard_value )

    use musica_assert,                 only : die_msg

    !> Converted value
    real(kind=musica_dk) :: standard_value
    !> Converter
    class(convert_t), intent(in) :: this
    !> Non-standard value to convert
    real(kind=musica_dk), intent(in) :: non_standard_value
    !> Longitude [radians]
    real(kind=musica_dk), intent(in), optional :: longitude__rad
    !> Surface area [m2]
    real(kind=musica_dk), intent(in), optional :: cell_height__m

    select case( this%conversion_type_ )
      case( CONV_OFFSET_THEN_SCALE )
        standard_value = ( non_standard_value / this%scale_factor_ ) -        &
          this%offset_
      case( CONV_SCALE_THEN_OFFSET )
        standard_value = ( non_standard_value - this%offset_ ) /              &
          this%scale_factor_
      case( CONV_SCALE_LONGITUDE_THEN_MOD_OFFSET )
        if( present( longitude__rad ) ) then
          standard_value = mod( non_standard_value -                          &
            ( longitude__rad * this%scale_factor_ ) + this%offset_,           &
            this%offset_ )
        else
          call die_msg( 873956386, "Missing longitude in conversion" )
        end if
      case( CONV_SCALE_WITH_HEIGHT_THEN_OFFSET )
        if( present( cell_height__m ) ) then
          standard_value = ( non_standard_value - this%offset_ ) /            &
            cell_height__m / this%scale_factor_
        else
          call die_msg( 171367003, "Missing surface area in conversion" )
        end if
      case default
        call die_msg( 425135301, "Invalid conversion" )
    end select

  end function  to_standard

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Convert a standard value to a non-standard value
  function to_non_standard( this, standard_value, longitude__rad,             &
      cell_height__m ) result( non_standard_value )

    use musica_assert,                 only : die_msg

    !> Converted value
    real(kind=musica_dk) :: non_standard_value
    !> Converter
    class(convert_t), intent(in) :: this
    !> Standard value to convert
    real(kind=musica_dk), intent(in) :: standard_value
    !> Longitude [radians]
    real(kind=musica_dk), intent(in), optional :: longitude__rad
    !> Surface area [m2]
    real(kind=musica_dk), intent(in), optional :: cell_height__m

    select case( this%conversion_type_ )
      case( CONV_OFFSET_THEN_SCALE )
        non_standard_value = ( standard_value + this%offset_ ) *              &
          this%scale_factor_
      case( CONV_SCALE_THEN_OFFSET )
        non_standard_value = ( standard_value * this%scale_factor_ ) +        &
          this%offset_
      case( CONV_SCALE_LONGITUDE_THEN_MOD_OFFSET )
        if( present( longitude__rad ) ) then
          non_standard_value = mod( ( longitude__rad * this%scale_factor_ ) + &
            standard_value + this%offset_, this%offset_ )
        else
          call die_msg( 353861650, "Missing longitude in conversion" )
        end if
      case( CONV_SCALE_WITH_HEIGHT_THEN_OFFSET )
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

  !> Set up a conversion for datetime [UTC]
  subroutine set_up_for_UTC( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_constants,              only : PI
    use musica_string,                 only : string_t

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    real(kind=musica_dk) :: utc_offset

    if( non_standard .eq. "utc" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      return
    else if( non_standard%substring(1,3) .eq. "utc" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      utc_offset = non_standard%substring(4,10)
      this%offset_ = utc_offset * 3600.0d0
    else if( non_standard .eq. "local solar time" .or.                        &
             non_standard .eq. "lst" ) then
      this%conversion_type_ = CONV_SCALE_LONGITUDE_THEN_MOD_OFFSET
      this%offset_ = 24.0d0 * 60.0d0 * 60.0d0 ! 24 hours in seconds
      this%scale_factor_ = this%offset_ / ( 2.0d0 * PI )
    else
      call die_msg( 532226526, "Invalid non-standard units for conversion "// &
                    "to UTC: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_UTC

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set up a conversion for temperature [K]
  subroutine set_up_for_K( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    if( non_standard .eq. "k" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      return
    else if( non_standard .eq. "degrees c" .or.                               &
             non_standard .eq. "deg_c" .or.                                   &
             non_standard .eq. "deg c" .or.                                   &
             non_standard .eq. "°c" .or.                                      &
             non_standard .eq. "℃" .or.                                       &
             non_standard .eq. "c" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%offset_ = -273.15d0
    else if( non_standard .eq. "degrees f" .or.                               &
             non_standard .eq. "deg_f" .or.                                   &
             non_standard .eq. "deg f" .or.                                   &
             non_standard .eq. "°f" .or.                                      &
             non_standard .eq. "℉" .or.                                       &
             non_standard .eq. "f" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 9.0d0 / 5.0d0
      this%offset_ = -273.15d0 * 9.0d0 / 5.0d0 + 32d0
    else
      call die_msg( 565100435, "Invalid non-standard units for conversion "// &
                    "to K: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_K

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set up a conversion for pressure [Pa]
  subroutine set_up_for_Pa( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    if( non_standard .eq. "pa" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      return
    else if( non_standard .eq. "hpa" .or.                                     &
             non_standard .eq. "mbar" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 1.0d-2
    else if( non_standard .eq. "kpa" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 1.0d-3
    else if( non_standard .eq. "atm" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 1.0d0 / 101325.0d0
    else if( non_standard .eq. "bar" ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 1.0d-5
    else if( non_standard .eq. "mmhg" .or.                                    &
             non_standard .eq. "torr" ) then
      !> \bug The conversion between torr/mmHg and Pa is approximate
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      this%scale_factor_ = 1.0d0 / 133.0d0
    else
      call die_msg( 268023978, "Invalid non-standard units for conversion "// &
                    "to Pa: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_Pa

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set up a conversion for number concentration [mol m-3]
  subroutine set_up_for_mol_per_m3( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_constants,              only : AVAGADRO
    use musica_string,                 only : string_t

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    type(string_t), allocatable :: base_units(:)
    real(kind=musica_dk) :: num_scale, space_scale
    logical :: use_slash

    use_slash = .false.
    base_units = non_standard%split( " " )
    if( size( base_units ) .eq. 1 ) then
      base_units = non_standard%split( "/" )
      use_slash = .true.
    end if

    if( size( base_units ) .eq. 2 ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      if( base_units(1) .eq. "mol" .or.                                       &
          base_units(1) .eq. "mole" .or.                                      &
          base_units(1) .eq. "moles" ) then
        num_scale = 1.0d0
      else if( base_units(1) .eq. "molec" .or.                                &
               base_units(1) .eq. "molecule" .or.                             &
               base_units(1) .eq. "molecules" ) then
        num_scale = AVAGADRO
      else
        call die_msg( 209497195, "Invalid non-standard units for conversion " &
                      //"to mol m-3: '"//non_standard%to_char( )//"'" )
      end if
      if( ( base_units(2) .eq. "m-3" .and. .not. use_slash ) .or.             &
          ( base_units(2) .eq. "m3" .and. use_slash ) ) then
        space_scale = 1.0d0
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

  !> Set up a conversion for time [s]
  subroutine set_up_for_s( this, non_standard )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    this%conversion_type_ = CONV_SCALE_THEN_OFFSET
    if( non_standard .eq. "s" .or.                                            &
        non_standard .eq. "sec" .or.                                          &
        non_standard .eq. "second" .or.                                       &
        non_standard .eq. "seconds" ) then
      return
    else if( non_standard .eq. "m" .or.                                       &
             non_standard .eq. "min" .or.                                     &
             non_standard .eq. "minute" .or.                                  &
             non_standard .eq. "minutes" ) then
      this%scale_factor_ = 1.0d0 / 60.0d0
    else if( non_standard .eq. "h" .or.                                       &
             non_standard .eq. "hr" .or.                                      &
             non_standard .eq. "hour" .or.                                    &
             non_standard .eq. "hours" ) then
      this%scale_factor_ = 1.0d0 / 60.0d0 / 60.0d0
    else if( non_standard .eq. "d" .or.                                       &
             non_standard .eq. "day" .or.                                     &
             non_standard .eq. "days" ) then
      this%scale_factor_ = 1.0d0 / 60.0d0 / 60.0d0 / 24.0d0
    else
      call die_msg( 542240061,"Invalid non-standard units for conversion "//  &
                    "to s: '"//non_standard%to_char( )//"'" )
    end if

  end subroutine set_up_for_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set up a conversion for emissions rates [mol m-3 s-1]
  subroutine set_up_for_mol_per_m3_per_s( this, non_standard )

    use musica_assert,                 only : die_msg, assert_msg
    use musica_constants,              only : AVAGADRO
    use musica_string

    !> Converter
    class(convert_t), intent(inout) :: this
    !> Non-standard units
    type(string_t), intent(in) :: non_standard

    type(string_t), allocatable :: base_units(:)
    real(kind=musica_dk) :: num_scale, space_scale
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
      num_scale = 1.0d0
    else if( base_units(1) .eq. "molec" .or.                                  &
             base_units(1) .eq. "molecule" .or.                               &
             base_units(1) .eq. "molecules" ) then
      num_scale = AVAGADRO
    else
      call die_msg( 179250665, "Invalid non-standard units for conversion "   &
                    //"to mol m-3: '"//non_standard%to_char( )//"'" )
    end if

    ! Space in m or cm (per surface area or air volume)
    if( ( base_units(2) .eq. "m-3" .and. .not. use_slash ) .or.               &
        ( base_units(2) .eq. "m3" .and. use_slash ) ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      space_scale = 1.0d0
    else if( ( base_units(2) .eq. "cm-3" .and. .not. use_slash ) .or.         &
             ( base_units(2) .eq. "cm3" .and. use_slash ) ) then
      this%conversion_type_ = CONV_SCALE_THEN_OFFSET
      space_scale = 1.0d6
    else if( ( base_units(2) .eq. "m-2" .and. .not. use_slash ) .or.          &
        ( base_units(2) .eq. "m2" .and. use_slash ) ) then
      this%conversion_type_ = CONV_SCALE_WITH_HEIGHT_THEN_OFFSET
      space_scale = 1.0d0
    else if( ( base_units(2) .eq. "cm-2" .and. .not. use_slash ) .or.         &
             ( base_units(2) .eq. "cm2" .and. use_slash ) ) then
      this%conversion_type_ = CONV_SCALE_WITH_HEIGHT_THEN_OFFSET
      space_scale = 1.0d4
    else
      call die_msg( 173986358, "Invalid non-standard units for conversion "   &
                    //"to mol m-3: '"//non_standard%to_char( )//"'" )
    end if

    ! combined scale factor
    this%scale_factor_ = num_scale / space_scale * time_convert%scale_factor_

  end subroutine set_up_for_mol_per_m3_per_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Set up a conversion for first order decay rate constants [s-1]
  subroutine set_up_for_per_s( this, non_standard )

    use musica_assert,                 only : die_msg, assert_msg
    use musica_string,                 only : string_t

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
    this%scale_factor_ = 1.0d0 / this%scale_factor_

  end subroutine set_up_for_per_s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_convert
