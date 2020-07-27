! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_constants module

!> Common physical constants
module musica_constants

  implicit none
  public

  !> @defgroup kinds  Primitive type kinds
  !> @{

  !> Kind of an integer
  integer, parameter :: musica_ik = kind(1)
  !> Kind of a single-precision real number
  integer, parameter :: musica_rk = kind(0.0)
  !> Kind of a double-precision real number
  integer, parameter :: musica_dk = kind(0.0d0)

  !> @}


  !> @defgroup phys_const Physical constants
  !> @{

  !> Pi
  real(kind=musica_dk), parameter :: kPi = 3.14159265358979323846d0
  !> Avagadro's number [molec mol-1]
  real(kind=musica_dk), parameter :: kAvagadro = 6.02214179d23
  !> Universal gas constant [J mol-1 K-1].
  real(kind=musica_dk), parameter :: kUniversalGasConstant = 8.314472d0

  !> @}

end module musica_constants
