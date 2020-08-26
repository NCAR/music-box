! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_netcdf_dimension module

!> The netcdf_dimension_t type and related functions
module musica_netcdf_dimension

  use musica_constants,                only : musica_dk, musica_ik
  use musica_netcdf_variable,          only : netcdf_variable_t
  use netcdf

  implicit none
  private

  public :: netcdf_dimension_t

  !> A NetCDF dimension
  type :: netcdf_dimension_t
    private
    !> NetCDF dimension id
    integer(kind=musica_ik) :: id_ = -1
    !> All dimension values present in the file
    real(kind=musica_dk), allocatable :: values_(:)
    !> NetCDF variable for this dimension
    type(netcdf_variable_t) :: variable_
  contains
    !> Gets the values for this dimension
    procedure :: get_values
    !> Gets the index for a given dimesion value
    procedure :: get_index
    !> Prints the properties of the dimension
    procedure :: print => do_print
    !> Loads the dimension values in MUSICA units, after scaling/offsetting
    procedure, private :: load_values
  end type netcdf_dimension_t

  !> Constructor
  interface netcdf_dimension_t
    module procedure :: constructor
  end interface netcdf_dimension_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a netcdf_dimension_t object for a NetCDF dimension
  function constructor( file, variable ) result( new_obj )

    use musica_netcdf_file,            only : netcdf_file_t
    use musica_string,                 only : string_t

    !> Pointer to the new NetCDF dimension object
    type(netcdf_dimension_t), pointer :: new_obj
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file
    !> NetCDF variable associated with the dimension
    type(netcdf_variable_t), intent(in) :: variable

    type(string_t) :: var_name

    allocate( new_obj )
    var_name = variable%name( )
    new_obj%variable_ = variable
    call file%check_open( )
    call file%check_status( 140723118,                                        &
        nf90_inq_dimid( file%id( ), var_name%to_char( ), new_obj%id_ ),       &
        "Error finding id for dimension '"//var_name%to_char( )//"'" )
    call new_obj%load_values( file )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the values for this dimension
  function get_values( this ) result( values )

    !> Dimension values
    real(kind=musica_dk), allocatable :: values(:)
    !> NetCDF dimension
    class(netcdf_dimension_t), intent(in) :: this

    values = this%values_

  end function get_values

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the index for a given dimension value
  !!
  !! If the value does not correspond exactly to a file index, the index of
  !! closest value less the requested value is returned. The is_exact flag
  !! can be included to indicate whether an exact match was found.
  !!
  !! If the first dimension value is greater than the requested value, an
  !! index of 1 is returned.
  !!
  function get_index( this, value, is_exact, guess ) result( index )

    use musica_assert,                 only : assert
    use musica_config,                 only : config_t
    use musica_datetime,               only : datetime_t

    !> Index for the closest (without going over) value
    integer(kind=musica_ik) :: index
    !> NetCDF dimension
    class(netcdf_dimension_t), intent(in) :: this
    !> Value to find
    real(kind=musica_dk), intent(in) :: value
    !> Flag indicating whether an exact match was found
    logical, intent(out), optional :: is_exact
    !> A guess for the index that will be used to start the search
    integer(kind=musica_ik), intent(in), optional :: guess

    integer(kind=musica_ik) :: i_val, l_guess

    if( present( is_exact ) ) is_exact = .false.
    if( this%values_( 1 ) .gt. value ) then
      index = 1
      return
    end if
    if( present( guess ) ) then
      l_guess = guess
      if( l_guess .gt. size( this%values_ ) ) l_guess = size( this%values_ )
      if( l_guess .lt. 1 ) l_guess = 1
      if( this%values_( l_guess ) .le. value ) then
        do i_val = l_guess, size( this%values_ )
          if( this%values_( i_val ) .eq. value ) then
            if( present( is_exact ) ) is_exact = .true.
            index = i_val
            return
          else if( this%values_( i_val ) .gt. value ) then
            index = i_val - 1
            return
          end if
        end do
      else
        do i_val = l_guess, 0, -1
          if( this%values_( i_val ) .eq. value ) then
            if( present( is_exact ) ) is_exact = .true.
            index = i_val
            return
          else if( this%values_( i_val ) .lt. value ) then
            index = i_val
            return
          end if
        end do
      end if
    else
      do i_val = 1, size( this%values_ )
        if( this%values_( i_val ) .eq. value ) then
          if( present( is_exact ) ) is_exact = .true.
          index = i_val
          return
        else if( this%values_( i_val ) .gt. value ) then
          index = i_val - 1
          return
        end if
      end do
    end if

  end function get_index

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints the properties of the dimension
  subroutine do_print( this )

    use musica_string,                 only : to_char

    !> NetCDF dimension
    class(netcdf_dimension_t), intent(in) :: this

    write(*,*) "*** Dimension id: "//to_char( this%id_ )//" ***"
    call this%variable_%print( )

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the values for the dimension from the NetCDF file
  subroutine load_values( this, file )

    use musica_assert,                 only : assert
    use musica_netcdf_file,            only : netcdf_file_t
    use musica_string,                 only : string_t

    !> NetCDF dimension
    class(netcdf_dimension_t), intent(inout) :: this
    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: file

    integer(kind=musica_ik) :: n_values
    type(string_t) :: var_name

    var_name = this%variable_%name( )
    call file%check_status( 649288296,                                        &
                            nf90_inquire_dimension( file%id( ),               &
                                                    this%id_,                 &
                                                    len = n_values ),         &
                            "Error getting values for dimension '"//          &
                            var_name%to_char( )//"'" )
    allocate( this%values_( n_values ) )
    call this%variable_%get_data( file, 1, n_values, this%values_ )

  end subroutine load_values

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_netcdf_dimension
