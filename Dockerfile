FROM fedora:33

RUN dnf -y update \
    && dnf -y install \
        gcc-gfortran \
        gcc-c++ \
        gcc \
        netcdf-fortran-devel \
        gsl-devel \
        metis-devel \
        lapack-devel \
        openblas-devel \
        cmake \
        make \
        wget \
        python \
        python3 \
        python3-pip \
        texlive-scheme-basic \
        'tex(type1cm.sty)' \
        'tex(type1ec.sty)' \
        dvipng \
        git \
        nodejs \
        ncview \
    && dnf clean all

# python modules needed in scripts
RUN dnf -y install python3-pandas

RUN pip3 install requests numpy scipy matplotlib ipython jupyter nose Django pillow django-crispy-forms

# Build the SuiteSparse libraries for sparse matrix support
RUN curl -LO http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.1.0.tar.gz \
    && tar -zxvf SuiteSparse-5.1.0.tar.gz \
    && export CXX=/usr/bin/cc \
    && cd SuiteSparse \
    && make install INSTALL=/usr/local BLAS="-L/lib64 -lopenblas"

# install json-fortran
RUN curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.2.0.tar.gz \
    && tar -zxvf 8.2.0.tar.gz \
    && cd json-fortran-8.2.0 \
    && export FC=gfortran \
    && mkdir build \
    && cd build \
    && cmake -D SKIP_DOC_GEN:BOOL=TRUE .. \
    && make install

# copy the MusicBox code
COPY . /music-box/

# move the change mechanism script to the root folder
RUN cp /music-box/etc/change_mechanism.sh /

# move the example configurations to the build folder
RUN mkdir /build \
    && cp -r /music-box/examples /build/examples

# nodejs modules needed Mechanism-To-Code
RUN cd /music-box/libs/micm-preprocessor; \
    npm install

# Install a modified version of CVODE
RUN tar -zxvf /music-box/libs/partmc/cvode-3.4-alpha.tar.gz \
    && cd cvode-3.4-alpha \
    && mkdir build \
    && cd build \
    && cmake -D CMAKE_BUILD_TYPE=release \
             -D CMAKE_C_FLAGS_DEBUG="-g -pg" \
             -D CMAKE_EXE_LINKER_FLAGS_DEBUG="-pg" \
             -D CMAKE_MODULE_LINKER_FLAGS_DEBUG="-pg" \
             -D CMAKE_SHARED_LINKER_FLAGS_DEBUG="-pg" \
             -D KLU_ENABLE:BOOL=TRUE \
             -D KLU_LIBRARY_DIR=/usr/local/lib \
             -D KLU_INCLUDE_DIR=/usr/local/include \
             .. \
    && make install

# Build PartMC
RUN mkdir pmc_build \
    && cd pmc_build \
    && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
    && cmake -D CMAKE_BUILD_TYPE=release \
             -D CMAKE_C_FLAGS_DEBUG="-g -pg" \
             -D CMAKE_Fortran_FLAGS_DEBUG="-g -pg" \
             -D CMAKE_MODULE_LINKER_FLAGS="-pg" \
             -D ENABLE_SUNDIALS:BOOL=TRUE \
             -D ENABLE_GSL:BOOL=TRUE \
             -D SUNDIALS_CVODE_LIB=/usr/local/lib/libsundials_cvode.so \
             -D SUNDIALS_INCLUDE_DIR=/usr/local/include \
             /music-box/libs/partmc \
    && make

# command line arguments
ARG TAG_ID=false

# get a MICM mechanism if one has been specified
RUN if [ "$TAG_ID" = "false" ] ; then \
      echo "No mechanism specified" ; else \
      echo "Grabbing mechanism $TAG_ID" \
      && cd /music-box/libs/micm-preprocessor \
      && nohup bash -c "node combined.js &" && sleep 4 \
      && mkdir /data \
      && cd /music-box/libs/micm-collection \
      && python3 get_tag.py -tag_id $TAG_ID \
      && python3 preprocess_tag.py -mechanism_source_path configured_tags/$TAG_ID -preprocessor localhost:3000 \
      && python3 stage_tag.py -source_dir_kinetics configured_tags/$TAG_ID -target_dir_data /data \
      && cp /music-box/libs/micm-collection/configured_tags/${TAG_ID}/source_mechanism.json /build \
      ; fi

# build the model
RUN cd /build \
      && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
      && cmake -D PARTMC_INCLUDE_DIR="/pmc_build" \
               -D PARTMC_LIB="/pmc_build/libpartmc.a" \
               /music-box \
      && make

# Prepare the music-box-interactive web server
RUN mv music-box/libs/music-box-interactive .
ENV MUSIC_BOX_BUILD_DIR=/build

EXPOSE 8000

CMD ["python3", "music-box-interactive/interactive/manage.py", "runserver", "0.0.0.0:8000" ]
