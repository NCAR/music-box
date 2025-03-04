#!/bin/bash

# exit on error
set -e
# turn on command echoing
set -v
# make sure that the current directory is the once where this script is
cd ${0%/*}

exec_str="../../../../music_box config_camp.json"
comp_str="../../../../compare_results output.csv expected_output_camp.csv 1.0e-3 1.0e-12"

if ! $exec_str; then
  echo FAIL
  exit 1
else
  if $comp_str; then
    echo PASS
    exit 0
  else
    echo unexpected results
    echo FAIL
    exit 1
  fi
fi
