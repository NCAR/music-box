!> \file
!> Common functions used to evaluate test output

!> Common functions used to evaluate test output
module test_common_output

  use musica_constants,                only : musica_dk, musica_ik
  use musica_string

  implicit none
  private

  public :: scaled_property_t, conservation_check

  !> Maximum length of a text file line
  integer, parameter :: kMaxFileLine = 5000

  !> Property with scaling factor
  type :: scaled_property_t
  private
    !> Property name
    type(string_t), public :: name_
    !> Scaling factor [unitless]
    real(kind=musica_dk), public :: scale_factor_ = 1.0
    !> Index of property in file
    integer(kind=musica_ik) :: file_index_ = -1
  end type scaled_property_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Ensure that a species or set of species is conserved in a time series
  !!
  !! To check a time series in a csv file for conservation of oxygen atoms
  !! in a mechanism that includes H2O, OH, and HOOH:
  !! \code{f90}
  !!   type(scaled_property_t) :: species(3)
  !!   character(len=*), parameter :: file_name = 'my_time_series.csv'
  !!   species(1)%name_ = "H2O"
  !!   species(2)%name_ = "OH"
  !!   species(3)%name_ = "HOOH"
  !!   species(3)%scale_factor_ = 2.0_musica_dk
  !!   call conservation_check( file_name, species )
  !! \endcode
  !!
  !! If oxygen is conserved in the time series, the subroutine will exit
  !! normally, otherwise an error will be thrown.
  !!
  subroutine conservation_check( file_name, species )

    use musica_assert,                 only : assert, almost_equal

    !> Time series data file
    character(len=*), intent(in) :: file_name
    !> Set of species with scaling factors to conserve
    type(scaled_property_t), intent(inout) :: species(:)

    character(len=kMaxFileLine) :: line
    type(string_t) :: line_str
    type(string_t), allocatable :: props(:), values(:)
    real(kind=musica_dk) :: first_val, curr_val, total_val
    integer :: io, i_prop, i_spec, time_index
    logical :: is_first_line

    open( unit = 10, file = file_name, action = 'READ', iostat = io )
    call assert( 163130698, io .eq. 0 )

    read( 10, '(a)', iostat = io ) line
    line_str = line
    call assert( 130996207, io .eq. 0 )

    do i_spec = 1, size( species )
      species( i_spec )%file_index_ = -1
    end do
    time_index = -1

    props = line_str%split( "," )
    do i_prop = 1, size( props )
      props( i_prop ) = adjustl( trim( props( i_prop )%to_char( ) ) )
    end do

    do i_prop = 1, size( props )
      do i_spec = 1, size( species )
        if( props( i_prop ) .eq. species( i_spec )%name_ ) then
          call assert( 235143767, species( i_spec )%file_index_ .eq. -1 )
          species( i_spec )%file_index_ = i_prop
          exit
        end if
        if( props( i_prop ) .eq. 'time' ) then
          time_index = i_prop
        end if
      end do
    end do

    do i_spec = 1, size( species )
      call assert( 326857179, species( i_spec )%file_index_ .gt. 0 )
    end do
    call assert( 379883726, time_index .gt. 0 )

    is_first_line = .true.
    read( 10, '(a)', iostat = io ) line
    do while( io .eq. 0 )
      line_str = line
      values = line_str%split( "," )
      total_val = 0.0
      do i_spec = 1, size( species )
        curr_val = values( species( i_spec )%file_index_ )
        curr_val = curr_val * species( i_spec )%scale_factor_
        total_val = total_val + curr_val
      end do
      if( is_first_line ) then
        first_val = total_val
        is_first_line = .false.
      end if
      call assert( 334766438, almost_equal( first_val, total_val ) )
      read( 10, '(a)', iostat = io ) line
    end do

    close( 10 )

  end subroutine conservation_check

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module test_common_output
