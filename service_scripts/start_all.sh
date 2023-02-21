# check if running as root
if [ "$(id -u)" != "0" ]; then
    echo -e "\033[31m This script must be run as root \033[0m" 1>&2
    exit 1
fi
# ask if we want to install the dependencies too (for the first time)
echo -e "\033[32m Do you want to install the dependencies too? (y/n) \033[0m"
read -r answer
if [ "$answer" = "y" ]; then
    cd ..
    # install dependencies
    echo -e "\033[32m installing dependencies \033[0m"
    echo -e "\033[32m   |_ installing dnf dependencies \033[0m"
    dnf -y update > /dev/null \
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
	libpq-devel \
    && dnf clean all > /dev/null
    dnf -y install python3-pandas > /dev/null
    echo -e "\033[32m   |_ installing pip dependencies \033[0m"
    pip3 install requests numpy scipy matplotlib ipython jupyter nose Django pillow \
                 django-crispy-forms pyvis django-cors-headers drf-yasg psycopg2-binary pika > /dev/null
    echo -e "\033[32m   |_ installing SuiteSparse \033[0m"
    curl -LO http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.1.0.tar.gz \
    && tar -zxvf SuiteSparse-5.1.0.tar.gz \
    && export CXX=/usr/bin/cc \
    && cd SuiteSparse \
    && make install INSTALL=/usr/local BLAS="-L/lib64 -lopenblas" > /dev/null \
    echo -e "\033[32m   |_ installing json-fortran \033[0m"
    curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.2.0.tar.gz \
    && tar -zxvf 8.2.0.tar.gz \
    && cd json-fortran-8.2.0 \
    && export FC=gfortran \
    && mkdir build \
    && cd build \
    && cmake -D SKIP_DOC_GEN:BOOL=TRUE .. \
    && make install > /dev/null \

    echo -e "\033[32m   |_ copying music box \033[0m"
    # TODO COPY . /music-box/
    
    echo -e "\033[32m   |_ copy mechanism \033[0m"
    cp /music-box/etc/change_mechanism.sh /
    mkdir /build \
    && cp -r /music-box/examples /build/examples
    cd /music-box/libs/micm-preprocessor; \
    npm install
    echo -e "\033[32m   |_ installing modified CVODE \033[0m"
    tar -zxvf /music-box/libs/camp/cvode-3.4-alpha.tar.gz \
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
    echo -e "\033[32m   |_ installing camp \033[0m"
    mkdir camp_build \
    && cd camp_build \
    && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
    && cmake -D CMAKE_BUILD_TYPE=release \
             -D CMAKE_C_FLAGS_DEBUG="-pg" \
             -D CMAKE_Fortran_FLAGS_DEBUG="-pg" \
             -D CMAKE_MODULE_LINKER_FLAGS="-pg" \
             -D ENABLE_GSL:BOOL=TRUE \
             /music-box/libs/camp \
    && make
    TAG_ID=false
    if [ "$TAG_ID" = "false" ] ; then \
      echo "No mechanism specified" ; else \
      echo "Grabbing mechanism $TAG_ID" \
      && cd /music-box/libs/micm-preprocessor \
      && nohup bash -c "node combined.js &" && sleep 4 \
      && mkdir /data \
      && cd /music-box/libs/micm-collection \
      && if [ "$TAG_ID" = "chapman" ] ; then \
           python3 preprocess_tag.py -c configured_tags/$TAG_ID/config.json -p localhost:3000 \
        && python3 stage_tag.py -source_dir_kinetics configured_tags/$TAG_ID/output -target_dir_data /data \
        ; else \
           echo "Only Chapman chemistry is currently available for MusicBox-MICM" \
        && exit 1 \
        ; fi \
      ; fi
    echo -e "\033[32m   |_ building music box \033[0m"
    cd /build \
      && export JSON_FORTRAN_HOME="/usr/local/jsonfortran-gnu-8.2.0" \
      && cmake -D CAMP_INCLUDE_DIR="/camp_build/include" \
               -D CAMP_LIB="/camp_build/lib/libcamp.a" \
               /music-box \
      && make
    pip3 install django-extensions Werkzeug pyOpenSSL > /dev/null
fi
# start rabbit mq
echo -e "\033[32m starting rabbitmq \033[0m"
# run 'sudo systemctl start rabbitmq-server' and don't show output
sudo systemctl start rabbitmq-server > /dev/null

# Prepare the music-box-interactive web server
echo -e "\033[32m preparing music-box-interactive web server \033[0m"
mv music-box/libs/music-box-interactive .
MUSIC_BOX_BUILD_DIR=/build
python3 libs/interactive/manage.py makemigrations > /dev/null
python3 libs/interactive/manage.py migrate
sh start_servers.sh &
echo -e "\033[32m Done! everything should be running in background \033[0m"