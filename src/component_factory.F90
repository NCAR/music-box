! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> Model component factory

!> Builder of model components
module musica_component_factory

  use musica_component,                only : component_t

  implicit none
  private

  public :: component_builder

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Build a model component by name
  !!
  !! \todo add full description and examples for component_builder
  !!
  function component_builder( config, domain, output ) result( new_obj )

    use music_box_camp,                only : camp_t
    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t
    use musica_emissions,              only : emissions_t
    use musica_input_output_processor, only : input_output_processor_t
    use musica_loss,                   only : loss_t
    use musica_string,                 only : string_t

    !> New model component
    class(component_t), pointer :: new_obj
    !> Model component configuration data
    type(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Output file
    class(input_output_processor_t), intent(inout) :: output

    type(string_t) :: component_type
    character(len=*), parameter :: my_name = "model component builder"

    new_obj => null( )
    call config%get( 'type', component_type, my_name )
    component_type = component_type%to_lower( )

    if( component_type .eq. 'camp' ) then
      new_obj => camp_t( config, domain, output )
    else if( component_type .eq. 'musica-emissions' ) then
      new_obj => emissions_t( config, domain, output )
    else if( component_type .eq. 'musica-loss' ) then
      new_obj => loss_t( config, domain, output )
    else
      call die_msg( 935006810, "Unsupported model component type: '"//        &
                               component_type%to_char( )//"'" )
    end if

  end function component_builder

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_component_factory
