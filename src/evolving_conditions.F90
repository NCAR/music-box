! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_evolving_conditions module

!> The evolving_conditions_t type and related functions
module musica_evolving_conditions

  use musica_constants,                only : musica_dk
  use musica_io,                       only : io_ptr

  implicit none
  private

  public :: evolving_conditions_t

  !> Evolving model conditions
  type evolving_conditions_t
    private
    !> Input files
    class(io_ptr), allocatable :: input_files_(:)
  contains
    !> Get suggested output times [s]
    procedure :: get_update_times__s
    !> Update the domain state
    procedure :: update_state
    !> Finalize the object
    final :: finalize
  end type evolving_conditions_t

  !> Constructor for evolving conditions
  interface evolving_conditions_t
    module procedure :: constructor
  end interface evolving_conditions_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor for evolving conditions
  function constructor( config, domain ) result( new_obj )

    use musica_assert,                 only : assert_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_io_factory,             only : io_builder
    use musica_iterator,               only : iterator_t
    use musica_string,                 only : string_t

    !> New evolving conditions object
    type(evolving_conditions_t), pointer :: new_obj
    !> Evolving conditions configuration data
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain

    character(len=*), parameter :: my_name = 'evolving conditions constructor'
    type(config_t) :: file_config
    class(iterator_t), pointer :: file_iter
    type(string_t) :: file_name, file_type
    type(string_t), allocatable :: str_array(:)
    integer :: i_file, n_files

    allocate( new_obj )

    ! load the evolving conditions files
    n_files = 0
    file_iter => config%get_iterator( )
    do while( file_iter%next( ) )
      n_files = n_files + 1
    end do
    allocate( new_obj%input_files_( n_files ) )
    call file_iter%reset( )
    i_file = 1
    do while( file_iter%next( ) )
      call config%get( file_iter, file_config, my_name )
      file_name = config%key( file_iter )
      str_array = file_name%split( "." )
      file_type = str_array( size( str_array ) )%to_lower( )
      call file_config%add( "type", file_type, my_name )
      call file_config%add( "intent", "input", my_name )
      call file_config%add( "file name", file_name, my_name )
      new_obj%input_files_( i_file )%val_ => io_builder( file_config, domain )
      call file_config%finalize( )
      i_file = i_file + 1
    end do

    deallocate( file_iter )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get suggested update times [s]
  !!
  !! These times correspond to the entries in the input data
  !!
  function get_update_times__s( this ) result( times )

    use musica_array,                  only : merge_series

    !> Suggested update times
    real(kind=musica_dk), allocatable :: times(:)
    !> Evolving conditions
    class(evolving_conditions_t), intent(inout) :: this

    integer :: i_file

    allocate( times( 0 ) )
    do i_file = 1, size( this%input_files_ )
      times = merge_series( times,                                            &
                           this%input_files_( i_file )%val_%entry_times__s( ) )
    end do

  end function get_update_times__s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update the model state for a given time
  subroutine update_state( this, domain, state, time__s )

    use musica_domain,                 only : domain_t, domain_state_t

    !> Evolving conditions
    class(evolving_conditions_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state to update
    class(domain_state_t), intent(inout) :: state
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s

    integer :: i_file

    do i_file = 1, size( this%input_files_ )
      call this%input_files_( i_file )%val_%update_state( domain, state,      &
                                                          time__s )
    end do

  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize the evolving conditions
  subroutine finalize( this )

    !> Evolving conditions
    type(evolving_conditions_t), intent(inout) :: this

    integer :: i_file

    if( allocated( this%input_files_ ) ) then
      do i_file = 1, size( this%input_files_ )
        if( associated( this%input_files_( i_file )%val_ ) ) then
          deallocate( this%input_files_( i_file )%val_ )
        end if
      end do
      deallocate( this%input_files_ )
    end if

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_evolving_conditions
