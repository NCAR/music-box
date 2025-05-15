#include <stdio.h>
#include <stdlib.h>
#include <netcdf.h>
#include <math.h>

typedef enum {false, true} bool;

void
check_err(const int stat, const int line, const char *file) {
    if (stat != NC_NOERR) {
        (void)fprintf(stderr,"line %d of %s: %s\n", line, file, nc_strerror(stat));
        fflush(stderr);
        exit(1);
    }
}

int
get_month_in_days( const int months, const bool is_leap_year ) {
  int days[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
  if( is_leap_year ) {
    days[1] = 29;
  }
  int ret_val = 0;
  for(int m = months-1; m >= 0; --m) ret_val += days[m];
  return ret_val;
}

double
get_time_in_seconds(const int year, const int month, const int day,
    const double hours, const double minutes, const double seconds) {
  int leap_years = (year-1) / 4 - (year-1) / 100 + (year-1) / 400;
  bool is_leap_year = year % 4 == 0 && ( year % 100 != 0 || year % 400 == 0 );
  int days_to_year = ( ( year-1 - leap_years ) * 365 + leap_years * 366 );
  double s = (double)days_to_year * 24.0 * 60.0 * 60.0 +
             ( ( ( (double)( get_month_in_days( month-1, is_leap_year ) + day-1 ) * 24.0 +
                           hours ) * 60.0 + minutes ) * 60.0 + seconds );
  return s;
}

int
main() {/* create parking_lot_photo_rates.nc */

    int  stat;  /* return status */
    int  ncid;  /* netCDF id */

    /* dimension ids */
    int time_dim;

    /* dimension lengths */
    size_t time_len = NC_UNLIMITED;

    /* variable ids */
    int time_id;
    int O3_1_id;
    int O3_2_id;
    int O2_1_id;

    /* rank (number of dimensions) for each variable */
#   define RANK_time 1
#   define RANK_O3_1 1
#   define RANK_O3_2 1
#   define RANK_O2_1 1

    /* variable shapes */
    int time_dims[RANK_time];
    int O3_1_dims[RANK_O3_1];
    int O3_2_dims[RANK_O3_2];
    int O2_1_dims[RANK_O2_1];

    /* enter define mode */
    stat = nc_create("parking_lot_photo_rates.nc", NC_CLOBBER, &ncid);
    check_err(stat,__LINE__,__FILE__);

    /* define dimensions */
    stat = nc_def_dim(ncid, "time", time_len, &time_dim);
    check_err(stat,__LINE__,__FILE__);

    /* define variables */

    time_dims[0] = time_dim;
    stat = nc_def_var(ncid, "time", NC_DOUBLE, RANK_time, time_dims, &time_id);
    check_err(stat,__LINE__,__FILE__);

    O3_1_dims[0] = time_dim;
    stat = nc_def_var(ncid, "O3_1", NC_DOUBLE, RANK_O3_1, O3_1_dims, &O3_1_id);
    check_err(stat,__LINE__,__FILE__);

    O3_2_dims[0] = time_dim;
    stat = nc_def_var(ncid, "O3_2", NC_DOUBLE, RANK_O3_2, O3_2_dims, &O3_2_id);
    check_err(stat,__LINE__,__FILE__);

    O2_1_dims[0] = time_dim;
    stat = nc_def_var(ncid, "O2_1", NC_DOUBLE, RANK_O2_1, O2_1_dims, &O2_1_id);
    check_err(stat,__LINE__,__FILE__);

    /* assign per-variable attributes */

    {
    stat = nc_put_att_text(ncid, time_id, "units", 5, "hours");
    check_err(stat,__LINE__,__FILE__);
    }

    {
    stat = nc_put_att_text(ncid, O3_1_id, "units", 3, "s-1");
    check_err(stat,__LINE__,__FILE__);
    }

    {
    stat = nc_put_att_text(ncid, O3_2_id, "units", 3, "s-1");
    check_err(stat,__LINE__,__FILE__);
    }

    {
    stat = nc_put_att_text(ncid, O2_1_id, "units", 3, "s-1");
    check_err(stat,__LINE__,__FILE__);
    }


    /* leave define mode */
    stat = nc_enddef (ncid);
    check_err(stat,__LINE__,__FILE__);

    /* assign variable data */
    double ref_time = get_time_in_seconds( 1, 1, 1, 0.0, 0.0, 0.0 );

    /* the start date is set for 6/11 because 2020 is a leap year
     * and 2005 is not */
    double data_set_start_time = get_time_in_seconds( 2005, 1, 1, 0.0-8.0, 0.0, 0.0 ) - ref_time;
    double sim_time_start = get_time_in_seconds( 2005, 6, 11, 13.0-8.0,  0.0, 0.0 ) - ref_time;
    double sim_time_stop  = get_time_in_seconds( 2005, 6, 11, 15.0-8.0, 30.0, 0.0 ) - ref_time;
    data_set_start_time /= 3600.0;
    sim_time_start /= 3600.0;
    sim_time_stop /= 3600.0;
    double O3_1 = 1.0e-4;
    double O3_2 = 2.0e-4;
    double O2_1 = 3.0e-4;
    double timea[1];
    double O3_1a[1];
    double O3_2a[1];
    double O2_1a[1];
    size_t start[1] = {0};
    size_t count[1] = {1};
    for(int i_hour = 0; i_hour <= 365 * 24; ++i_hour) {
      timea[0] = data_set_start_time + i_hour;
      if( timea[0] >= sim_time_start - 1.0e-10 && timea[0] <= sim_time_stop + 1.0e-10 ) {
        O3_1a[0] = O3_1;
        O3_2a[0] = O3_2;
        O2_1a[0] = O2_1;
        O3_1 += 1.0e-5;
        O3_2 += 2.0e-5;
        O2_1 += 3.0e-5;
      } else {
        O3_1a[0] = i_hour;
        O3_2a[0] = 0.0;
        O2_1a[0] = 0.0;
      }
      stat = nc_put_vara_double(ncid, time_id, start, count, timea );
      check_err(stat,__LINE__,__FILE__);
      stat = nc_put_vara_double(ncid, O3_1_id, start, count, O3_1a );
      check_err(stat,__LINE__,__FILE__);
      stat = nc_put_vara_double(ncid, O3_2_id, start, count, O3_2a );
      check_err(stat,__LINE__,__FILE__);
      stat = nc_put_vara_double(ncid, O2_1_id, start, count, O2_1a );
      check_err(stat,__LINE__,__FILE__);
      start[0] += 1;
    }

    stat = nc_close(ncid);
    check_err(stat,__LINE__,__FILE__);
    return 0;
}
