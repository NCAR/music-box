!> \file
!> Output stream factory

!> Builder of output streams
module musica_output_factory

  use musica_output,                   only : output_t
  use musica_output_text,              only : output_text_t

  implicit none
  private

  public :: output_builder

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Build an output stream by name
  function output_builder( config ) result( new_output )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_string,                 only : string_t

    !> New output stream
    class(output_t), pointer :: new_output
    !> Output configration data
    class(config_t), intent(inout) :: config

    type(string_t) :: output_type
    character(len=*), parameter :: my_name = 'output builder'

    new_output => null( )
    call config%get( 'format', output_type, my_name )
    output_type = output_type%to_lower( )

    if( output_type .eq. 'txt' .or.                                           &
        output_type .eq. 'text' .or.                                          &
        output_type .eq. 'csv' ) then
      new_output => output_text_t( config )
    else
      call die_msg( 690482624, "Invalid output type: '"//                     &
                               output_type%to_char( )//"'" )
    end if

  end function output_builder

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_output_factory
