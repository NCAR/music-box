!> \file
!> Check results from an integration test

!> Check results from an integration test
program check_output

  use test_common_output

  implicit none

  call check_results( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Perform checks of an integration test output, in addition to comparison
  !! with the `expected_results` file
  subroutine check_results( )

    use musica_string,                 only : string_t

    type(scaled_property_t) :: species(4)

    species(1)%name_ = 'CONC.O1D'
    species(2)%name_ = 'CONC.O'
    species(3)%name_ = 'CONC.O2'
    species(3)%scale_factor_ = 2.0
    species(4)%name_ = 'CONC.O3'
    species(4)%scale_factor_ = 3.0

    call conservation_check( 'output.csv', species )

  end subroutine check_results

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program check_output
