FROM fedora:latest

ARG MUSICA_TAG=v0.13.0

RUN dnf -y update \
    && dnf -y install \
        cmake \
        gcc-c++ \
        gcc-fortran \
        gdb \
        git \
        lapack-devel \
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

RUN cd /musica \
    && pip3 install git+https://github.com/NCAR/wrf-python@v1.4.2 \
    && pip3 install .

RUN cd /musica \
    && pip3 install --verbose .[test] pytest-mock

RUN cd /music-box \
    && pip3 install --verbose .[test] pytest-mock

WORKDIR /music-box
CMD ["pytest"]
