!> \file
!> The musica_constants module

!> Common physical constants
module musica_constants

  implicit none
  public

  !> MusicBox kinds
  !! @{
  !> Kind of an integer
  integer, parameter :: musica_ik = kind(1)
  !> Kind of a single-precision real number
  integer, parameter :: musica_rk = kind(0.0)
  !> Kind of a double-precision real number
  integer, parameter :: musica_dk = kind(0.0d0)
  !> @}

  !> Physical constants
  !! @{
  !> Pi
  real(kind=musica_dk) :: PI = 3.14159265358979323846d0
  !> Avagadro's number
  real(kind=musica_dk) :: AVAGADRO = 6.02214179d23
  !! @}

end module musica_constants
