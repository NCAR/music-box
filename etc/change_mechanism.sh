#!/bin/bash

# turn on command echoing
set -v

# get the mechanism to switch to
if [ "$#" -ne 1 ]; then
  echo change_mechanism accepts one argument: the name of the new mechanism
  exit 1
fi

cd /music-box/libs/micm-preprocessor
nohup bash -c "node combined.js &" && sleep 4
mkdir -p /data
cd /music-box/libs/micm-collection
python3 get_tag.py -tag_id $1 -tag_server cafe-devel -overwrite true
python3 preprocess_tag.py -c configured_tags/$1/config.json -p localhost:3000
python3 stage_tag.py -source_dir_kinetics configured_tags/$1/output -target_dir_data /data
pkill -n node
mkdir -p /build
cd /build
export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.1.0"
cmake /music-box
make
cp /music-box/libs/micm-collection/configured_tags/${1}/source_mechanism.json .
