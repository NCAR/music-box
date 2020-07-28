!> \file
!> Tests for the musica_config module

!> Test module for the musica_config module
program test_config

  use musica_assert
  use musica_config

  implicit none

  call test_config_t( )
  call config_example( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Test config_t functionality
  subroutine test_config_t( )

    use musica_constants,              only : musica_rk, musica_dk, musica_ik
    use musica_iterator,               only : iterator_t
    use musica_string,                 only : string_t

    type(config_t) :: a, a_file, b, c
    real(kind=musica_rk) :: ra
    real(kind=musica_dk) :: da
    integer(kind=musica_ik) :: ia
    logical :: la, found
    type(string_t) :: sa, sb
    type(string_t), allocatable :: saa(:), sab(:)
    character(len=*), parameter :: my_name = "config tests"
    class(iterator_t), pointer :: iterator

    ! constructors

    call a%empty( )
    call a_file%from_file( "data/test_config.json" )

    ! get config

    call a_file%get( "my sub object", b, my_name, found = found )
    call assert( 169832207, found )

    call b%get( "sub real", da, my_name )
    call assert( 630635145, almost_equal( da, 87.3d0 ) )

    call b%get( "sub int", ia, my_name )
    call assert( 892957756, ia .eq. 42 )

    call b%get( "really?", la, my_name )
    call assert( 389656885, la )

    call b%get( "a bunch of strings", saa, my_name )
    call assert( 603764961, size( saa ) .eq. 3 )
    call assert( 210876901, saa(1) .eq. "bar" )
    call assert( 325100780, saa(2) .eq. "foo" )
    call assert( 202253821, saa(3) .eq. "barfoo" )

    call b%finalize( )
    call a_file%get( "not there", b, my_name, found = found )
    call assert( 430701579, .not. found )

    call b%finalize( )
    c = '{ "an int" : 13, "foo" : "bar" }'
    call a_file%get( "not there", b, my_name, default = c, found = found )
    call assert( 250468356, .not. found )
    call b%get( "foo", sa, my_name )
    call assert( 464576432, sa .eq. "bar" )
    call b%get( "an int", ia, my_name )
    call assert( 457145065, ia .eq. 13 )

    ! get string

    call a_file%get( "a string", sa, my_name )
    call assert( 651552798, sa .eq. "foo" )
    call a_file%get( "another string", sa, my_name, found = found )
    call assert( 411575482, found )
    call assert( 927310501, sa .eq. "bar" )
    call a_file%get( "a string", sa, my_name, default = "default value" )
    call assert( 292539591, sa .eq. "foo" )
    call a_file%get( "not there", sa, my_name, default = "default value", found = found )
    call assert( 968355195, .not. found )
    call assert( 345566138, sa .eq. "default value" )

    ! get property
    call a_file%get( "some time", "s", da, my_name )
    call assert( 741099150, almost_equal( da, 24.5d0 * 60.0d0 ) )
    call a_file%get( "some pressure", "Pa", da, my_name, found = found )
    call assert( 731022831, found )
    call assert( 338134771, almost_equal( da, 0.94d0 * 101325.0d0 ) )
    call a_file%get( "some time", "s", da, my_name, default = 32.4d0 )
    call assert( 270219893, almost_equal( da, 24.5d0 * 60.0d0 ) )
    call a_file%get( "not there", "K", da, my_name, default = 256.7d0, found = found )
    call assert( 763444445, .not. found )
    call assert( 705605886, da .eq. 256.7d0 )

    ! get integer

    call a_file%get( "another int", ia, my_name )
    call assert( 851875875, ia .eq. 31 )
    call a_file%get( "my integer", ia, my_name, found = found )
    call assert( 338046390, found )
    call assert( 397790483, ia .eq. 12 )
    call a_file%get( "another int", ia, my_name, default = 42 )
    call assert( 271584751, ia .eq. 31 )
    call a_file%get( "not there", ia, my_name, default = 96, found = found )
    call assert( 440288416, .not. found )
    call assert( 382449857, ia .eq. 96 )

    ! get real

    call a_file%get( "this real", ra, my_name )
    call assert( 821646918, almost_equal( ra, 23.4 ) )
    call a_file%get( "that real", ra, my_name, found = found )
    call assert( 425400085, found )
    call assert( 702611027, almost_equal( ra, 52.3e-4 ) )
    call a_file%get( "this real", ra, my_name, default = 432.5 )
    call assert( 901830772, almost_equal( ra, 23.4e0 ) )
    call a_file%get( "not there", ra, my_name, default = 643.78, found = found )
    call assert( 505583939, .not. found )
    call assert( 165270131, ra .eq. 643.78 )

    ! get double

    call a_file%get( "this real", da, my_name )
    call assert( 155933230, almost_equal( da, 23.4d0 ) )
    call a_file%get( "that real", da, my_name, found = found )
    call assert( 550726824, found )
    call assert( 663045169, almost_equal( da, 52.3d-4 ) )
    call a_file%get( "this real", da, my_name, default = 432.5d0 )
    call assert( 775363514, almost_equal( da, 23.4d0 ) )
    call a_file%get( "not there", da, my_name, default = 643.78d0, found = found )
    call assert( 887681859, .not. found )
    call assert( 435049706, da .eq. 643.78d0 )

    ! get boolean

    call a_file%get( "is it?", la, my_name )
    call assert( 807245669, .not. la )
    call a_file%get( "is it really?", la, my_name, found = found )
    call assert( 405734529, found )
    call assert( 630371219, la )
    call a_file%get( "is it?", la, my_name, default = .false. )
    call assert( 511335328, .not. la )
    call a_file%get( "not there", la, my_name, default = .true., found = found )
    call assert( 672869152, .not. found )
    call assert( 227406840, la )

    ! get string array

    call a_file%get( "a bunch of strings", saa, my_name )
    call assert( 215424987, size( saa ) .eq. 3 )
    call assert( 834855271, saa(1) .eq. "foo" )
    call assert( 376958811, saa(2) .eq. "bar" )
    call assert( 884070750, saa(3) .eq. "foobar" )
    call a_file%get( "another bunch of strings", saa, my_name, found = found )
    call assert( 821420179, found )
    call assert( 533680623, size( saa ) .eq. 2 )
    call assert( 875899965, saa(1) .eq. "boo" )
    call assert( 135528256, saa(2) .eq. "far" )
    allocate( sab(2) )
    sab(1) = "default 1"
    sab(2) = "default 2"
    call a_file%get( "a bunch of strings", saa, my_name, default = sab )
    call assert( 802720780, size( saa ) .eq. 3 )
    call assert( 632563876, saa(1) .eq. "foo" )
    call assert( 127357471, saa(2) .eq. "bar" )
    call assert( 857200566, saa(3) .eq. "foobar" )
    call a_file%get( "not there", saa, my_name, default = sab, found = found )
    call assert( 801267541, .not. found )
    call assert( 513527985, size( saa ) .eq. 2 )
    call assert( 120639925, saa(1) .eq. "default 1" )
    call assert( 792644461, saa(2) .eq. "default 2" )

    ! add config

    call a%finalize( )
    call b%finalize( )
    call c%finalize( )
    a = '{ "some int" : 1263 }'
    b = '{ "some real" : 14.3, "some string" : "foo" }'
    call a%add( "sub props", b, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 762415504, ia .eq. 1263 )
    call a%get( "sub props", c, my_name )
    call c%get( "some string", sa, my_name )
    call assert( 643379613, sa .eq. "foo" )
    call c%get( "some real", da, my_name )
    call assert( 252397087, almost_equal( da, 14.3d0 ) )

    ! add char array

    call a%add( "new char array", "new char array value", my_name )
    call a%get( "some int", ia, my_name )
    call assert( 575490332, ia .eq. 1263 )
    call a%get( "new char array", sa, my_name )
    call assert( 110876326, sa .eq. "new char array value" )

    ! add string

    sa = "new string value"
    call a%add( "new string", sa, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 428870436, ia .eq. 1263 )
    call a%get( "new string", sb, my_name )
    call assert( 258713532, sb .eq. "new string value" )

    ! add property

    call a%add( "new pressure", "atm", 0.9765d0, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 671014812, ia .eq. 1263 )
    call a%get( "new pressure", "Pa", da, my_name )
    call assert( 779974384, almost_equal( da, 0.9765d0 * 101325.0d0 ) )

    ! add int

    call a%add( "new int", 432, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 601194400, ia .eq. 1263 )
    call a%get( "new int", ia, my_name )
    call assert( 827736624, ia .eq. 432 )

    ! add float

    call a%add( "new float", 12.75, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 313907139, ia .eq. 1263 )
    call a%get( "new float", ra, my_name )
    call assert( 875498864, almost_equal( ra, 12.75 ) )

    ! add double

    call a%add( "new double", 53.6d0, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 470628951, ia .eq. 1263 )
    call a%get( "new double", da, my_name )
    call assert( 468723417, almost_equal( da, 53.60d0 ) )

    ! add logical

    call a%add( "new logical", .true., my_name )
    call a%get( "some int", ia, my_name )
    call assert( 570965443, ia .eq. 1263 )
    call a%get( "new logical", la, my_name )
    call assert( 128861904, la )

    ! add string array

    if( allocated( saa ) ) deallocate( saa )
    if( allocated( sab ) ) deallocate( sab )
    allocate( saa(2) )
    saa(1) = "foo"
    saa(2) = "bar"
    call a%add( "new string array", saa, my_name )
    call a%get( "some int", ia, my_name )
    call assert( 729592789, ia .eq. 1263 )
    call a%get( "new string array", sab, my_name )
    call assert( 225839623, size( sab ) .eq. 2 )
    call assert( 115426812, sab(1) .eq. "foo" )
    call assert( 275055102, sab(2) .eq. "bar" )

    ! assignment

    call a%finalize( )
    call b%finalize( )
    call c%finalize( )
    a = '{ "my favorite int" : 42 }'
    b = a
    call b%get( "my favorite int", ia, my_name )
    call assert( 679211194, ia .eq. 42 )
    sa = '{ "another int" : 532 }'
    c = sa
    call c%get( "another int", ia, my_name )
    call assert( 842650552, ia .eq. 532 )

    call a%finalize( )
    call a_file%finalize( )
    call b%finalize( )
    call c%finalize( )

    ! iterator
    a = '{ "my int" : 2,'//&
        '  "my real" : 4.2,'//&
        '  "my double" : 5.2,'//&
        '  "my logical" : true,'//&
        '  "my string" : "foo bar",'//&
        '  "my sub config" : { "an int" : 3, "a double" : 6.7 },'//&
        '  "my property [K]" : 295.6,'//&
        '  "my string array" : [ "foo", "bar", "foobar" ] }'
    iterator => a%get_iterator( )
    call assert( 909667855, iterator%next( ) )
    call a%get( iterator, ia, my_name )
    call assert( 227587000, ia .eq. 2 )
    call assert( 217058386, iterator%next( ) )
    call a%get( iterator, ra, my_name )
    call assert( 391026358, almost_equal( ra, 4.2 ) )
    call assert( 270084933, iterator%next( ) )
    call a%get( iterator, da, my_name )
    call assert( 384308812, almost_equal( da, 5.2d0 ) )
    call assert( 826412351, iterator%next( ) )
    call a%get( iterator, la, my_name )
    call assert( 258103080, la )
    call assert( 147690269, iterator%next( ) )
    call a%get( iterator, sa, my_name )
    call assert( 361110121, sa .eq. "foo bar" )
    call assert( 468164159, iterator%next( ) )
    call a%get( iterator, b, my_name )
    call b%get( "a double", da, my_name )
    call assert( 749186169, almost_equal( da, 6.7d0 ) )
    call b%get( "an int", ia, my_name )
    call assert( 915984300, ia .eq. 3 )
    call assert( 182782432, iterator%next( ) )
    call a%get( iterator, "K", da, my_name )
    call assert( 739109850, almost_equal( da, 295.6d0 ) )
    call assert( 846163888, iterator%next( ) )
    call a%get( iterator, saa, my_name )
    call assert( 902549208, saa(1) .eq. "foo" )
    call assert( 334239937, saa(2) .eq. "bar" )
    call assert( 164083033, saa(3) .eq. "foobar" )
    call assert( 441293975, .not. iterator%next( ) )
    call iterator%reset( )
    call assert( 102885701, iterator%next( ) )
    call a%get( iterator, ia, my_name )
    call assert( 162629794, ia .eq. 2 )

    call a%finalize( )
    call b%finalize( )
    deallocate( iterator )

  end subroutine test_config_t

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Test the \c config_t example code
  subroutine config_example( )

use musica_config,                   only : config_t
use musica_constants,                only : musica_dk, musica_ik
use musica_iterator,                 only : iterator_t
use musica_string,                   only : string_t
 
character(len=*), parameter :: my_name = "config file example"
type(config_t) :: main_config, sub_config, sub_real_config
real(musica_dk) :: my_real
integer(musica_ik) :: my_int
type(string_t) :: my_string
class(iterator_t), pointer :: iter
logical :: found
 
call main_config%from_file( 'data/config_example.json' )
 
! this would fail with an error if 'a string' is not found
call main_config%get( "a string", my_string, my_name )
write(*,*) "a string value: ", my_string
 
! add the found argument to avoid failure if the pair is not found
call main_config%get( "my int", my_int, my_name, found = found )
if( found ) then
  write(*,*) "my int value: ", my_int
else
  write(*,*) "'my int' was not found"
end if
 
! when you get a subset of the properties, a new config_t object is
! created containing the subset data. The two config_t objects are
! independent of one another after this point.
call main_config%get( "other props", sub_config, my_name )
call sub_config%get( "an int", my_int, my_name )
write(*,*) "other props->an int value: ", my_int
 
! property values need a standard unit to convert to.
! time units must be passed the standard unit 's'
! (non-standard units may be used in the config file, but you cannot
!  request non-standard units in the model.)
call sub_config%get( "some time", "s", my_real, my_name )
write(*,*) "other props->some time value: ", my_real, " s"
 
! units are case-insensitive
call sub_config%get( "a pressure", "pa", my_real, my_name )
write(*,*) "other props->a pressure value: ", my_real, " Pa"
 
! you can iterate over a set of key-value pairs. but remember that
! the order is always arbitrary. you also must provide the right type
! of variable for the values.
call main_config%get( "real props", sub_real_config, my_name )
iter => sub_real_config%get_iterator( )
do while( iter%next( ) )
  my_string = sub_real_config%key( iter )
  call sub_real_config%get( iter, my_real, my_name )
  write(*,*) my_string, " value: ", my_real
end do
 
! you can add key-value pairs with the add function
call main_config%add( "my new int", 43, my_name )
call main_config%get( "my new int", my_int, my_name )
write(*,*) "my new int value: ", my_int
 
! clean up all the config objects when you're done with them
call main_config%finalize( )
call sub_config%finalize( )
call sub_real_config%finalize( )
deallocate( iter )

  end subroutine config_example

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program test_config
