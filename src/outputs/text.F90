! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_output_text module

!> The output_text_t type and related functions
module musica_output_text

  use musica_domain,                   only : domain_state_accessor_t,        &
                                              domain_iterator_t
  use musica_string,                   only : string_t
  use musica_output,                   only : output_t

  implicit none
  private

  public :: output_text_t

  !> Private output variable type
  type :: output_var_t
    !> Accessor for variable
    class(domain_state_accessor_t), pointer :: accessor_
    !> Variable name
    type(string_t) :: name_
    !> Variable units
    type(string_t) :: units_
  end type output_var_t

  !> Output to a text file
  type, extends(output_t) :: output_text_t
    private
    !> Flag indicating whether file is open
    logical :: is_open_ = .false.
    !> Output file path
    type(string_t) :: file_path_
    !> File pointer
    integer :: file_unit_
    !> Set of registered variables for output
    type(output_var_t), allocatable :: variables_(:)
    !> Iterator over domain cells
    class(domain_iterator_t), pointer :: iterator_
  contains
    !> Register a state variable for output
    procedure :: register
    !> Output the current domain state
    procedure :: output
    !> Close the file stream
    procedure :: close
    !> Finalize the output
    final :: finalize
  end type output_text_t

  !> Constructor
  interface output_text_t
    module procedure :: constructor
  end interface output_text_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function constructor( config ) result( new_obj )

    use musica_config,                 only : config_t

    !> New output file
    type(output_text_t), pointer :: new_obj
    !> Configuration data
    class(config_t), intent(inout) :: config

    character(len=*), parameter :: my_name = 'output constructor'
    logical :: found

    allocate( new_obj )
    call config%get( "file name", new_obj%file_path_, my_name, found = found )
    if( .not. found ) new_obj%file_path_ = "output.csv"
    allocate( new_obj%variables_( 0 ) )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine register( this, domain, variable_name, units, output_name )

    use musica_domain,                 only : domain_t

    !> Output stream
    class(output_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to output
    character(len=*), intent(in) :: variable_name
    !> Units for output variable
    character(len=*), intent(in) :: units
    !> Optional custom output name
    character(len=*), intent(in), optional :: output_name

    character(len=*), parameter :: my_name = "output text file"
    type(output_var_t), allocatable :: temp_vars(:)

    allocate( temp_vars( size( this%variables_ ) ) )
    temp_vars(:) = this%variables_(:)
    deallocate( this%variables_ )
    allocate( this%variables_( size( temp_vars ) + 1 ) )
    this%variables_( 1:size( temp_vars ) ) = temp_vars(:)
    deallocate( temp_vars )
    this%variables_( size( this%variables_ ) )%accessor_ =>                   &
        domain%cell_state_accessor( variable_name, units, my_name )
    if( present( output_name ) ) then
      this%variables_( size( this%variables_ ) )%name_ = output_name
    else
      this%variables_( size( this%variables_ ) )%name_ = variable_name
    end if
    this%variables_( size( this%variables_ ) )%units_ = units

  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine output( this, time__s, domain, domain_state )

    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    use musica_io,                     only : get_file_unit

    !> Output stream
    class(output_text_t), intent(inout) :: this
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

  !> Close the file stream
  subroutine close( this )

    use musica_io,                     only : free_file_unit

    !> Output stream
    class(output_text_t), intent(inout) :: this

    if( this%is_open_ ) then
      close( this%file_unit_ )
      call free_file_unit( this%file_unit_ )
      if( associated( this%iterator_ ) ) deallocate( this%iterator_ )
      this%is_open_ = .false.
    end if

  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize the output stream
  subroutine finalize( this )

    !> Output stream
    type(output_text_t), intent(inout) :: this

    call this%close( )

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_output_text
