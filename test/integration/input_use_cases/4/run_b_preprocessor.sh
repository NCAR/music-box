#!/bin/bash

# exit on error
set -e
# turn on command echoing
set -v
# make sure that the current directory is the once where this script is
cd ${0%/*}

exec_str="../../../../music_box --preprocess-only config_b.json"
exec_str2="./run_preprocessed_data.sh"

if ! $exec_str; then
  echo FAIL
  exit 1
else
  if ! $exec_str2; then
    echo FAIL
    exit 1
  else
    echo PASS
    exit 0
  fi
fi
