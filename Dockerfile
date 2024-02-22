FROM fedora:37

RUN dnf -y update \
    && dnf -y install \
        gcc-c++ \
        gcc \
        cmake \
        make \
        wget \
        git \
    && dnf clean all

COPY . /music-box

# build music-box
RUN cd music-box \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -j

WORKDIR /music-box/build