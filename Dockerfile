FROM fedora:29

RUN dnf -y update \
    && dnf -y install \
        gcc-gfortran \
        gcc-c++ \
        netcdf-fortran-devel \
        cmake \
        make \
        wget \
        python \
        git \
        nodejs \
        ncview \
    && dnf clean all

# copy the MusicBox code
COPY . /MusicBox/

# python modules needed in scripts
RUN pip3 install requests

# nodejs modules needed Mechanism-To-Code
RUN npm install express helmet

# install json-fortran
RUN curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.1.0.tar.gz \
    && tar -zxvf 8.1.0.tar.gz \
    && cd json-fortran-8.1.0 \
    && export FC=gfortran \
    && mkdir build \
    && cd build \
    && cmake -D SKIP_DOC_GEN:BOOL=TRUE .. \
    && make install

# clone the Mechanism-To-Code tool
RUN git clone https://github.com/NCAR/MechanismToCode.git

# command line arguments
ARG TAG_ID=false

# get a tag and build the model
RUN if [ "$TAG_ID" = "false" ] ; then \
      echo "No mechanism specified" ; else \
      echo "Grabbing mechanism $TAG_ID" \
      && cd MechanismToCode \
      && nohup bash -c "node combined.js &" && sleep 4 \
#      && cd ../MusicBox/Mechanism_collection \
#      && python3 get_tag.py -tag_id $TAG_ID \
#      && python3 preprocess_tag.py -mechanism_source_path configured_tags/$TAG_ID -preprocessor localhost:3000 \
#      && python3 stage_tag.py -source_dir_kinetics configured_tags/$TAG_ID \
      && cd .. \
      && mkdir build \
      && cd build \
      && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.1.0" \
      && cmake ../MusicBox \
      && make \
      ; fi
