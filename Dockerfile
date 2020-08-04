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
        python3 \
        texlive-scheme-basic \
        'tex(type1cm.sty)' \
        'tex(type1ec.sty)' \
        dvipng \
        git \
        nodejs \
        ncview \
    && dnf clean all

# copy the MusicBox code
COPY . /music-box/

# python modules needed in scripts
RUN pip3 install requests numpy scipy matplotlib ipython jupyter pandas nose Django pillow django-crispy-forms

# nodejs modules needed Mechanism-To-Code
RUN cd /music-box/libs/MechanismToCode; \
    npm install

# install json-fortran
RUN curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.1.0.tar.gz \
    && tar -zxvf 8.1.0.tar.gz \
    && cd json-fortran-8.1.0 \
    && export FC=gfortran \
    && mkdir build \
    && cd build \
    && cmake -D SKIP_DOC_GEN:BOOL=TRUE .. \
    && make install

# command line arguments
ARG TAG_ID=false

# get a tag and build the model
RUN if [ "$TAG_ID" = "false" ] ; then \
      echo "No mechanism specified" ; else \
      echo "Grabbing mechanism $TAG_ID" \
      && cd /music-box/libs/MechanismToCode \
      && nohup bash -c "node combined.js &" && sleep 4 \
      && mkdir /data \
      && cd /music-box/libs/Mechanism_Collection \
      && python3 get_tag.py -tag_id $TAG_ID \
      && python3 preprocess_tag.py -mechanism_source_path configured_tags/$TAG_ID -preprocessor localhost:3000 \
      && python3 stage_tag.py -source_dir_kinetics configured_tags/$TAG_ID -target_dir_data /data \
      && mkdir /build \
      && cd /build \
      && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.1.0" \
      && cmake ../music-box \
      && make \
      ; fi

# Prepare the music-box-interactive web server
RUN mv music-box/libs/music-box-interactive .
ENV MUSIC_BOX_BUILD_DIR=/build

EXPOSE 8000

CMD ["python3", "music-box-interactive/interactive/manage.py", "runserver", "0.0.0.0:8000" ]
