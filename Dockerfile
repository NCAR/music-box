FROM fedora:35

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

RUN pip3 install requests numpy scipy matplotlib ipython jupyter nose Django pillow \
                 django-crispy-forms pyvis django-cors-headers drf-yasg

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

# Install a modified version of CVODE
RUN tar -zxvf /music-box/libs/camp/cvode-3.4-alpha.tar.gz \
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

# Build CAMP
RUN mkdir camp_build \
    && cd camp_build \
    && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
    && cmake -D CMAKE_BUILD_TYPE=release \
             -D CMAKE_C_FLAGS_DEBUG="-pg" \
             -D CMAKE_Fortran_FLAGS_DEBUG="-pg" \
             -D CMAKE_MODULE_LINKER_FLAGS="-pg" \
             -D ENABLE_GSL:BOOL=TRUE \
             /music-box/libs/camp \
    && make

# build the model
RUN cd /build \
      && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
      && cmake -D CAMP_INCLUDE_DIR="/camp_build/include" \
               -D CAMP_LIB="/camp_build/lib/libcamp.a" \
               /music-box \
      && make

# Prepare the music-box-interactive web server
RUN mv music-box/libs/music-box-interactive .
ENV MUSIC_BOX_BUILD_DIR=/build

EXPOSE 8000

CMD ["python3", "music-box-interactive/interactive/manage.py", "runserver", "0.0.0.0:8000" ]
