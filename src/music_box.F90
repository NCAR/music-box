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
  class(core_t), pointer :: core
  ! Path to the configuration file
  character(len=256) :: config_file_name
  ! Command-line options
  character(len=256) :: argument
  ! Command-line argument index
  integer :: i_arg
  ! Preprocess input data only
  logical :: preprocess_only = .false.

  character(len=*), parameter :: kDoneFile = 'MODEL_RUN_COMPLETE'
  character(len=*), parameter :: kRunningFile = 'MODEL_RUNNING'

  ! Get the model configuration file and options from the command line
  if( command_argument_count( ) .lt. 1 ) call fail_run( )
  call get_command_argument( command_argument_count( ), config_file_name )
  do i_arg = 1, command_argument_count( ) - 1
    call get_command_argument( i_arg, argument )
    if( trim( argument ) .eq. "--preprocess-only" ) then
      preprocess_only = .true.
    else
      call fail_run( )
    end if
  end do

  open(unit=10, file=kRunningFile)
  write(10,*) "running"
  close(10)

  core => core_t( config_file_name )

  if( preprocess_only ) then
    call execute_command_line( 'mkdir -p preprocessor_output/' )
    call core%preprocess_input( 'preprocessor_output/' )
  else
    call core%run( )
  end if

  deallocate( core )

  open(unit=10, file=kDoneFile)
  write(10,*) "complete"
  close(10)

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Fail run and print usage info
  subroutine fail_run( )

    write(*,*) "Usage: ./musicbox [<options>] configuration_file.json"
    write(*,*)
    write(*,*) "OPTIONS"
    write(*,*) "--preprocess-only : Converts input data to standard "//       &
               "MUSICA format for repeat runs"
    write(*,*)
    stop 3

  end subroutine fail_run

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program music_box
