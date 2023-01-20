! Copyright (C) 2023 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The music_box_micm module

!> The micm_t type and related functions
module music_box_micm

  use musica_component,                only : component_t
  use musica_config,                   only : config_t
  use musica_constants,                only : musica_dk, musica_ik
  use musica_domain_state_accessor,    only : domain_state_accessor_t,        &
                                              domain_state_accessor_ptr
  use musica_domain_state_mutator,     only : domain_state_mutator_t,         &
                                              domain_state_mutator_ptr

  implicit none
  private

  public :: micm_t

  !> Interface to Model Independent Chemical Mechanisms (MICM)
  !!
  type, extends(component_t) :: micm_t
    !> MICM configuration
    type(config_t) :: config_
    private
  contains
    !> Returns the name of the component
    procedure :: name => component_name
    !> Returns a description of the component purpose
    procedure :: description
    !> Advance the model state for a given timestep
    procedure :: advance_state
    !> Save the component configuration for future simultaions
    procedure :: preprocess_input
    final :: finalize
  end type micm_t

  !> Constructor of micm_t objects
  interface micm_t
    module procedure :: constructor
  end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> MICM interface constructor
  function constructor( config, domain, output ) result( new_obj )

    use musica_domain,                 only : domain_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_string,                 only : string_t

    !> New MICM interface
    type(micm_t), pointer :: new_obj
    !> MICM configuration
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Ouput file
    class(input_output_processor_t), intent(inout) :: output

    character(len=*), parameter :: my_name = "MICM interface constructor"
    type(string_t) :: config_file_name

    allocate( new_obj )

    ! save the configuration (used for preprocessing input data only)
    new_obj%config_ = config

    ! get the path to the MICM configuration file
    call config%get( "configuration file", config_file_name, my_name )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component name
  type(string_t) function component_name( this )

    use musica_string,                 only : string_t

    !> MICM interface
    class(micm_t), intent(in) :: this

    component_name = "MICM: Model Independent Chemical Mechanisms"

  end function component_name

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Model component description
  type(string_t) function description( this )

    use musica_string,                 only : string_t

    !> MICM interface
    class(micm_t), intent(in) :: this

    description = "A configurable chemistry solver"

  end function description

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the model state for multi-phase chemistry
  subroutine advance_state( this, domain_state, domain_element,               &
      current_time__s, time_step__s )

    use musica_domain_iterator,        only : domain_iterator_t
    use musica_domain_state,           only : domain_state_t

    !> MICM interface
    class(micm_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(inout) :: domain_state
    !> Domain element to advance state for
    class(domain_iterator_t), intent(in) :: domain_element
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: current_time__s
    !> Time step to advance state by [s]
    real(kind=musica_dk), intent(in) :: time_step__s

  end subroutine advance_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Save the MICM configuration for future simulations
  subroutine preprocess_input( this, config, output_path )

    use musica_assert,                 only : die_msg
    use musica_string,                 only : string_t

    !> MICM interface
    class(micm_t), intent(inout) :: this
    !> Model component configuration
    type(config_t), intent(out) :: config
    !> Folder to save input data to
    character(len=*), intent(in) :: output_path

    ! nothing to preprocess

  end subroutine preprocess_input

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes a micm_t object
  elemental subroutine finalize( this )

    !> MICM interface
    type(micm_t), intent(inout) :: this

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module music_box_camp
