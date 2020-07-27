!> \file
!> Tests for the musica_convert module

!> Test module for the musica_convert module
program test_util_convert

  implicit none

  call test_convert_t( )
  call test_example( )

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Test convert_t functionality
  subroutine test_convert_t( )

    use musica_assert
    use musica_constants,              only : musica_dk, PI => kPi,           &
                                              AVAGADRO => kAvagadro
    use musica_convert

    type(convert_t) :: a
    real(kind=musica_dk) :: ra, rb, rc, lon, cell_height

    ! UTC (standard unit: s)

    a = convert_t( "UTC", "UTC" )
    ra = 35762.3 ! some UTC in seconds
    call assert( 114091117, a%to_non_standard( ra ) .eq. ra )
    call assert( 158042289, a%to_standard( ra ) .eq. ra )
    call assert( 736490495, a%standard_units( ) .eq. 'utc' )

    a = convert_t( "UTC", "UTC+12" )
    ra = 12.0d0 * 60.0d0 * 60.0d0 ! 12 hours in seconds
    rb = 356.0 ! some UTC in seconds
    rc = a%to_non_standard( rb )
    call assert( 149572774, almost_equal( rc, rb + ra ) )
    call assert( 363680850, almost_equal( a%to_standard( rc ), rb ) )
    call assert( 220755476, a%standard_units( ) .eq. 'utc' )

    a = convert_t( "UTC", "UTC-6.5" )
    ra = -6.5d0 * 60.0d0 * 60.0d0 ! -6.5 hours in seconds
    rb = 452.6 ! some UTC in seconds
    rc = a%to_non_standard( rb )
    call assert( 140121895, almost_equal( rc, rb + ra ) )
    call assert( 312184333, almost_equal( a%to_standard( rc ), rb ) )
    call assert( 484983621, a%standard_units( ) .eq. 'utc' )

    a = convert_t( "UTC", "LoCaL SoLaR TiMe" )
    lon = -93.4 / 180.0d0 * PI ! some longitude in radians
    ra = 24.0d0 * 60.0d0 * 60.0d0  ! 24 hours in seconds
    rb = 345.2 ! some UTC in seconds
    rc = a%to_non_standard( rb, longitude__rad = lon )
    call assert( 333815807, almost_equal( rc, mod( lon * ra / ( 2.0d0 * PI )  &
                                                   + rb + ra, ra ) ) )
    call assert( 839022212,                                                   &
                 almost_equal( mod( a%to_standard( rc, longitude__rad = lon ) &
                                    + ra, ra ), mod( rb + ra, ra ) ) )
    call assert( 879777215, a%standard_units( ) .eq. 'utc' )

    a = convert_t( "UTC", "LST" )
    lon = 143.2 / 180.0d0 * PI ! some longitude in radians
    ra = 24.0d0 * 60.0d0 * 60.0d0  ! 24 hours in seconds
    rb = 1295.3 ! some UTC in seconds
    rc = a%to_non_standard( rb, longitude__rad = lon )
    call assert( 362139230, almost_equal( rc, mod( lon * ra / ( 2.0d0 * PI )  &
                                                   + rb + ra, ra ) ) )
    call assert( 314829285,                                                   &
                 almost_equal( mod( a%to_standard( rc, longitude__rad = lon ) &
                                    + ra, ra ), mod( rb + ra, ra ) ) )
    call assert( 592037659, a%standard_units( ) .eq. 'utc' )

    ! temperature (standard units: K)

    a = convert_t( "K", "K" )
    ra = 298.64 ! some temp in K
    call assert( 270812929, a%to_non_standard( ra ) .eq. ra )
    call assert( 660342216, a%to_standard( ra ) .eq. ra )
    call assert( 369306503, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "degrees C" )
    ra = 251.24 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 472288115, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 863722936, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 764100097, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "deg_C" )
    ra = 432.67 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 292507187, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 404825532, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 258893692, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "deg C" )
    ra = 241.56 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 452135477, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 281978573, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 371212037, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "°C" )
    ra = 146.34 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 676772167, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 171565762, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 136046733, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "℃" )
    ra = 93.23 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 672699573, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 277905979, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 530840327, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "C" )
    ra = 214.57 ! some temp in K
    rb = ra - 273.15d0 ! same temp in degree C
    call assert( 231309855, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 343628200, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 360683423, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "degrees F" )
    ra = 432.56 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 587990830, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 695044868, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 755477017, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "deg_F" )
    ra = 241.56 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 234241930, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 964085025, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 867795362, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "deg F" )
    ra = 265.87 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 741353869, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 571196965, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 645064206, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "°F" )
    ra = 196.79 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 348465809, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 178308905, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 474907302, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "℉" )
    ra = 276.53 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 173044598, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 285362943, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 869700896, a%standard_units( ) .eq. 'k' )

    a = convert_t( "K", "F" )
    ra = 352.45 ! some temp in K
    rb = ra * 9.0d0 / 5.0d0 - 273.15d0 * 9.0d0 / 5.0d0 + 32.0d0 ! same temp in degree F
    call assert( 397681288, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 227524384, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 982019241, a%standard_units( ) .eq. 'k' )

    ! pressure (standard units: Pa)

    a = convert_t( "Pa", "Pa" )
    ra = 24950.30 ! some pressure in Pa
    call assert( 199086983, a%to_non_standard( ra ) .eq. ra )
    call assert( 200992517, a%to_standard( ra ) .eq. ra )
    call assert( 129329187, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "hPa" )
    ra = 329405.42 ! some pressure in Pa
    rb = ra / 100.0d0 ! same pressure in hPa
    call assert( 131172105, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 580445485, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 306655932, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "mbar" )
    ra = 95847.80 ! some pressure in Pa
    rb = ra / 100.0d0 ! same pressure in mbar
    call assert( 383870692, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 213713788, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 353965877, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "kPa" )
    ra = 84758.235 ! some pressure in Pa
    rb = ra / 1000.0d0 ! same pressure in kPa
    call assert( 261023733, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 938292576, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 183808973, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "atm" )
    ra = 104857.7 ! some pressure in Pa
    rb = ra / 101325.0d0 ! same pressure in atm
    call assert( 433086171, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 262929267, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 578602567, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "bar" )
    ra = 294596.837 ! some pressure in Pa
    rb = ra * 1.0d-5 ! same pressure in bar
    call assert( 375247612, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 487565957, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 690920912, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "mmHg" )
    ra = 105948.3 ! some pressure in Pa
    rb = ra / 133.0d0 ! same pressure in mmHg
    call assert( 599884302, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 712202647, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 185714507, a%standard_units( ) .eq. 'pa' )

    a = convert_t( "Pa", "torr" )
    ra = 98634.958 ! some pressure in Pa
    rb = ra / 133.0d0 ! same pressure in torr
    call assert( 206996242, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 319314587, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 298032852, a%standard_units( ) .eq. 'pa' )

    ! species concentrations (standard units: mol m-3)

    a = convert_t( "mol m-3", "mol m-3" )
    ra = 0.3456 ! some concentration in mol m-3
    call assert( 886457742, a%to_non_standard( ra ) .eq. ra )
    call assert( 428561282, a%to_standard( ra ) .eq. ra )
    call assert( 410351197, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "mol/m3" )
    ra = 0.74583 ! some concentration in mol m-3
    call assert( 139820782, a%to_non_standard( ra ) .eq. ra )
    call assert( 869663877, a%to_standard( ra ) .eq. ra )
    call assert( 522669542, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "mole m-3" )
    ra = 0.0954 ! some concentration in mol m-3
    call assert( 364457472, a%to_non_standard( ra ) .eq. ra )
    call assert( 194300568, a%to_standard( ra ) .eq. ra )
    call assert( 352512638, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "mole/m3" )
    ra = 0.1746 ! some concentration in mol m-3
    call assert( 241610513, a%to_non_standard( ra ) .eq. ra )
    call assert( 418937258, a%to_standard( ra ) .eq. ra )
    call assert( 464830983, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "moles m-3" )
    ra = 0.0475 ! some concentration in mol m-3
    call assert( 183771954, a%to_non_standard( ra ) .eq. ra )
    call assert( 578565548, a%to_standard( ra ) .eq. ra )
    call assert( 577149328, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "moles/m3" )
    ra = 0.2375 ! some concentration in mol m-3
    call assert( 690883893, a%to_non_standard( ra ) .eq. ra )
    call assert( 238251740, a%to_standard( ra ) .eq. ra )
    call assert( 971942922, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molecule m-3" )
    ra = 0.0897 ! some concentration in mol m-3
    rb = ra * AVAGADRO ! same concentration in molecules m-3
    call assert( 257690557, a%to_non_standard( ra ) .eq. ra )
    call assert( 987533652, a%to_standard( ra ) .eq. ra )
    call assert( 119252868, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molecule/m3" )
    ra = 0.34758 ! some concentration in mol m-3
    rb = ra * AVAGADRO ! same concentration in molecules m-3
    call assert( 764802496, a%to_non_standard( ra ) .eq. ra )
    call assert( 594645592, a%to_standard( ra ) .eq. ra )
    call assert( 231571213, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molec m-3" )
    ra = 0.7453 ! some concentration in mol m-3
    rb = ra * AVAGADRO ! same concentration in molecules m-3
    call assert( 706963937, a%to_non_standard( ra ) .eq. ra )
    call assert( 201757532, a%to_standard( ra ) .eq. ra )
    call assert( 343889558, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molec/m3" )
    ra = 0.1534 ! some concentration in mol m-3
    rb = ra * AVAGADRO ! same concentration in molecules m-3
    call assert( 314075877, a%to_non_standard( ra ) .eq. ra )
    call assert( 761443723, a%to_standard( ra ) .eq. ra )
    call assert( 456207903, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "mol cm-3" )
    ra = 0.9845 ! some concentration in mol m-3
    rb = ra * 1.0d-6 ! same concentration in mol cm-3
    call assert( 256237318, a%to_non_standard( ra ) .eq. ra )
    call assert( 703605164, a%to_standard( ra ) .eq. ra )
    call assert( 568526248, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "mol/cm3" )
    ra = 0.2756 ! some concentration in mol m-3
    rb = ra * 1.0d-6 ! same concentration in mol cm-3
    call assert( 815923509, a%to_non_standard( ra ) .eq. ra )
    call assert( 645766605, a%to_standard( ra ) .eq. ra )
    call assert( 398369344, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molecule cm-3" )
    ra = 0.8976 ! some concentration in mol m-3
    rb = ra * AVAGADRO * 1.0d-6 ! same concentration in molecules cm-3
    call assert( 475609701, a%to_non_standard( ra ) .eq. ra )
    call assert( 587928046, a%to_standard( ra ) .eq. ra )
    call assert( 510687689, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molecule/cm3" )
    ra = 0.5642 ! some concentration in mol m-3
    rb = ra * AVAGADRO * 1.0d-6 ! same concentration in molecules cm-3
    call assert( 700246391, a%to_non_standard( ra ) .eq. ra )
    call assert( 247614238, a%to_standard( ra ) .eq. ra )
    call assert( 340530785, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molec cm-3" )
    ra = 0.2867 ! some concentration in mol m-3
    rb = ra * AVAGADRO * 1.0d-6 ! same concentration in molecules cm-3
    call assert( 359932583, a%to_non_standard( ra ) .eq. ra )
    call assert( 472250928, a%to_standard( ra ) .eq. ra )
    call assert( 452849130, a%standard_units( ) .eq. 'mol m-3' )

    a = convert_t( "mol m-3", "molec/cm3" )
    ra = 0.9087 ! some concentration in mol m-3
    rb = ra * AVAGADRO * 1.0d-6 ! same concentration in molecules cm-3
    call assert( 584569273, a%to_non_standard( ra ) .eq. ra )
    call assert( 696887618, a%to_standard( ra ) .eq. ra )
    call assert( 565167475, a%standard_units( ) .eq. 'mol m-3' )

    ! time (standard units: s)

    a = convert_t( "s", "s" )
    ra = 2349.532 ! some time in seconds
    call assert( 570733080, a%to_non_standard( ra ) .eq. ra )
    call assert( 512894521, a%to_standard( ra ) .eq. ra )
    call assert( 959961069, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "sec")
    ra = 9284.2 ! some time in seconds
    call assert( 342737617, a%to_non_standard( ra ) .eq. ra )
    call assert( 455055962, a%to_standard( ra ) .eq. ra )
    call assert( 789804165, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "second" )
    ra = 9384.50 ! some time in seconds
    call assert( 567374307, a%to_non_standard( ra ) .eq. ra )
    call assert( 114742154, a%to_standard( ra ) .eq. ra )
    call assert( 902122510, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "seconds" )
    ra = 26354.5847 ! some time in seconds
    call assert( 844585249, a%to_non_standard( ra ) .eq. ra )
    call assert( 674428345, a%to_standard( ra ) .eq. ra )
    call assert( 114440856, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "m" )
    ra = 395876.019 ! some time in seconds
    rb = ra / 60.0d0 ! same time in minutes
    call assert( 334114537, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 163957633, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 844283951, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "min" )
    ra = 34985.202 ! some time in seconds
    rb = ra / 60.0d0 ! same time in minutes
    call assert( 276275978, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 106119074, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 956602296, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "minute" )
    ra = 857362.41 ! some time in seconds
    rb = ra / 60.0d0 ! same time in minutes
    call assert( 448338416, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 895706262, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 168920642, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "minutes" )
    ra = 8982445.37 ! some time in seconds
    rb = ra / 60.0d0 ! same time in minutes
    call assert( 108024608, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 555392454, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 281238987, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "h" )
    ra = 12567.82 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 ! same time in hours
    call assert( 385235550, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 280087046, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 393557332, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "hr" )
    ra = 93857.3923 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 ! same time in hours
    call assert( 109930142, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 839773237, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 223400428, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "hour" )
    ra = 1276.52 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 ! same time in hours
    call assert( 669616333, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 216984180, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 335718773, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "hours" )
    ra = 763254.73 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 ! same time in hours
    call assert( 329302525, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 776670371, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 448037118, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "d" )
    ra = 83247.98671 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 / 24.0d0 ! same time in days
    call assert( 553939215, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 383782311, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 560355463, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "day" )
    ra = 92.987217 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 / 24.0d0 ! same time in days
    call assert( 496100656, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 943468502, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 672673808, a%standard_units( ) .eq. 's' )

    a = convert_t( "s", "days" )
    ra = 76123.214 ! some time in seconds
    rb = ra / 60.0d0 / 60.0d0 / 24.0d0 ! same time in days
    call assert( 773311598, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 320679445, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 784992153, a%standard_units( ) .eq. 's' )

    ! emissions rates (standard units: mol m-3 s-1)

    a = convert_t( "mol m-3 s-1", "mol m-3 s-1" )
    ra = 234.6823 ! some rate in mol m-3 s-1
    call assert( 393884227, a%to_non_standard( ra ) .eq. ra )
    call assert( 223727323, a%to_standard( ra ) .eq. ra )
    call assert( 614835249, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "moles/m3/s" )
    ra = 2395.29 ! some rate in mol m-3 s-1
    call assert( 336045668, a%to_non_standard( ra ) .eq. ra )
    call assert( 165888764, a%to_standard( ra ) .eq. ra )
    call assert( 727153594, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "mol m-3 hr-1" )
    ra = 938576.24 ! some rate in mol m-3 s-1
    rb = ra * 60.0d0 * 60.0d0 ! same rate in mol m-3 hr-1
    call assert( 895731859, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 725574955, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 839471939, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "mol/m3/hr" )
    ra = 8176.12 ! some rate in mol m-3 s-1
    rb = ra * 60.0d0 * 60.0d0 ! same rate in mol m-3 hr-1
    call assert( 272942802, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 720310648, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 951790284, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "mol m-2 min-1" )
    ra = 901285.32 ! some rate in mol m-3 s-1
    cell_height = 30.5d0 ! cell height in m
    rb = ra * cell_height * 60.0d0 ! same rate in mol m-2 min-1
    call assert( 832628993,                                                   &
                 almost_equal( a%to_non_standard( ra,                         &
                                 cell_height__m = cell_height ), rb ) )
    call assert( 445005240,                                                   &
                 almost_equal( a%to_standard( rb,                             &
                                 cell_height__m = cell_height ), ra ) )
    call assert( 381575479, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "mol/m2/min" )
    ra = 918.28934 ! some rate in mol m-3 s-1
    cell_height = 30.5d0 ! cell height in m
    rb = ra * cell_height * 60.0d0 ! same rate in mol m-2 min-1
    call assert( 274848336,                                                   &
                 almost_equal( a%to_non_standard( ra,                         &
                                 cell_height__m = cell_height ), rb ) )
    call assert( 722216182,                                                   &
                 almost_equal( a%to_standard( rb,                             &
                                 cell_height__m = cell_height ), ra ) )
    call assert( 493893824, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "molecules/cm2/s" )
    ra = 17284.235 ! some rate in mol m-3 s-1
    cell_height = 30.5d0 ! cell height in m
    rb = ra * cell_height * 1.0d-4 * AVAGADRO ! same rate in molec cm-2 s-1
    call assert( 552059278,                                                   &
                 almost_equal( a%to_non_standard( ra,                         &
                                 cell_height__m = cell_height ), rb ) )
    call assert( 999427124,                                                   &
                 almost_equal( a%to_standard( rb,                             &
                                 cell_height__m = cell_height ), ra ) )
    call assert( 888687418, a%standard_units( ) .eq. 'mol m-3 s-1' )

    a = convert_t( "mol m-3 s-1", "molecules/cm3/s" )
    ra = 192850.234 ! some rate in mol m-3 s-1
    rb = ra * 1.0d-6 * AVAGADRO ! same rate in molec cm-2 s-1
    call assert( 829270220, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 376638067, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 665956262, a%standard_units( ) .eq. 'mol m-3 s-1' )

    ! first order loss rates (standard units: s-1)

    a = convert_t( "s-1", "s-1" )
    ra = 2840.12389 ! some rate in s-1
    call assert( 731865803, a%to_non_standard( ra ) .eq. ra )
    call assert( 388193222, a%to_standard( ra ) .eq. ra )
    call assert( 443225106, a%standard_units( ) .eq. 's-1' )

    a = convert_t( "s-1", "1/s" )
    ra = 1295.42 ! some rate in s-1
    call assert( 485623236, a%to_non_standard( ra ) .eq. ra )
    call assert( 932991082, a%to_standard( ra ) .eq. ra )
    call assert( 490535051, a%standard_units( ) .eq. 's-1' )

    a = convert_t( "s-1", "sec-1" )
    ra = 509234.21 ! some rate in s-1
    call assert( 867721156, a%to_non_standard( ra ) .eq. ra )
    call assert( 362514751, a%to_standard( ra ) .eq. ra )
    call assert( 602853396, a%standard_units( ) .eq. 's-1' )

    a = convert_t( "s-1", "1/sec" )
    ra = 2395.2783 ! some rate in s-1
    call assert( 409824696, a%to_non_standard( ra ) .eq. ra )
    call assert( 522143041, a%to_standard( ra ) .eq. ra )
    call assert( 715171741, a%standard_units( ) .eq. 's-1' )

    a = convert_t( "s-1", "h-1")
    ra = 82.231 ! some rate in s-1
    rb = ra * 60.0d0 * 60.0d0 ! same rate in h-1
    call assert( 634461386, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 129254981, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 827490086, a%standard_units( ) .eq. 's-1' )

    a = convert_t( "s-1", "1/hour")
    ra = 9387582.213 ! some rate in s-1
    rb = ra * 60.0d0 * 60.0d0 ! same rate in h-1
    call assert( 806523824, almost_equal( a%to_non_standard( ra ), rb ) )
    call assert( 918842169, almost_equal( a%to_standard( rb ), ra ) )
    call assert( 657333182, a%standard_units( ) .eq. 's-1' )


  end subroutine test_convert_t

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine test_example( )

use musica_constants,                only : dk => musica_dk
use musica_convert,                  only : convert_t
use musica_string,                   only : string_t
 
type(convert_t) :: convert
type(string_t) :: str
real(kind=dk) :: a, long
 
convert = convert_t( "Pa", "atm" )     ! convert between [Pa] and [atm]
a = convert%to_standard( 0.915_dk )
write(*,*) 0.915, " atm is ", a, " Pa"
a = convert%to_non_standard( 103657.0_dk )
write(*,*) 103657.0, " Pa is ", a, " atm"
 
str = "Local solar time"
convert = convert_t( "UTC", str )      ! converts between [UTC] and [LST]
long = 2.564_dk                        ! a longitude in radians
a = convert%to_standard( 6.5_dk, longitude__rad = long )
write(*,*) 6.5_dk, " UTC [s] is ", a, " LST [s] at ", long / 3.14159265359 * 180.0, " deg W"

  end subroutine test_example

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end program test_util_convert
