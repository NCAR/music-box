// Copyright (C) 2020 National Center for Atmospheric Research
// SPDX-License-Identifier: Apache-2.0
//
/// \file
/// Compares MusicBox results for equality with provided tolerances
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int number_of_columns( FILE *file1, FILE *file2 ) {
  int c1, c2, n_col = 1;
  while( EOF != ( c1 = fgetc( file1 ) ) &&
         EOF != ( c2 = fgetc( file2 ) ) ) {
    if( c1 != c2 ) { printf( "\n\nERROR 1\n" ); exit( EXIT_FAILURE ); }
    if( c1 == '\n' ) return n_col;
    if( c1 == ' ' ) {
      ++n_col;
      while( EOF != ( c1 = fgetc( file1 ) ) &&
             EOF != ( c2 = fgetc( file2 ) ) ) {
        if( c1 != c2 ) { printf( "\n\nERROR 2\n" ); exit( EXIT_FAILURE ); }
        if( c1 == '\n' ) return n_col;
        if( c1 != ' ' ) break;
      }
    }
  }
  exit( EXIT_FAILURE );
}

int main( const int argc, const char *argv[] ) {

  FILE *file1, *file2;
  double abs_tol, rel_tol;

  if( argc != 5 ) {
    printf( "\nUsage: ./compare_results results_file_1 results_file_2 "
            "relative_tolerance absolute_tolerance\n\n" );
    return EXIT_FAILURE;
  }

  file1 = fopen( argv[1], "r" );
  if( file1 == 0 ) {
    printf( "\nCannot open file '%s'\n\n", argv[1] );
    return EXIT_FAILURE;
  }

  file2 = fopen( argv[2], "r" );
  if( file2 == 0 ) {
    printf( "\nCannot open file '%s'\n\n", argv[2] );
    fclose( file1 );
    return EXIT_FAILURE;
  }

  rel_tol = strtod( argv[3], NULL );
  abs_tol = strtod( argv[4], NULL );

  int n_col = number_of_columns( file1, file2 );

  while( 1 ) {
    for( int i = 0; i < n_col; ++i ) {
      double val1, val2;
      fscanf( file1, "%lg%*c", &val1 );
      fscanf( file2, "%lg%*c", &val2 );
      if( fabs( val1 - val2 ) > abs_tol &&
          fabs( val1 - val2 ) * 2.0 / fabs( val1 + val2 ) > rel_tol ) {
        printf( "\n\ndata mismatch %lg %lg\n", val1, val2 );
        exit( EXIT_FAILURE );
      }
    }
    fscanf( file1, "\n" );
    fscanf( file2, "\n" );
    if( feof( file1 ) && feof( file2 ) ) break;
    if( feof( file1 ) || feof( file2 ) ) { printf( "\n\nERROR 3\n" ); exit( EXIT_FAILURE ); }
  }
  fclose( file1 );
  fclose( file2 );

  return EXIT_SUCCESS;
}
