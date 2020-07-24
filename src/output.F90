! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_output module

!> The abstract output_t type and related functions
module musica_output

  implicit none
  private

  public :: output_t

  !> An abstract output stream
  type, abstract :: output_t
  contains
    !> Register a state variable for output
    procedure(register), deferred :: register
    !> Output the current domain state
    procedure(output), deferred :: output
    !> Close the output stream
    procedure(close), deferred :: close
  end type output_t

interface

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a state variable for output
  subroutine register( this, domain, variable_name, units, output_name )
    use musica_domain,                 only : domain_t
    import output_t
    !> Output stream
    class(output_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to output
    character(len=*), intent(in) :: variable_name
    !> Units for output variable
    character(len=*), intent(in) :: units
    !> Optional custom output name
    character(len=*), intent(in), optional :: output_name
  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Output the current domain state
  subroutine output( this, time__s, domain, domain_state )
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    import output_t
    !> Output stream
    class(output_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state
  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Close the output stream
  subroutine close( this )
    import output_t
    !> Output stream
    class(output_t), intent(inout) :: this
  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

end module musica_output
