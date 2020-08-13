!> \file
!> Tests for the musica_domain_cell module

!> Test module for the musica_domain_cell module
program test_domain_cell

  use musica_assert
  use musica_domain_cell

  implicit none

  call test_domain_cell_t( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Test domain_t functionality
  subroutine test_domain_cell_t( )

    use musica_config,                 only : config_t
    use musica_constants,              only : dk => musica_dk
    use musica_domain,                 only : domain_t, domain_state_t,       &
                                              domain_state_mutator_t,         &
                                              domain_state_mutator_ptr,       &
                                              domain_state_accessor_t,        &
                                              domain_state_accessor_ptr,      &
                                              domain_iterator_t
    use musica_string,                 only : string_t

    class(domain_t), pointer :: domain
    type(config_t) :: config
    class(domain_state_t), pointer :: state, state2
    class(domain_iterator_t), pointer :: iter
    class(domain_state_mutator_t), pointer :: mut_ra, mut_rb, mut_la, mut_lb
    class(domain_state_mutator_t), pointer :: mut_ra2, mut_la2
    class(domain_state_accessor_t), pointer :: acc_ra, acc_rb, acc_la, acc_lb
    class(domain_state_accessor_t), pointer :: acc_ra2, acc_la2
    class(domain_state_mutator_ptr), pointer :: mut_set(:), mut_set2(:)
    class(domain_state_accessor_ptr), pointer :: acc_set(:), acc_set2(:)
    type(string_t) :: var_set_names(3)
    type(string_t), allocatable :: set_names(:)
    character(len=*), parameter :: my_name = "domain_cell_t tests"
    integer :: i
    type(string_t) :: temp_str
    real(kind=dk) :: temp_real
    logical :: temp_bool

    ! constructor
    ! (no config information is needed)
    call config%empty( )
    domain => domain_cell_t( config )

    var_set_names(1) = "var 1"
    var_set_names(2) = "var 2"
    var_set_names(3) = "var 3"

    ! register
    call domain%register_cell_state_variable( "ra", "s", 12.3_dk, my_name )
    mut_ra => domain%cell_state_mutator( "ra", "s", my_name )
    call domain%register_cell_state_variable( "rb", "K", 1.54_dk, my_name )
    mut_rb => domain%cell_state_mutator( "rb", "K", my_name )
    call domain%register_cell_state_variable_set( "my set",                   &
                                                  "Pa",                       &
                                                  13.2_dk,                    &
                                                  var_set_names,              &
                                                  my_name )
    mut_set => domain%cell_state_set_mutator( "my set", "Pa", set_names,      &
                                               my_name )
    call domain%register_cell_flag( "la", .true.,  my_name )
    mut_la  => domain%cell_flag_mutator( "la", my_name )
    call domain%register_cell_flag( "lb", .false., my_name )
    mut_lb  => domain%cell_flag_mutator( "lb", my_name )

    ! get mutators
    mut_ra2  => domain%cell_state_mutator( "ra", "s", my_name )
    mut_set2 => domain%cell_state_set_mutator( "my set", "Pa", set_names,     &
                                               my_name )
    call assert( 930747579, size( set_names ) .eq. size( var_set_names ) )
    do i = 1, size( set_names )
      call assert( 134442845, set_names(i) .eq. var_set_names(i) )
    end do
    mut_la2  => domain%cell_flag_mutator( "la", my_name )

    ! get accessors
    acc_ra  => domain%cell_state_accessor( "ra", "s", my_name )
    acc_rb  => domain%cell_state_accessor( "rb", "K", my_name )
    acc_set => domain%cell_state_set_accessor( "my set", "Pa", set_names,     &
                                               my_name )
    call assert( 441168923, size( set_names ) .eq. size( var_set_names ) )
    do i = 1, size( set_names )
      call assert( 553487268, set_names(i) .eq. var_set_names(i) )
    end do
    acc_la  => domain%cell_flag_accessor( "la", my_name )
    acc_lb  => domain%cell_flag_accessor( "lb", my_name )

    ! get a second set of accessors
    acc_ra2  => domain%cell_state_accessor( "ra", "s", my_name )
    acc_set2 => domain%cell_state_set_accessor( "my set", "Pa", set_names,     &
                                                my_name )
    call assert( 485572390, size( set_names ) .eq. size( var_set_names ) )
    do i = 1, size( set_names )
      call assert( 480308083, set_names(i) .eq. var_set_names(i) )
    end do
    acc_la2  => domain%cell_flag_accessor( "la", my_name )

    ! get domain state objects
    state  => domain%new_state( )
    state2 => domain%new_state( )

    ! check units
    temp_str = domain%cell_state_units( "ra" )
    call assert( 348289395, temp_str .eq. "s" )
    temp_str = domain%cell_state_units( "rb" )
    call assert( 844872720, temp_str .eq. "K" )
    temp_str = domain%cell_state_units( "my set%var 1" )
    call assert( 103047772, temp_str .eq. "Pa" )
    temp_str = domain%cell_state_units( "my set%var 2" )
    call assert( 382164248, temp_str .eq. "Pa" )
    temp_str = domain%cell_state_units( "my set%var 3" )
    call assert( 724383590, temp_str .eq. "Pa" )

    ! check for variables and flags
    call assert( 392097426, domain%is_cell_state_variable( "ra" ) )
    call assert( 169366270, domain%is_cell_state_variable( "rb" ) )
    call assert( 846635113, domain%is_cell_state_variable( "my set%var 1" ) )
    call assert( 341428708, domain%is_cell_state_variable( "my set%var 2" ) )
    call assert( 388738653, domain%is_cell_state_variable( "my set%var 3" ) )
    call assert( 501056998, .not. domain%is_cell_state_variable(              &
                                                              "not there" ) )
    call assert( 895850592, domain%is_cell_flag( "la" ) )
    call assert( 390644187, domain%is_cell_flag( "lb" ) )
    call assert( 102904631, .not. domain%is_cell_flag( "not there" ) )

    ! get an iterator
    iter => domain%cell_iterator( )

    ! default values for both states
    do while( iter%next( ) )
      call state%get( iter, acc_ra, temp_real )
      call assert( 203122738, temp_real .eq. 12.3_dk )
      call state%get( iter, acc_ra2, temp_real )
      call assert( 734033211, temp_real .eq. 12.3_dk )
      call state%get( iter, acc_rb, temp_real )
      call assert( 866504194, temp_real .eq. 1.54_dk )
      call state%get( iter, acc_set2(1)%val_, temp_real )
      call assert( 308723537, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_set2(2)%val_, temp_real )
      call assert( 303459230, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_set2(3)%val_, temp_real )
      call assert( 363203323, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_la, temp_bool )
      call assert( 285212126, temp_bool )
      call state%get( iter, acc_la2, temp_bool )
      call assert( 334427605, temp_bool )
      call state%get( iter, acc_lb, temp_bool )
      call assert( 101167835, .not. temp_bool )
      call state2%get( iter, acc_ra, temp_real )
      call assert( 203122738, temp_real .eq. 12.3_dk )
      call state2%get( iter, acc_ra2, temp_real )
      call assert( 947140343, temp_real .eq. 12.3_dk )
      call state2%get( iter, acc_rb, temp_real )
      call assert( 866504194, temp_real .eq. 1.54_dk )
      call state2%get( iter, acc_set(1)%val_, temp_real )
      call assert( 308723537, temp_real .eq. 13.2_dk )
      call state2%get( iter, acc_set(2)%val_, temp_real )
      call assert( 303459230, temp_real .eq. 13.2_dk )
      call state2%get( iter, acc_set(3)%val_, temp_real )
      call assert( 363203323, temp_real .eq. 13.2_dk )
      call state2%get( iter, acc_la, temp_bool )
      call assert( 831463225, temp_bool )
      call state2%get( iter, acc_la2, temp_bool )
      call assert( 261248420, temp_bool )
      call state2%get( iter, acc_lb, temp_bool )
      call assert( 438575165, .not. temp_bool )
    end do

    ! update state 2 with first set of mutators
    call iter%reset( )
    do while( iter%next( ) )
      call state2%update( iter, mut_ra, 65.4_dk )
      call state2%update( iter, mut_rb, 798.4_dk )
      call state2%update( iter, mut_set(1)%val_, 458.1_dk )
      call state2%update( iter, mut_set(2)%val_, 65.23_dk )
      call state2%update( iter, mut_set(2)%val_, 95.10_dk )
      call state2%update( iter, mut_la, .false. )
      call state2%update( iter, mut_lb, .true. )
    end do

    ! default values in state and updated values in state 2
    do while( iter%next( ) )
      call state%get( iter, acc_ra, temp_real )
      call assert( 408346208, temp_real .eq. 12.3_dk )
      call state%get( iter, acc_ra2, temp_real )
      call assert( 350507649, temp_real .eq. 12.3_dk )
      call state%get( iter, acc_rb, temp_real )
      call assert( 115342345, temp_real .eq. 1.54_dk )
      call state%get( iter, acc_set2(1)%val_, temp_real )
      call assert( 510135939, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_set2(2)%val_, temp_real )
      call assert( 904929533, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_set2(3)%val_, temp_real )
      call assert( 117247879, temp_real .eq. 13.2_dk )
      call state%get( iter, acc_la, temp_bool )
      call assert( 794516722, temp_bool )
      call state%get( iter, acc_la2, temp_bool )
      call assert( 736678163, temp_bool )
      call state%get( iter, acc_lb, temp_bool )
      call assert( 166463358, .not. temp_bool )
      call state2%get( iter, acc_ra, temp_real )
      call assert( 561256952, temp_real .eq. 65.4_dk )
      call state2%get( iter, acc_ra2, temp_real )
      call assert( 673575297, temp_real .eq. 65.4_dk )
      call state2%get( iter, acc_rb, temp_real )
      call assert( 168368892, temp_real .eq. 798.4_dk )
      call state2%get( iter, acc_set(1)%val_, temp_real )
      call assert( 563162486, temp_real .eq. 458.1_dk )
      call state2%get( iter, acc_set(2)%val_, temp_real )
      call assert( 957956080, temp_real .eq. 65.23_dk )
      call state2%get( iter, acc_set(3)%val_, temp_real )
      call assert( 782534869, temp_real .eq. 95.10_dk )
      call state2%get( iter, acc_la, temp_bool )
      call assert( 277328464, .not. temp_bool )
      call state2%get( iter, acc_la2, temp_bool )
      call assert( 389646809, .not. temp_bool )
      call state2%get( iter, acc_lb, temp_bool )
      call assert( 784440403, temp_bool )
    end do

    ! update some values in state 1 with second set of mutators
    call iter%reset( )
    do while( iter%next( ) )
      call state%update( iter, mut_ra2, 42.53_dk )
      call state%update( iter, mut_set2(1)%val_, 97.54_dk )
      call state%update( iter, mut_set2(2)%val_, 1.653_dk )
      call state%update( iter, mut_set2(2)%val_, 5.421_dk )
      call state%update( iter, mut_la2, .false. )
    end do

    ! some default values left in state
    do while( iter%next( ) )
      call state%get( iter, acc_ra, temp_real )
      call assert( 304938066, temp_real .eq. 42.53_dk )
      call state%get( iter, acc_ra2, temp_real )
      call assert( 982206909, temp_real .eq. 42.53_dk )
      call state%get( iter, acc_rb, temp_real )
      call assert( 129516855, temp_real .eq. 1.54_dk )
      call state%get( iter, acc_set2(1)%val_, temp_real )
      call assert( 524310449, temp_real .eq. 97.54_dk )
      call state%get( iter, acc_set2(2)%val_, temp_real )
      call assert( 636628794, temp_real .eq. 1.653_dk )
      call state%get( iter, acc_set2(3)%val_, temp_real )
      call assert( 748947139, temp_real .eq. 5.421_dk )
      call state%get( iter, acc_la, temp_bool )
      call assert( 861265484, .not. temp_bool )
      call state%get( iter, acc_la2, temp_bool )
      call assert( 356059079, .not. temp_bool )
      call state%get( iter, acc_lb, temp_bool )
      call assert( 750852673, .not. temp_bool )
      call state2%get( iter, acc_ra, temp_real )
      call assert( 863171018, temp_real .eq. 65.4_dk )
      call state2%get( iter, acc_ra2, temp_real )
      call assert( 975489363, temp_real .eq. 65.4_dk )
      call state2%get( iter, acc_rb, temp_real )
      call assert( 122799309, temp_real .eq. 798.4_dk )
      call state2%get( iter, acc_set(1)%val_, temp_real )
      call assert( 800068152, temp_real .eq. 458.1_dk )
      call state2%get( iter, acc_set(2)%val_, temp_real )
      call assert( 577336996, temp_real .eq. 65.23_dk )
      call state2%get( iter, acc_set(3)%val_, temp_real )
      call assert( 689655341, temp_real .eq. 95.10_dk )
      call state2%get( iter, acc_la, temp_bool )
      call assert( 801973686, .not. temp_bool )
      call state2%get( iter, acc_la2, temp_bool )
      call assert( 914292031, .not. temp_bool )
      call state2%get( iter, acc_lb, temp_bool )
      call assert( 126610377, temp_bool )
    end do

    ! clean up memory
    call config%finalize( )
    deallocate( domain )
    deallocate( state )
    deallocate( state2 )
    deallocate( iter )
    deallocate( var_set_names(1)%val_ )
    deallocate( var_set_names(2)%val_ )
    deallocate( var_set_names(3)%val_ )
    deallocate( mut_ra )
    deallocate( mut_rb )
    deallocate( mut_ra2 )
    deallocate( mut_set(1)%val_ )
    deallocate( mut_set(2)%val_ )
    deallocate( mut_set(3)%val_ )
    deallocate( mut_set )
    deallocate( mut_set2(1)%val_ )
    deallocate( mut_set2(2)%val_ )
    deallocate( mut_set2(3)%val_ )
    deallocate( mut_set2 )
    deallocate( mut_la )
    deallocate( mut_lb )
    deallocate( mut_la2 )
    deallocate( acc_ra )
    deallocate( acc_rb )
    deallocate( acc_ra2 )
    deallocate( acc_set(1)%val_ )
    deallocate( acc_set(2)%val_ )
    deallocate( acc_set(3)%val_ )
    deallocate( acc_set )
    deallocate( acc_set2(1)%val_ )
    deallocate( acc_set2(2)%val_ )
    deallocate( acc_set2(3)%val_ )
    deallocate( acc_set2 )
    deallocate( acc_la )
    deallocate( acc_lb )
    deallocate( acc_la2 )

  end subroutine test_domain_cell_t

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program test_domain_cell
