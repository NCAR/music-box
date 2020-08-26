! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_netcdf_file module

!> The netcdf_file_t type and related functions
module musica_netcdf_file

  use musica_constants,                only : musica_ik, musica_dk
  use musica_string,                   only : string_t
  use netcdf

  implicit none
  private

  public :: netcdf_file_t

  !> A NetCDF file
  type :: netcdf_file_t
    private
    !> Flag indicating whether the file is open
    logical :: is_open_ = .false.
    !> Path to the file
    type(string_t) :: path_
    !> File id
    integer(kind=musica_ik) :: id_
    !> Indicates file is for input
    logical :: is_input_ = .false.
    !> Indicates file is for output
    logical :: is_output_ = .false.
  contains
    !> Returns the NetCDF file id
    procedure :: id
    !> Returns the name of the file
    procedure :: name => file_name
    !> Returns whether the file is an input
    procedure :: is_input
    !> Returns whether the file is an output
    procedure :: is_output
    !> Opens the file if it is not currently open
    procedure :: check_open
    !> Checks a returned NetCDF status code and fail if an error occurred
    procedure :: check_status
    !> Closes the file
    procedure :: close
    !> Prints the file properties
    procedure :: print => do_print
    !> Finalizes the file
    final :: finalize
  end type netcdf_file_t

  !> Constructor
  interface netcdf_file_t
    module procedure :: constructor
  end interface netcdf_file_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a netcdf_file_t object for a NetCDF file
  function constructor( file_path, is_input, is_output ) result( new_obj )

    use musica_assert,                 only : assert_msg

    !> New NetCDF file object
    type(netcdf_file_t) :: new_obj
    !> Path to the NetCDF file
    type(string_t) :: file_path
    !> Flags the file as an input
    logical, optional :: is_input
    !> Flags the file as an output
    logical, optional :: is_output

    new_obj%path_ = file_path
    if( present( is_input  ) ) new_obj%is_input_  = is_input
    if( present( is_output ) ) new_obj%is_output_ = is_output
    call assert_msg( 261207824, .not. new_obj%is_output_, "NetCDF output "//  &
                     "files are not yet supported." )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the NetCDF file id
  function id( this )

    !> NetCDF file id
    integer(kind=musica_ik) :: id
    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this

    id = this%id_

  end function id

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the file name
  function file_name( this )

    !> File name
    type(string_t) :: file_name
    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this

    file_name = this%path_

  end function file_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns whether the file is an input
  logical function is_input( this )

    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this

    is_input = this%is_input_

  end function is_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns whether the file is an output
  logical function is_output( this )

    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this

    is_output = this%is_output_

  end function is_output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Opens the file if it is not open already
  subroutine check_open( this )

    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: this

    if( .not. this%is_open_ ) then
      call this%check_status( 172405314,                                      &
          nf90_open( this%path_%to_char( ), NF90_NOWRITE, this%id_ ),         &
                     "Error opening NetCDF file" )
      this%is_open_ = .true.
    end if

  end subroutine check_open

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Checks a NetCDF and fail with a message if an error occurred
  subroutine check_status( this, code, status, error_message )

    use musica_assert,                 only : die_msg

    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this
    !> Unique code for the assertion
    integer(kind=musica_ik), intent(in) :: code
    !> Status code
    integer(kind=musica_ik), intent(in) :: status
    !> Error message
    character(len=*), intent(in) :: error_message

    if( status .ne. NF90_NOERR ) then
      call die_msg( code, "NetCDF file '"//this%path_%to_char( )//            &
                    "': "//trim( error_message )//": "//                      &
                    trim( nf90_strerror( status ) ) )
    end if

  end subroutine check_status

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Closes the NetCDF file
  subroutine close( this )

    !> NetCDF file
    class(netcdf_file_t), intent(inout) :: this

    if( this%is_open_ ) then
      call this%check_status( 633660547, nf90_close( this%id_ ),              &
                              "Error closing NetCDF file '"//                 &
                              this%path_%to_char( )//"'" )
      this%is_open_ = .false.
    end if

  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Prints the file properties
  subroutine do_print( this )

    !> NetCDF file
    class(netcdf_file_t), intent(in) :: this

    write(*,*) "file path: "//this%path_%to_char( )
    write(*,*) "file id:", this%id_
    write(*,*) "is input:", this%is_input_
    write(*,*) "is output:", this%is_output_

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes the file object
  subroutine finalize( this )

    !> NetCDF file
    type(netcdf_file_t), intent(inout) :: this

    call this%close( )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_netcdf_file
