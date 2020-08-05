! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The MusicBox program

!> Driver for the MusicBox model
program music_box

  use music_box_core,                  only : core_t

  implicit none

  ! MusicBox Core
  type(core_t), allocatable :: core
  ! Path to the configuration file
  character(len=256) :: config_file_name

  ! Get the model configuration file from the command line
  if( command_argument_count( ) .ne. 1 ) then
    write(*,*) "Usage: ./musicbox configuration_file.json"
    stop 3
  end if
  call get_command_argument( 1, config_file_name )

  allocate( core )
  core = core_t( config_file_name )
  call core%run( )
  deallocate( core )

end program music_box
