FROM fedora:latest

ARG MUSIC_BOX_TAG=main
ARG MUSICA_TAG=cd811c935ea0043370439b6148ebaaf3230f4cdb

RUN dnf -y update \
    && dnf -y install \
        cmake \
        gcc-c++ \
        gcc-fortran \
        gdb \
        git \
        make \
        netcdf-fortran-devel \
        python3 \
        python3-devel \
        python3-pip \
        python3-setuptools \
    && dnf clean all

COPY . /music-box/

ENV CXX=g++
ENV CC=gcc
ENV FC=gfortran

RUN git clone https://github.com/NCAR/musica.git /musica \
    && cd /musica \
    && git checkout $MUSICA_TAG

RUN mkdir /build \
      && cd /build \
      && cmake \
        -D CMAKE_BUILD_TYPE=debug \
        -D MUSICA_ENABLE_PYTHON_LIBRARY=ON \
        /musica \
      && make install -j 8

RUN cd /build/_deps/mechanism_configuration-src \
    && python3 -m pip install --upgrade wheel setuptools pytest \
    && pip3 install --verbose .[test]

RUN cd /musica \
    && pip3 install --verbose .[test] pytest-mock

RUN cd /music-box \
    && pip3 install --verbose .[test] pytest-mock

WORKDIR /music-box
CMD ["pytest"]