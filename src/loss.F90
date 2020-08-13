! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_loss module

!> The loss_t type and related functions
module musica_loss

  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain,                   only : domain_state_accessor_t,        &
                                              domain_state_mutator_t

  implicit none
  private

  public :: loss_t

  !> Accessors/mutators for loss rate/species pairs
  type :: loss_pairs_t
    !> Loss rate accessor
    class(domain_state_accessor_t), pointer :: get_rate_ => null( )
    !> Get current chemical species concentration
    class(domain_state_accessor_t), pointer :: get_species_ => null( )
    !> Set chemical species concentration
    class(domain_state_mutator_t), pointer :: set_species_ => null( )
  end type loss_pairs_t

  !> First-order loss handler for MUSICA
  !!
  !! These objects match loss rates registered by other model components
  !! to chemical species during construction. During the simulation the
  !! type-bound \c do_loss() function can be called to update a domain state
  !! to include loss for a provided time step.
  !!
  !! \todo add loss_t example
  !!
  type :: loss_t
    private
    !> Loss rate/species pairs
    type(loss_pairs_t), allocatable :: pairs_(:)
  contains
    !> Update domain state for loss occurring over a given time step
    procedure :: do_loss
    !> Clean up memory
    final :: finalize
  end type loss_t

  !> Constructor for the loss_t type
  interface loss_t
    module procedure :: constructor
  end interface loss_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Create an loss_t object
  !!
  !! The constructor finds registered loss rates and matches them to
  !! chemical species concentrations, setting up accessors and mutators to use
  !! at run-time to update the domain state to include loss.
  !!
  function constructor( domain ) result( new_obj )

    use musica_domain,                 only : domain_t,                       &
                                              domain_state_accessor_ptr
    use musica_string,                 only : string_t

    !> New loss_t object
    type(loss_t), pointer :: new_obj
    !> Model domain
    class(domain_t), intent(inout) :: domain

    character(len=*), parameter :: my_name = 'loss_t constructor'
    type(domain_state_accessor_ptr), pointer :: rates(:)
    type(string_t), allocatable :: species_names(:)
    integer(kind=musica_ik) :: i_rate

    allocate( new_obj )

    rates => domain%cell_state_set_accessor( "loss_rate_constants",           & !- state variable set name
                                             "s-1",                           & !- MUSICA units
                                             species_names,                   & !- set element names
                                             my_name )

    allocate( new_obj%pairs_( size( rates ) ) )

    do i_rate = 1, size( rates )
      new_obj%pairs_( i_rate )%get_rate_ => rates( i_rate )%val_
      rates( i_rate )%val_ => null( )
      new_obj%pairs_( i_rate )%get_species_ =>                                &
          domain%cell_state_accessor( "chemical_species%"//                   & !- state variable name
                                          species_names( i_rate )%to_char( ), &
                                      "mol m-3",                              & !- MUSICA units
                                      my_name )
      new_obj%pairs_( i_rate )%set_species_ =>                                &
          domain%cell_state_mutator(  "chemical_species%"//                   & !- state variable name
                                          species_names( i_rate )%to_char( ), &
                                      "mol m-3",                              & !- MUSICA units
                                      my_name )
    end do

    deallocate( rates )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update a domain state for loss over a given time step
  subroutine do_loss( this, domain_state, cell, time_step__s )

    use musica_assert,                 only : assert
    use musica_domain,                 only : domain_state_t,                 &
                                              domain_iterator_t

    !> Loss handler
    class(loss_t), intent(in) :: this
    !> Model domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Grid cell to update for loss
    class(domain_iterator_t), intent(in) :: cell
    !> Time step to calculate loss for [s]
    real(kind=musica_dk), intent(in) :: time_step__s

    integer(kind=musica_ik) :: i_rate
    real(kind=musica_dk) :: conc, k

    call assert( 202905722, allocated( this%pairs_ ) )
    do i_rate = 1, size( this%pairs_ )
      call domain_state%get( cell, this%pairs_( i_rate )%get_rate_, k )
      call domain_state%get( cell, this%pairs_( i_rate )%get_species_, conc )
      conc = conc * exp( - k * time_step__s )
      call domain_state%update( cell, this%pairs_( i_rate )%set_species_,     &
                                conc )
    end do

  end subroutine do_loss

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Clean up memory
  subroutine finalize( this )

    !> Loss handler
    type(loss_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_rate

    if( allocated( this%pairs_ ) ) then
      do i_rate = 1, size( this%pairs_ )
        if( associated( this%pairs_( i_rate )%get_rate_ ) )                   &
          deallocate( this%pairs_( i_rate )%get_rate_ )
        if( associated( this%pairs_( i_rate )%get_species_ ) )                &
          deallocate( this%pairs_( i_rate )%get_species_ )
        if( associated( this%pairs_( i_rate )%set_species_ ) )                &
          deallocate( this%pairs_( i_rate )%set_species_ )
      end do
      deallocate( this%pairs_ )
    end if

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_loss
