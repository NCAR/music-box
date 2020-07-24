! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_config module

!> The config_t type and related functions
module musica_config

  use json_module,                     only : json_file, json_value, json_core
  use musica_constants,                only : musica_ik, musica_rk, musica_dk
  use musica_iterator,                 only : iterator_t

  implicit none
  private

  public :: config_t

  !> Wrapper for configuration data
  !!
  !! It is assumed that most configuration datasets will be small enough that
  !! returning subsets of configuration data can just make a copy of the original
  !! data (instead of using a pointer to the start of the subset in the original
  !! dataset, or something like this). This avoids ownership problems with
  !! cleaning up the memory after a config_t object goes out of scope.
  type :: config_t
    private
    !> JSON core
    type(json_core) :: core_
    !> JSON value
    type(json_value), pointer :: value_ => null( )
  contains
    !> Empty the configuration
    procedure :: empty
    !> Load a configuration with data from a file
    procedure :: from_file => construct_from_file
    !> Get an iterator for the configuration data
    procedure :: get_iterator
    !> Get the key name for a key-value pair
    procedure :: key
    !> Get some configuration data
    !!
    !! Each function includes optional \c found and \c default arguments. If
    !! neither is included and the data are not found, execution is stopped
    !! with an error message.
    !!
    !! If a \c default value is included and the data are not found, the
    !! returned argument is set to this default value, otherwise it is set to
    !! a standard default value.
    !!
    !! If the \c found argument is included and the data are found, \c found
    !! is set to \c true, otherwise it is set to \c false.
    !! @{
    procedure, private :: get_config
    procedure, private :: get_string_string_default
    procedure, private :: get_string
    procedure, private :: get_property
    procedure, private :: get_int
    procedure, private :: get_float
    procedure, private :: get_double
    procedure, private :: get_logical
    procedure, private :: get_string_array
    procedure, private :: get_from_iterator
    procedure, private :: get_property_from_iterator
    procedure, private :: get_array_from_iterator
    generic :: get => get_config, get_string, get_string_string_default,      &
                      get_property, get_int, get_float, get_double,           &
                      get_logical, get_string_array, get_from_iterator,       &
                      get_property_from_iterator, get_array_from_iterator
    !> @}
    !> Add a named piece of configuration data
    !! @{
    procedure, private :: add_config
    procedure, private :: add_char_array
    procedure, private :: add_string
    procedure, private :: add_property
    procedure, private :: add_int
    procedure, private :: add_float
    procedure, private :: add_double
    procedure, private :: add_logical
    procedure, private :: add_string_array
    generic :: add => add_config, add_char_array, add_string, add_property,  &
                      add_int, add_float, add_double, add_logical,           &
                      add_string_array
    !> @}
    !> Assignment
    !! @{
    procedure, private :: config_assign_config
    procedure, private :: config_assign_string
    procedure, private :: config_assign_char
    procedure, private, pass(config) :: string_assign_config
    generic :: assignment(=) => config_assign_config, config_assign_string,   &
                                config_assign_char, string_assign_config
    !> @}
    !> Clean up memory
    !! \bug There is a compiler bug in gfortran preventing this from being a
    !! final procedure. (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=91648)
    !! Update once fixed and add constructors
    procedure :: finalize
    !> Find a JSON key by prefix
    procedure, private :: find_by_prefix
  end type config_t

  !> Configuration data iterator
  type, extends(iterator_t) :: config_iterator_t
    !> Pointer to the configuration data
    class(config_t), pointer :: config_ => null( )
    !> Current index in the data set
    integer(kind=musica_ik) :: id_ = 0
  contains
    !> Advance to the next key-value pair
    procedure :: next => iterator_next
    !> Reset the iterator
    procedure :: reset => iterator_reset
  end type config_iterator_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Empty the configuration
  subroutine empty( this )

    !> Configuration
    class(config_t), intent(inout) :: this

    call this%finalize( )
    call this%core_%initialize( )
    call this%core_%create_object( this%value_, "" )

  end subroutine empty

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Construct a configuration from a file
  subroutine construct_from_file( this, file_name )

    use json_module,                   only : json_ck
    use musica_assert,                 only : assert_msg

    !> New configuration
    class(config_t), intent(inout) :: this
    !> File name containing configuration data
    character(len=*), intent(in) :: file_name

    type(json_file) :: file
    type(json_core) :: core
    type(json_value), pointer :: j_obj
    character(kind=json_ck, len=:), allocatable :: json_string, error_message
    logical :: found, valid

    call this%finalize( )

    call file%initialize( )
    call file%load_file( filename = file_name )
    call file%get_core( core )
    call file%get( '', j_obj, found = found )

    call assert_msg( 156963713, found, "Invalid top-level object in '"//      &
                     trim( file_name )//"'" )

    call core%validate( j_obj, valid, error_message )
    if( .not. allocated( error_message ) ) error_message = ""
    call assert_msg( 282316049, valid, "Invalid JSON structure in '"//        &
                     trim( file_name )//"': "//trim( error_message ) )

    call core%print_to_string( j_obj, json_string )
    this = json_string

    call file%destroy( )

  end subroutine construct_from_file

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an interator for the configuration data
  function get_iterator( this )

    !> Pointer to the iterator
    class(iterator_t), pointer :: get_iterator
    !> Configuration
    class(config_t), intent(in), target :: this

    allocate( config_iterator_t :: get_iterator )
    select type( iter => get_iterator )
      type is( config_iterator_t )
        iter%config_ => this
    end select

  end function get_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the key name using an iterator
  function key( this, iterator )

    use json_module,                   only : json_ck, json_ik
    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Key name
    type(string_t) :: key
    !> Configuration
    class(config_t), intent(inout) :: this
    !> Configuration iterator
    class(iterator_t), intent(in) :: iterator

    type(json_value), pointer :: j_obj
    character(kind=json_ck, len=:), allocatable :: j_key

    select type( iterator )
      class is( config_iterator_t )
        call this%core_%get_child( this%value_,                               &
                                   int( iterator%id_, kind=json_ik ), j_obj )
        call this%core_%info( j_obj, name = j_key )
        key = j_key
      class default
        call die_msg( 789668190, "Iterator type mismatch. Expected "//        &
                      "config_iterator_t" )
    end select

  end function key

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a subset of the configuration data
  subroutine get_config( this, key, value, caller, default, found )

    use json_module,                   only : json_lk, json_ck
    use musica_assert,                 only : assert_msg

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    class(config_t), intent(inout) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    class(config_t), intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    type(json_value), pointer :: j_obj
    logical(kind=json_lk) :: l_found
    character(kind=json_ck, len=:), allocatable :: str_tmp

    call value%finalize( )
    call this%core_%get( this%value_, key, j_obj, l_found )

    call assert_msg( 202757635, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( l_found ) then
      call this%core_%print_to_string( j_obj, str_tmp )
      call this%core_%destroy( value%value_ )
      call this%core_%parse( value%value_, str_tmp )
    else
      if( present( default ) ) then
        value = default
      else
        value = ""
      end if
    end if

  end subroutine get_config

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a string from the configuration data
  subroutine get_string_string_default( this, key, value, caller, default,    &
      found )

    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    class(string_t), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    class(string_t), intent(in) :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    call get_string( this, key, value, caller, default%val_, found )

  end subroutine get_string_string_default

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a string from the configuration data
  subroutine get_string( this, key, value, caller, default, found )

    use json_module,                   only : json_lk
    use musica_assert,                 only : assert_msg
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    class(string_t), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    character(len=*), intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    type(json_value), pointer :: j_obj
    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, value%val_, l_found )

    call assert_msg( 506864358, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( .not. l_found ) then
      if( present( default ) ) then
        value = default
      else
        value = ""
      end if
    end if

  end subroutine get_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a property from the configuration data
  subroutine get_property( this, key, units, value, caller, default, found )

    use json_module,                   only : json_ck, json_lk, json_rk
    use musica_assert,                 only : assert_msg
    use musica_convert,                only : convert_t
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Units for the property
    character(len=*), intent(in) :: units
    !> Returned value
    real(kind=musica_dk), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    real(kind=musica_dk), intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    type(string_t) :: full_key
    real(kind=musica_dk) :: tmp_val
    type(json_value), pointer :: j_obj
    logical(kind=json_lk) :: l_found
    type(convert_t) :: convert

    call this%find_by_prefix( key, this%value_, j_obj, full_key, l_found )

    if( l_found ) then
      call this%core_%get( j_obj, tmp_val )
    end if

    call assert_msg( 501600051, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( l_found ) then
      convert = convert_t( units, get_property_units( full_key%val_ ) )
      value = convert%to_standard( tmp_val )
    else
      if( present( default ) ) then
        value = default
      else
        value = 0.0d0
      end if
    end if

  end subroutine get_property

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an integer from the configuration data
  subroutine get_int( this, key, value, caller, default, found )

    use json_module,                   only : json_lk
    use musica_assert,                 only : assert_msg

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    integer, intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    integer, intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, value, l_found )

    call assert_msg( 168054983, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( .not. l_found ) then
      if( present( default ) ) then
        value = default
      else
        value = 0
      end if
    end if

  end subroutine get_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a single-precision real number from the configuration data
  subroutine get_float( this, key, value, caller, default, found )

    use json_module,                   only : json_lk, json_rk
    use musica_assert,                 only : assert_msg

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    real(kind=musica_rk), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    real(kind=musica_rk), intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    real(kind=json_rk) :: tmp_value
    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, tmp_value, l_found )

    call assert_msg( 497840177, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    value = tmp_value
    if( present( found ) ) found = l_found

    if( .not. l_found ) then
      if( present( default ) ) then
        value = default
      else
        value = 0.0
      end if
    end if

  end subroutine get_float

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!> Get a double-precision real number from the configuration data
  subroutine get_double( this, key, value, caller, default, found )

    use json_module,                   only : json_lk
    use musica_assert,                 only : assert_msg

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    real(kind=musica_dk), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    real(kind=musica_dk), intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, value, l_found )

    call assert_msg( 273655782, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( .not. l_found ) then
      if( present( default ) ) then
        value = default
      else
        value = 0.0d0
      end if
    end if

  end subroutine get_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a boolean value from the configuration data
  subroutine get_logical( this, key, value, caller, default, found )

    use json_module,                   only : json_lk
    use musica_assert,                 only : assert_msg

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    logical, intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    logical, intent(in), optional :: default
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, value, l_found )

    call assert_msg( 714306082, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( .not. l_found ) then
      if( present( default ) ) then
        value = default
      else
        value = .false.
      end if
    end if

  end subroutine get_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an array of strings from the configuration data
  subroutine get_string_array( this, key, value, caller, default, found )

    use json_module,                   only : json_ik, json_lk
    use musica_assert,                 only : assert_msg
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key used to find value
    character(len=*), intent(in) :: key
    !> Returned value
    type(string_t), allocatable, intent(out) :: value(:)
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller
    !> Default value if not found
    type(string_t), intent(in), optional :: default(:)
    !> Flag indicating whether key was found
    logical, intent(out), optional :: found

    type(json_value), pointer :: j_obj, child, next
    integer(kind=json_ik) :: n_child, i_string
    logical(kind=json_lk) :: l_found

    call this%core_%get( this%value_, key, j_obj, l_found )
    if( l_found ) then
      call this%core_%info( j_obj, n_children = n_child )
      allocate( value( n_child ) )
    end if

    call assert_msg( 640725796, l_found .or. present( default )               &
                     .or. present( found ), "Key '"//trim( key )//            &
                     "' requested by "//trim( caller )//" not found" )

    if( present( found ) ) found = l_found

    if( l_found ) then
      child => null( )
      next  => null( )
      i_string = 1
      call this%core_%get_child( j_obj, child )
      do while( associated( child ) )
        call this%core_%get( child, value( i_string )%val_ )
        call this%core_%get_next( child, next )
        child => next
        i_string = i_string + 1
      end do
    else
      if( present( default ) ) then
        value = default
      end if
    end if

  end subroutine get_string_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a value using an iterator
  !!
  !! \todo the get functions should be changed so that the search by name
  !!       functions call search by index functions
  subroutine get_from_iterator( this, iterator, value, caller )

    use json_module,                   only : json_ck
    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Iterator to use to find value
    class(iterator_t), intent(in) :: iterator
    !> Returned value
    class(*), intent(out) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    type(json_value), pointer :: j_obj
    character(kind=json_ck, len=:), allocatable :: key

    select type( iterator )
      class is( config_iterator_t )
        call this%core_%get_child( this%value_, iterator%id_, j_obj )
        call this%core_%info( j_obj, name = key )
        select type( value )
          type is( config_t )
            call this%get_config( key, value, caller )
          type is( integer( musica_ik ) )
            call this%get_int( key, value, caller )
          type is( real( musica_rk ) )
            call this%get_float( key, value, caller )
          type is( real( musica_dk ) )
            call this%get_double( key, value, caller )
          type is( logical )
            call this%get_logical( key, value, caller )
          type is( string_t )
            call this%get_string( key, value, caller )
          class default
            call die_msg( 898465007, "Unknown type for get function." )
        end select
      class default
        call die_msg( 888551443, "Iterator type mismatch. Expected "//        &
                      "config_iterator_t" )
    end select

  end subroutine get_from_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a property value using an iterator
  !!
  !! \todo the get functions should be changed so that the search by name
  !!       functions call search by index functions
  subroutine get_property_from_iterator( this, iterator, units, ret_val,      &
      caller )

    use json_module,                   only : json_ck, json_rk
    use musica_assert,                 only : die_msg
    use musica_convert,                only : convert_t
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Iterator to use to find value
    class(iterator_t), intent(in) :: iterator
    !> Standard units for the property
    character(len=*), intent(in) :: units
    !> Returned value
    real(kind=musica_dk), intent(out) :: ret_val
    !> Name of the calling function (only used for error messages)
    character(len=*), intent(in) :: caller

    type(json_value), pointer :: j_obj
    character(kind=json_ck, len=:), allocatable :: key
    real(json_rk) :: tmp_val
    type(convert_t) :: convert

    select type( iterator )
      class is( config_iterator_t )
        call this%core_%get_child( this%value_, iterator%id_, j_obj )
        call this%core_%info( j_obj, name = key )
        call this%core_%get( j_obj, tmp_val )
        convert = convert_t( units, get_property_units( key ) )
        ret_val = convert%to_standard( tmp_val )
      class default
        call die_msg( 946966665, "Iterator type mismatch. Expected "//        &
                      "config_iterator_t" )
    end select

  end subroutine get_property_from_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an array value using an iterator
  !!
  !! \todo the get functions should be changed so that the search by name
  !!       functions call search by index functions
  subroutine get_array_from_iterator( this, iterator, value, caller )

    use json_module,                   only : json_ck
    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Iterator to use to find value
    class(iterator_t), intent(in) :: iterator
    !> Returned value
    type(string_t), allocatable, intent(out) :: value(:)
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    type(json_value), pointer :: j_obj
    character(kind=json_ck, len=:), allocatable :: key

    select type( iterator )
      class is( config_iterator_t )
        call this%core_%get_child( this%value_, iterator%id_, j_obj )
        call this%core_%info( j_obj, name = key )
        call this%get_string_array( key, value, caller )
      class default
        call die_msg( 858322486, "Iterator type mismatch. Expected "//        &
                      "config_iterator_t" )
    end select

  end subroutine get_array_from_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a subset of configuration data
  subroutine add_config( this, key, value, caller )

    use json_module,                   only : json_ck

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    type(config_t), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    character(kind=json_ck, len=:), allocatable :: json_string
    type(json_value), pointer :: a

    call this%core_%print_to_string( value%value_, json_string )
    call this%core_%parse( a, json_string )
    call this%core_%rename( a, key )
    call this%core_%add( this%value_, a )

  end subroutine add_config

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a string to the configuration data
  subroutine add_char_array( this, key, value, caller )

    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    character(len=*), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    call this%core_%add( this%value_, key, value )

  end subroutine add_char_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a string to the configuration data
  subroutine add_string( this, key, value, caller )

    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    type(string_t), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    call this%core_%add( this%value_, key, value%val_ )

  end subroutine add_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a property to the configuration data
  subroutine add_property( this, key, units, value, caller )

    use json_module,                   only : json_ck

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key to insert
    character(len=*), intent(in) :: key
    !> Units for value
    character(len=*), intent(in) :: units
    !> Value to set
    real(kind=musica_dk), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    character(kind=json_ck, len=:), allocatable :: full_key

    full_key = get_full_key( key, units )
    call this%core_%add( this%value_, full_key, value )

  end subroutine add_property

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add an integer to the configuration data
  subroutine add_int( this, key, value, caller )

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    integer, intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    call this%core_%add( this%value_, key, value )

  end subroutine add_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a single-precision real number to the configuration data
  subroutine add_float( this, key, value, caller )

    use json_module,                   only : json_rk

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    real(kind=musica_rk), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    real(kind=json_rk) :: tmp_value

    tmp_value = value
    call this%core_%add( this%value_, key, tmp_value )

  end subroutine add_float

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a double-precision real number to the configuration data
  subroutine add_double( this, key, value, caller )

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    real(kind=musica_dk), intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    call this%core_%add( this%value_, key, value )

  end subroutine add_double

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a boolean to the configuration data
  subroutine add_logical( this, key, value, caller )

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    logical, intent(in) :: value
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    call this%core_%add( this%value_, key, value )

  end subroutine add_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a string array to the configuration data
  subroutine add_string_array( this, key, value, caller )

    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Key in insert
    character(len=*), intent(in) :: key
    !> Value to set
    type(string_t), intent(in) :: value(:)
    !> Name of the calling function (only for use in error messages)
    character(len=*), intent(in) :: caller

    type(json_value), pointer :: array
    integer :: i_str

    call this%core_%create_array( array, key )
    do i_str = 1, size( value )
      call this%core_%add( array, "", value( i_str )%val_ )
    end do
    call this%core_%add( this%value_, array )

  end subroutine add_string_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assign a config_t from a config_t
  subroutine config_assign_config( a, b )

    use json_module,                   only : json_ck

    !> Configuration to assign to
    class(config_t), intent(inout) :: a
    !> Configuration to assign from
    class(config_t), intent(in) :: b

    character(kind=json_ck, len=:), allocatable :: json_string

    call a%core_%print_to_string( b%value_, json_string )
    call a%core_%initialize( )
    call a%core_%destroy( a%value_ )
    call a%core_%parse( a%value_, json_string )

  end subroutine config_assign_config

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assign a config_t from a string
  subroutine config_assign_string( config, string )

    use musica_string,                 only : string_t

    !> Configuration to assign to
    class(config_t), intent(inout) :: config
    !> String to assign from
    class(string_t), intent(in) :: string

    call config%core_%initialize( )
    call config%core_%destroy( config%value_ )
    call config%core_%parse( config%value_, string%val_ )

  end subroutine config_assign_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assign a config_t from a character array
  subroutine config_assign_char( config, string )

    use musica_string,                 only : string_t

    !> Configuration to assign to
    class(config_t), intent(inout) :: config
    !> String to assign from
    character(len=*), intent(in) :: string

    call config%core_%initialize( )
    call config%core_%destroy( config%value_ )
    call config%core_%parse( config%value_, string )

  end subroutine config_assign_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Assign a string from a configuration
  subroutine string_assign_config( string, config )

    use musica_string,                 only : string_t

    !> String to assign to
    type(string_t), intent(out) :: string
    !> Configuration to assign from
    class(config_t), intent(in) :: config

    type(json_core) :: tmp_core

    call tmp_core%initialize( )
    call tmp_core%print_to_string( config%value_, string%val_ )

  end subroutine string_assign_config

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Clean up memory
  subroutine finalize( this )

    !> Configuration
    class(config_t), intent(inout) :: this

    call this%core_%destroy( this%value_ )
    call this%core_%destroy( )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the property name from a key
  function get_property_name( key ) result( prop_name )

    use musica_string,                 only : string_t

    !> Property name
    type(string_t) :: prop_name
    !> Key
    character(len=*), intent(in) :: key

    integer :: b

    b = index( key, '[' )
    prop_name = trim( key(1:b-1) )

  end function get_property_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the property units from a key
  function get_property_units( key ) result( units )

    use musica_string,                 only : string_t

    !> Units
    type(string_t) :: units
    !> Key
    character(len=*), intent(in) :: key

    integer :: b1, b2

    b1 = index( key, '[' )
    b2 = index( key, ']' )
    units = trim( key(b1+1:b2-1) )

  end function get_property_units

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get a full to use for a property
  function get_full_key( property_name, units ) result( key )

    !> Full key
    character(len=:), allocatable :: key
    !> Property name
    character(len=*), intent(in) :: property_name
    !> Property units
    character(len=*), intent(in) :: units

    key = trim( property_name )//" ["//trim( units )//"]"

  end function get_full_key

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Find a full key name by a prefix
  !!
  !! Returns the first instance of the prefix if found
  subroutine find_by_prefix( this, prefix, parent, child, full_key, found )

    use json_module,                   only : json_ck, json_ik, json_lk
    use json_string_utilities,         only : escape_string
    use musica_string,                 only : string_t

    !> Configuration
    class(config_t), intent(inout) :: this
    !> Prefix to search for (first instance is returned)
    character(len=*), intent(in) :: prefix
    !> JSON object to search
    type(json_value), pointer, intent(in) :: parent
    !> JSON object found
    type(json_value), pointer, intent(out) :: child
    !> Full key found
    type(string_t), intent(out) :: full_key
    !> Flag indicating whether the key was found
    logical, intent(out) :: found

    character(kind=json_ck, len=:), allocatable :: tmp_key
    type(json_value), pointer :: next
    logical(kind=json_lk) :: l_found
    integer :: length

    length = len( trim( prefix ) )
    child => null( )
    next  => null( )
    call this%core_%get_child( parent, int( 1, kind=json_ik ), child, l_found )
    do while( associated( child ) .and. l_found )
      call this%core_%info( child, name = tmp_key )
      if( len( tmp_key ) .gt. length ) then
        if( tmp_key(1:length) .eq. trim( prefix ) ) then
          full_key = tmp_key
          found = .true.
          return
        end if
      end if
      call this%core_%get_next( child, next )
      child => next
    end do
    child => null( )
    found = .false.
    full_key = ""

  end subroutine find_by_prefix

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the iterator
  !!
  !! Returns false if the end of the collection has been reached
  logical function iterator_next( this )

    use json_module,                   only : json_ik

    !> Iterator
    class(config_iterator_t), intent(inout) :: this

    integer(kind=json_ik) :: n_children

    this%id_ = this%id_ + 1
    call this%config_%core_%info( this%config_%value_, n_children = n_children )
    if( this%id_ .le. n_children ) then
      iterator_next = .true.
    else
      iterator_next = .false.
    end if

  end function iterator_next

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Reset the iterator
  subroutine iterator_reset( this )

    !> Iterator
    class(config_iterator_t), intent(inout) :: this

    this%id_ = 0

  end subroutine iterator_reset

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_config

