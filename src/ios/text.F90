! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io_text module

!> The io_text_t type and related functions
module musica_io_text

  use musica_constants,                only : musica_dk
  use musica_domain,                   only : domain_state_accessor_t,        &
                                              domain_iterator_t
  use musica_string,                   only : string_t
  use musica_io,                       only : io_t

  implicit none
  private

  public :: io_text_t

  !> Private input/output variable type
  type :: io_var_t
    !> Mutator for variable
    class(domain_state_accessor_t), pointer :: mutator_ => null( )
    !> Accessor for variable
    class(domain_state_accessor_t), pointer :: accessor_ => null( )
    !> Time series
    real(kind=musica_dk), allocatable :: time_series_(:)
    !> Variable name
    type(string_t) :: name_
    !> Variable units
    type(string_t) :: units_
  end type io_var_t

  !> Text file input/output
  !!
  !! Sets up a text file for input and/or output.
  !!
  !! \todo add example for \c io_test_t usage
  !!
  type, extends(io_t) :: io_text_t
    private
    !> Flag indicating whether file is open
    logical :: is_open_ = .false.
    !> Flag indicating whether file is for input
    logical :: is_input_ = .false.
    !> Flag indicating whether file is for output
    logical :: is_output_ = .false.
    !> File path
    type(string_t) :: file_path_
    !> File pointer
    integer :: file_unit_
    !> Set of registered variables for input/output
    type(io_var_t), allocatable :: variables_(:)
    !> Iterator over domain cells
    class(domain_iterator_t), pointer :: iterator_
  contains
    !> Auto-maps input/output variables to model state variables
    procedure :: auto_map_variables
    !> Registers a state variable for input/output
    procedure :: register
    !> Updates the model state with input data
    procedure :: update_state
    !> Outputs the current domain state
    procedure :: output
    !> Closes the file stream
    procedure :: close
    !> Finalizes the output
    final :: finalize
  end type io_text_t

  !> Constructor
  interface io_text_t
    module procedure :: constructor
  end interface io_text_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a connection to a text input/output file
  !!
  !! At minimum, \c config must include a top-level key-value pair "intent",
  !! which can be any of: "input", "output", or "input/output".
  !!
  !! A "file name" is also required for files opened for input or
  !! input/output. This is optional for output files, with the default name
  !! being "output.csv".
  !!
  function constructor( config ) result( new_obj )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t

    !> New output file
    type(io_text_t), pointer :: new_obj
    !> Configuration data
    class(config_t), intent(inout) :: config

    character(len=*), parameter :: my_name = 'output constructor'
    logical :: found
    type(string_t) :: temp_str

    allocate( new_obj )

    ! file intent
    call config%get( "intent", temp_str, my_name )
    if( temp_str .eq. "input" ) then
      new_obj%is_input_ = .true.
    else if( temp_str .eq. "output" ) then
      new_obj%is_output_ = .true.
    else if( temp_str .eq. "input/output" ) then
      new_obj%is_input_ = .true.
      new_obj%is_output_ = .true.
    else
      call die_msg( 162615120, "Invalid type specified for text file: "//     &
                               temp_str%to_char( ) )
    end if

    ! file name
    call config%get( "file name", new_obj%file_path_, my_name, found = found )
    if( .not. found ) then
      if( new_obj%is_input_ ) then
        call die_msg( 652480899, "A 'file name' must be provided for "//      &
                      "input text files" )
      else
        new_obj%file_path_ = "output.csv"
      end if
    end if

    ! initialize io variables
    allocate( new_obj%variables_( 0 ) )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Auto-maps input/output variables to model state variables
  subroutine auto_map_variables( this, domain )

    use musica_assert,                 only : assert_msg, die_msg
    use musica_domain,                 only : domain_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain

    call assert_msg( 974120905, .not. this%is_output_, "Auto-mapping of "//   &
                     "text files is only available for input or "//           &
                     "input/output files." )

    call die_msg( 431967997, "Input text files are not set up yet." )

  end subroutine auto_map_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a state variable for input/output
  subroutine register( this, domain, variable_name, units, io_name )

    use musica_domain,                 only : domain_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to output
    character(len=*), intent(in) :: variable_name
    !> Units for output variable
    character(len=*), intent(in) :: units
    !> Optional custom output name
    character(len=*), intent(in), optional :: io_name

    character(len=*), parameter :: my_name = "output text file"
    type(io_var_t), allocatable :: temp_vars(:)

    allocate( temp_vars( size( this%variables_ ) ) )
    temp_vars(:) = this%variables_(:)
    deallocate( this%variables_ )
    allocate( this%variables_( size( temp_vars ) + 1 ) )
    this%variables_( 1:size( temp_vars ) ) = temp_vars(:)
    deallocate( temp_vars )
    this%variables_( size( this%variables_ ) )%accessor_ =>                   &
        domain%cell_state_accessor( variable_name, units, my_name )
    if( present( io_name ) ) then
      this%variables_( size( this%variables_ ) )%name_ = io_name
    else
      this%variables_( size( this%variables_ ) )%name_ = variable_name
    end if
    this%variables_( size( this%variables_ ) )%units_ = units

  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the model state with input data
  !!
  !! \todo finish input data functions for text files
  subroutine update_state( this, time__s, domain, domain_state )

    use musica_assert,                 only : die_msg
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state to update
    class(domain_state_t), intent(inout) :: domain_state

    call die_msg( 287515161, "Input text files are not set up yet." )

  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Outputs the current domain state
  subroutine output( this, time__s, domain, domain_state )

    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    use musica_io,                     only : get_file_unit

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state

    integer :: i_var, i_cell
    real(kind=musica_dk) :: state_value
    logical :: one_cell
    type(string_t) :: col_name

    if( .not. this%is_open_ ) then
      this%iterator_ => domain%cell_iterator( )

      ! check if there is more than one cell for naming
      one_cell = this%iterator_%next( )
      one_cell = .true.
      if( this%iterator_%next( ) ) one_cell = .false.
      call this%iterator_%reset( )

      ! open the cell and write the header
      this%file_unit_ = get_file_unit( )
      open( unit = this%file_unit_, file = this%file_path_%to_char( ) )
      write(this%file_unit_,'(A)',advance="no") "time"
      call this%iterator_%reset( )
      i_cell = 1
      do while( this%iterator_%next( ) )
        do i_var = 1, size( this%variables_ )
          if( one_cell ) then
            col_name = this%variables_(i_var)%name_
          else
            col_name = i_cell
            col_name = trim( col_name%to_char( ) )//'.'//                     &
                this%variables_(i_var)%name_
          end if
          write(this%file_unit_,'(", ",A)',advance="no") col_name%to_char( )
        end do
        i_cell = i_cell + 1
      end do
      write(this%file_unit_,*) ""
      this%is_open_ = .true.
    end if

    ! output the current state values
    write(this%file_unit_,'(D30.20)',advance="no") time__s
    call this%iterator_%reset( )
    do while( this%iterator_%next( ) )
      do i_var = 1, size( this%variables_ )
        call domain_state%get( this%iterator_,                                &
                               this%variables_(i_var)%accessor_,              &
                               state_value )
        write(this%file_unit_,'(", ",D30.20)',advance="no") state_value
      end do
    end do
    write(this%file_unit_,*) ""

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Closes the text file
  subroutine close( this )

    use musica_io,                     only : free_file_unit

    !> Text file
    class(io_text_t), intent(inout) :: this

    if( this%is_open_ ) then
      close( this%file_unit_ )
      call free_file_unit( this%file_unit_ )
      if( associated( this%iterator_ ) ) deallocate( this%iterator_ )
      this%is_open_ = .false.
    end if

  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes the text file object, including closing the file if needed.
  subroutine finalize( this )

    !> Text file
    type(io_text_t), intent(inout) :: this

    call this%close( )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io_text
