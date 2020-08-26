! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_netcdf_variable module

!> The netcdf_variable_t type and related functions
module musica_netcdf_variable

  use musica_constants,                only : musica_dk, musica_ik
  use musica_convert,                  only : convert_t
  use musica_string,                   only : string_t
  use netcdf

  implicit none
  private

  public :: netcdf_variable_t, netcdf_variable_ptr, find_variable_by_name,    &
            find_variable_by_musica_name

  !> A NetCDF variable
  !!
  !! Only variables that have been successfully matched to a MUSICA domain
  !! state variable are allowed. All matching criteria are passed to the
  !! netcdf_variable_t constructor. If a match is found, a new object is
  !! returned.
  !!
  !! The netcdf_variable_t handles all conversions, offsetting, scaling,
  !! etc. and can be used to return sub-sets of the file data during the
  !! simulation in MUSICA units after applying any specified conversions.
  !!
  type :: netcdf_variable_t
    private
    !> Name in the file
    type(string_t) :: name_
    !> Expected MUSICA name
    type(string_t) :: musica_name_
    !> Units for variable in file data
    type(string_t) :: units_
    !> Variable id in file
    integer(kind=musica_ik) :: id_ = -1
    !> Variable dimensions
    integer(kind=musica_ik) :: dimensions_(1) = (/ 0 /)
    !> Converter to MUSICA units
    type(convert_t) :: converter_
    !> Scaling factor
    real(kind=musica_dk) :: scale_factor_ = 1.0_musica_dk
    !> Offset (applied to file data after scaling and before unit conversion)
    real(kind=musica_dk) :: offset_ = 0.0_musica_dk
    !> Shift (applied after unit conversion)
    real(kind=musica_dk) :: shift_ = 0.0_musica_dk
  contains
    !> Returns the NetCDF variable id
    procedure :: id
    !> Returns the name of the variable
    procedure :: name => variable_name
    !> Returns the MUSICA name for the variable
    procedure :: musica_name
    !> Gets the number of entries for the variable in the temporal dimension
    procedure :: time_dimension_size
    !> Gets a sub-set of the variable data for a specified index range
    !!
    !! Data are returned after applying conversions set up during
    !! initialization.
    !!
    procedure :: get_data
    !> Prints the properties of the variable
    procedure :: print => do_print
    !> Sets the NetCDF <-> MUSICA matching criteria
    procedure, private :: set_matching_criteria
    !> Does standard NetCDF -> MUSICA name conversions
    procedure, private :: do_standard_name_conversions
    !> Attempts to match to a MUSICA domain state variable
    procedure, private :: do_match
    !> Sets any specified data adjustments
    procedure, private :: set_adjustments
  end type netcdf_variable_t

  !> Constructor
  interface netcdf_variable_t
    module procedure :: constructor_name, constructor_id
  end interface netcdf_variable_t

  !> Pointer to netcdf_variable_t objects
  type :: netcdf_variable_ptr
    type(netcdf_variable_t), pointer :: val_
  end type netcdf_variable_ptr

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a netcdf_variable_t object for an existing NetCDF variable by name
  !!
  !! If no matching state variable is found in the MUSICA domain, a null
  !! pointer is returned.
  !!
  function constructor_name( domain, file, variable_name, config )            &
      result( new_obj )

    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_netcdf_file,            only : netcdf_file_t

    !> New NetCDF variable
    type(netcdf_variable_t), pointer :: new_obj
    !> MUSICA domain
    class(domain_t), intent(inout) :: domain
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file
    !> Variable name
    character(len=*), intent(in) :: variable_name
    !> Configuration describing how to match to MUSICA variables
    !!
    !! If omitted, standard matching is applied
    class(config_t), intent(inout), optional :: config

    integer(kind=musica_ik) :: variable_id

    call file%check_open( )
    call file%check_status( 542234258,                                        &
        nf90_inq_varid( file%id( ), variable_name, variable_id ),             &
        "Error getting variable id for '"//variable_name//"'" )
      new_obj => constructor_id( domain, file, variable_id, config )

  end function constructor_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a netcdf_variable_t object for an existing NetCDF variable by id
  !!
  !! If no matching state variable is found in the MUSICA domain, a null
  !! pointer is returned.
  !!
  function constructor_id( domain, file, variable_id, config )                &
      result( new_obj )

    use musica_assert,                 only : assert_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_netcdf_file,            only : netcdf_file_t
    use musica_string,                 only : to_char

    !> New NetCDF variable
    type(netcdf_variable_t), pointer :: new_obj
    !> MUSICA domain
    class(domain_t), intent(inout) :: domain
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file
    !> Variable ID
    integer(kind=musica_ik), intent(in) :: variable_id
    !> Configuration describing how to match to MUSICA variables
    !!
    !! If omitted, standard matching is applied
    class(config_t), intent(inout), optional :: config

    character(len=NF90_MAX_NAME) :: name, units
    type(string_t) :: file_name, att_name
    integer(kind=musica_ik) :: dimids(1), n_values, i_att, n_attributes

    allocate( new_obj )
    file_name = file%name( )
    call file%check_open( )
    call file%check_status( 206732462,                                        &
                            nf90_inquire_variable( file%id( ),                &
                                                   variable_id,               &
                                                   name = name,               &
                                                   dimids = dimids,           &
                                                   nAtts = n_attributes ),    &
                            "Error getting variable information for id: "//   &
                            to_char( variable_id )//"'" )
    new_obj%name_  = name
    new_obj%units_ = ""
    new_obj%id_ = variable_id
    call file%check_status( 661270149,                                        &
                            nf90_inquire_dimension( file%id( ),               &
                                                    dimids(1),                &
                                                    len = n_values ),         &
                            "Error getting dimensions of variable '"//        &
                            new_obj%name_%to_char( )//"'" )
    new_obj%dimensions_(1) = n_values
    do i_att = 1, n_attributes
      call file%check_status( 485848938,                                      &
                              nf90_inq_attname( file%id( ),                   &
                                                variable_id,                  &
                                                i_att,                        &
                                                name ),                       &
                              "Error getting attribute "//to_char( i_att )//  &
                              " name for variable '"//                        &
                              new_obj%name_%to_char( )//"'" )
      att_name = trim( name )
      att_name = att_name%to_lower( )
      if( att_name .eq. "units" .or. att_name .eq. "unit" ) then
        call file%check_status( 992960877,                                    &
                                nf90_get_att( file%id( ), new_obj%id_, name,  &
                                              units ),                        &
                                "Error getting units for variable '"//        &
                                new_obj%name_%to_char( )//"'" )
        new_obj%units_ = trim( units )
      end if
    end do
    call assert_msg( 738503497, new_obj%units_ .ne. "",                       &
                     "No units found for variable '"//new_obj%name_%to_char( )&
                     //"' in NetCDF file '"//file_name%to_char( )//"'" )

    call new_obj%set_matching_criteria( config )
    if( .not. new_obj%do_match( domain ) ) then
      deallocate( new_obj )
      new_obj => null( )
    end if
    call new_obj%set_adjustments( file, config )

  end function constructor_id

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the NetCDF variable index
  integer(kind=musica_ik) function id( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this

    id = this%id_

  end function id

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the name of the variable
  type(string_t) function variable_name( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this

    variable_name = this%name_

  end function variable_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the expected MUSICA name for the variable
  type(string_t) function musica_name( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this

    musica_name = this%musica_name_

  end function musica_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the number of entries of the variable in the temporal dimension
  integer(kind=musica_ik) function time_dimension_size( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this

    time_dimension_size = this%dimensions_(1)

  end function time_dimension_size

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets a sub-set of the data from the file
  !!
  !! Conversions are applied in the following order:
  !! - scaling
  !! - offsetting
  !! - conversion to MUSICA units
  !! - shifting
  !!
  subroutine get_data( this, file, start, count, values )

    use musica_netcdf_file,            only : netcdf_file_t

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this
    !> NetCDF file
    class(netcdf_file_t), intent(in) :: file
    !> Starting index for returned data
    integer(kind=musica_ik), intent(in) :: start
    !> Number of data points to return
    integer(kind=musica_ik), intent(in) :: count
    !> Values to return
    real(kind=musica_dk), intent(out) :: values(count)

    integer(kind=musica_ik) :: l_count(1), l_start(1), i_val
    l_start(1) = start
    l_count(1) = count
    call file%check_status( 448163017, nf90_get_var( file%id( ), this%id_,    &
                                                   values, l_start, l_count ),&
                            "Error getting values for variable '"//           &
                            this%name_%to_char( )//"'" )
    do i_val = 1, size( values )
      values( i_val ) = values( i_val ) * this%scale_factor_ + this%offset_
      values( i_val ) = this%converter_%to_standard( values( i_val ) )
      values( i_val ) = values( i_val ) + this%shift_
    end do

  end subroutine get_data

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints the properties of the variable
  subroutine do_print( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(in) :: this

    write(*,*) "*** Variable: "//this%name_%to_char( )//" ***"
    write(*,*) "MUSICA name: "//this%musica_name_%to_char( )
    write(*,*) "NetCDF variable id:", this%id_
    write(*,*) "dimension sizes:", this%dimensions_
    write(*,*) "units: "//this%units_%to_char( )
    write(*,*) "scale factor:", this%scale_factor_
    write(*,*) "offset:", this%offset_
    write(*,*) "shift:", this%shift_

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up matching between MUSICA and NetCDF variables
  subroutine set_matching_criteria( this, config )

    use musica_config,                 only : config_t

    !> NetCDF variable
    class(netcdf_variable_t), intent(inout) :: this
    !> Configuration describing how to match to MUSICA variables
    !!
    !! If omitted, standard matching is applied
    class(config_t), intent(inout), optional :: config

    character(len=*), parameter :: my_name = "NetCDF variable matching"
    type(config_t) :: vars, var_data
    logical :: found, general_match

    ! default to NetCDF variable name
    this%musica_name_ = this%name_

    ! get specific property matching if present
    call config%get( "properties", vars, my_name, found = found )

    ! look for specific and then general variable information
    general_match = .false.
    if( found ) then
      call vars%get( this%name_%to_char( ), var_data, my_name, found = found )
      if( .not. found ) then
        call vars%get( "*", var_data, my_name, found = found )
        general_match = found
      end if
      call vars%finalize( )
    end if

    ! update matching criteria as specified in configuration
    if( found ) then
      call var_data%get( "MusicBox name", this%musica_name_, my_name,       &
                         default = this%musica_name_ )
      call var_data%get( "units", this%units_, my_name,                     &
                         default = this%units_%to_char( ) )
      call var_data%finalize( )
      if( general_match ) then
        this%musica_name_ = this%musica_name_%replace( "*",                   &
                                                       this%name_%to_char( ) )
      end if
    end if

    ! do standard name conversions
    call this%do_standard_name_conversions( )

  end subroutine set_matching_criteria

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Does standard name conversions between NetCDF and MUSICA
  subroutine do_standard_name_conversions( this )

    !> NetCDF variable
    class(netcdf_variable_t), intent(inout) :: this

    associate( str => this%musica_name_ )
      str = str%replace( "CONC.", "chemical_species%" )
      str = str%replace( "ENV.",  "" )
      str = str%replace( "EMIS.", "emission_rates%" )
      str = str%replace( "LOSS.", "loss_rate_constants%" )
      str = str%replace( "PHOT.", "photolysis_rate_constants%" )
    end associate

  end subroutine do_standard_name_conversions

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Attempts to find the variable in the MUSICA domain or create the variable
  !! in the domain for certain input variables.
  !!
  logical function do_match( this, domain )

    use musica_domain,                 only : domain_t

    !> NetCDF variable
    class(netcdf_variable_t), intent(inout) :: this
    !> MUSICA domain
    class(domain_t), intent(inout) :: domain

    character(len=*), parameter :: my_name = "NetCDF variable matcher"

    ! create state variables for emissions and loss rates
    if( this%musica_name_%substring( 1, 15 ) .eq. "emission_rates%" ) then
      call domain%register_cell_state_variable( this%musica_name_%to_char( ), & !- state variable name
                                                "mol m-3 s-1",                & !- MUSICA units
                                                0.0d0,                        & !- default units
                                                my_name )
    else if( this%musica_name_%substring( 1, 20 )                             &
             .eq. "loss_rate_constants%" ) then
      call domain%register_cell_state_variable( this%musica_name_%to_char( ), & !- state variable name
                                                "s-1",                        & !- MUSICA units
                                                0.0d0,                        & !- default value
                                                my_name )
    end if

    ! look for state variables
    do_match = domain%is_cell_state_variable( this%musica_name_%to_char( ) )

    ! look for standard MUSICA dimensions and set up conversions
    if( .not. do_match ) then
      if( this%musica_name_ .eq. "time" ) then
        do_match = .true.
        this%converter_ = convert_t( "s", this%units_ )
      end if
    else
      this%converter_ = convert_t(                                            &
        domain%cell_state_units( this%musica_name_%to_char( ) ), this%units_ )
    end if

  end function do_match

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets any specified data adjustments
  subroutine set_adjustments( this, file, config )

    use musica_assert,                 only : assert_msg
    use musica_config,                 only : config_t
    use musica_datetime,               only : datetime_t
    use musica_netcdf_file,            only : netcdf_file_t

    !> NetCDF variable
    class(netcdf_variable_t), intent(inout) :: this
    !> NetCDF file
    class(netcdf_file_t), intent(in) :: file
    !> Configuration data
    type(config_t), intent(inout) :: config

    character(len=*), parameter :: my_name = "NetCDF variable adjustments"
    type(config_t) :: vars, var_data, shift_data
    logical :: found
    real(kind=musica_dk) :: values(1)
    type(datetime_t) :: shift
    type(string_t) :: units

    ! get specific property data if present
    call config%get( "properties", vars, my_name, found = found )

    ! look for specific and then general variable information
    if( found ) then
      call vars%get( this%name_%to_char( ), var_data, my_name, found = found )
      if( .not. found ) then
        call vars%get( "*", var_data, my_name, found = found )
      end if
      call vars%finalize( )
    end if

    ! update matching criteria as specified in configuration
    if( found ) then
      call var_data%get( "shift first entry to", shift_data, my_name,         &
                         found = found )
      if( found ) then
        units = this%converter_%standard_units( )
        ! for now, just handle time shifts
        call assert_msg( 850243996, units .eq. "s",                           &
                         "Data shifts are not currently supported for "//     &
                         "units of: "//units%to_char( ) )
        call this%get_data( file, 1, 1, values )
        shift = datetime_t( shift_data )
        this%shift_ = shift%in_seconds( ) - values(1)
        call shift_data%finalize( )
      end if
      call var_data%finalize( )
    end if

  end subroutine set_adjustments

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finds a NetCDF variable by name in a set of variables
  !!
  !! Variable matching is case-insensitive
  !!
  function find_variable_by_name( set, name, found ) result( var_id )

    !> Index of variable in set (-1 if not found)
    integer(musica_ik) :: var_id
    !> Set of NetCDF variables
    class(netcdf_variable_t), intent(in) :: set(:)
    !> Variable name to locate
    type(string_t), intent(in) :: name
    !> Flag indicating whether variable was found
    logical, intent(out), optional :: found

    type(string_t) :: l_name, var_name

    l_name = name%to_lower( )
    do var_id = 1, size( set )
      if( set( var_id )%name_%to_lower( ) .eq. l_name ) then
        if( present( found ) ) found = .true.
        return
      end if
    end do
    if( present( found ) ) found = .false.

  end function find_variable_by_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finds a NetCDF variable id by its expected MUSICA name
  !!
  !! Variable matching is case-insensitive
  !!
  function find_variable_by_musica_name( set, name, found ) result( var_id )

    !> Index of variable in set (-1 if not found)
    integer(musica_ik) :: var_id
    !> Set of NetCDF variables
    class(netcdf_variable_t), intent(in) :: set(:)
    !> Domain variable name to locate
    type(string_t), intent(in) :: name
    !> Flag indicating whether variable was found
    logical, intent(out), optional :: found

    type(string_t) :: l_name, musica_name

    l_name = name%to_lower( )
    do var_id = 1, size( set )
      if( set( var_id )%musica_name_%to_lower( ) .eq. l_name ) then
        if( present( found ) ) found = .true.
        return
      end if
    end do
    if( present( found ) ) found = .false.

  end function find_variable_by_musica_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_netcdf_variable
