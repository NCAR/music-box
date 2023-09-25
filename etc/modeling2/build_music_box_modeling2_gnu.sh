# Downloads and build MusicBox and its dependencies on modeling2 using GNU compilers
#
# The MUSIC_BOX_HOME environment variable must be set to the directory to build Music
# in prior to calling this script.

if [[ -z "${MUSIC_BOX_HOME}" ]]; then
  echo "You must set the MUSIC_BOX_HOME environment variable to the directory where MusicBox should be built."
  return
fi

if [[ ! -d "${MUSIC_BOX_HOME}" ]]; then
  echo "MUSIC_BOX_HOME must point to an existing directory"
  return
fi

echo "Building MusicBox"

export PATH="/opt/local/bin:${PATH}"
export LD_LIBRARY_PATH="/opt/local/lib64:/opt/local/lib:/usr/bin:/usr/lib:usr/lib64:usr/local/bin:usr/local/lib:usr/local/lib64"

# get source code
# HDF5 is not available using curl
# There is a copy at /home/mattdawson/CMake-hdf5-1.12.0.tar.gz
cd ${MUSIC_BOX_HOME}
curl -LO http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.1.0.tar.gz
curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.2.1.tar.gz
curl -LO https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.4.tar.gz
curl -LO https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.5.3.tar.gz
curl -LO https://mirrors.kernel.org/gnu/gsl/gsl-2.6.tar.gz
git clone --recurse-submodules https://github.com/NCAR/music-box.git

# extract
cd ${MUSIC_BOX_HOME}
cp music-box/libs/camp/cvode-3.4-alpha.tar.gz .
tar -zxf SuiteSparse-5.1.0.tar.gz
tar -zxf 8.2.1.tar.gz
tar -zxf cvode-3.4-alpha.tar.gz
tar -zxf v4.7.4.tar.gz
tar -zxf v4.5.3.tar.gz
tar -zxf gsl-2.6.tar.gz
tar -zxf CMake-hdf5-1.12.0.tar.gz

INSTALL_ROOT=$MUSIC_BOX_HOME/install
mkdir -p $INSTALL_ROOT

# HDF5
HDF5_ROOT=$MUSIC_BOX_HOME/CMake-hdf5-1.12.0
export HDF5_HOME=$INSTALL_ROOT/hdf5-gnu-1.12.0
mkdir -p $HDF5_HOME
cd $HDF5_ROOT
sed -i 's/^ctest/ctest3/' build-unix.sh
. build-unix.sh
tar -zxf HDF5-1.12.0-Linux.tar.gz
mv HDF5-1.12.0-Linux/HDF_Group/HDF5/1.12.0/* $HDF5_HOME

# NetCDF
NETCDF_ROOT=$MUSIC_BOX_HOME/netcdf-c-4.7.4
export NETCDF_HOME=$INSTALL_ROOT/netcdf-gnu-4.7.4
mkdir -p $NETCDF_HOME
cd $NETCDF_ROOT
mkdir -p build
cd build
cmake3 -D CMAKE_C_COMPILER=/opt/local/bin/gcc \
       -D CMAKE_BUILD_TYPE=release \
       -D CMAKE_INSTALL_PREFIX=$NETCDF_HOME \
       -D ENABLE_REMOTE_FORTRAN_BOOTSTRAP:BOOL=TRUE \
       -D HDF5_INCLUDE_DIR=$HDF5_HOME/include \
       -D HDF5_C_LIBRARY=$HDF5_HOME/lib/libhdf5.so \
       -D HDF5_HL_LIBRARY=$HDF5_HOME/lib/libhdf5_hl.so \
       ..
make install
export NCDIR=$NETCDF_HOME

# NetCDF-Fortran
NETCDFF_ROOT=$MUSIC_BOX_HOME/netcdf-fortran-4.5.3
cd $NETCDFF_ROOT
mkdir -p temp_lib
mkdir -p temp_include
mkdir -p build
cd build
cmake3 -D CMAKE_C_COMPILER=/opt/local/bin/gcc \
       -D CMAKE_Fortran_COMPILER=/opt/local/bin/gfortran \
       -D CMAKE_BUILD_TYPE=release \
       -D CMAKE_INSTALL_PREFIX=$NETCDF_HOME \
       -D CMAKE_INSTALL_LIBDIR=$NETCDFF_ROOT/temp_lib \
       -D CMAKE_INSTALL_INCLUDEDIR=$NETCDFF_ROOT/temp_include \
       -D netCDF_DIR=$NETCDF_HOME \
       -D NETCDF_C_LIBRARY=$NETCDF_HOME/lib/libnetcdf.so \
       -D NETCDF_INCLUDE_DIR=$NETCDF_HOME/include \
       ..
make install
cp -r $NETCDFF_ROOT/temp_lib/* $NETCDF_HOME/lib64/
cp -r $NETCDFF_ROOT/temp_include/* $NETCDF_HOME/include/

# GSL
GSL_ROOT=$MUSIC_BOX_HOME/gsl-2.6
export GSL_HOME=$INSTALL_ROOT/gsl-gnu-2.6
mkdir -p $GSL_HOME
cd $GSL_ROOT
./configure --prefix=$GSL_HOME \
            CC="/opt/local/bin/gcc" \
            CXX="/opt/local/bin/gcc" \
            CPP="/opt/local/bin/cpp"
make
make install

# Suite Sparse
SUITE_SPARSE_ROOT=$MUSIC_BOX_HOME/SuiteSparse
export SUITE_SPARSE_HOME=$INSTALL_ROOT/suitesparse-gnu-5.1.0
mkdir -p $SUITE_SPARSE_HOME
cd $SUITE_SPARSE_ROOT
sed -i 's/\-openmp/\-qopenmp/' SuiteSparse_config/SuiteSparse_config.mk
make install INSTALL=$SUITE_SPARSE_HOME BLAS="-lblas" LAPACK="-llapack"

# json-fortran
JSON_FORTRAN_ROOT=$MUSIC_BOX_HOME/json-fortran-8.2.1
export JSON_FORTRAN_HOME=$INSTALL_ROOT/jsonfortran-gnu-8.2.1
cd $JSON_FORTRAN_ROOT
sed -i 's/\-C $<CONFIG>//' CMakeLists.txt
mkdir -p build
cd build
cmake3 -D CMAKE_Fortran_COMPILER=/opt/local/bin/gfortran \
       -D SKIP_DOC_GEN:BOOL=TRUE \
       -D CMAKE_INSTALL_PREFIX=$INSTALL_ROOT \
       ..
make install
mkdir -p $JSON_FORTRAN_HOME/lib/shared
mv $JSON_FORTRAN_HOME/lib/*.so* $JSON_FORTRAN_HOME/lib/shared

# CVODE
SUNDIALS_ROOT=$MUSIC_BOX_HOME/cvode-3.4-alpha
export SUNDIALS_HOME=$INSTALL_ROOT/cvode-gnu-3.4-alpha
mkdir -p $SUNDIALS_HOME
cd $SUNDIALS_ROOT
mkdir -p build
cd build
cmake3 -D CMAKE_C_COMPILER=/opt/local/bin/gcc \
       -D CMAKE_BUILD_TYPE=release \
       -D BUILD_SHARED_LIBS:BOOL=FALSE \
       -D MPI_ENABLE:BOOL=TRUE \
       -D KLU_ENABLE:BOOL=TRUE \
       -D KLU_LIBRARY_DIR=$SUITE_SPARSE_HOME/lib \
       -D KLU_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
       -D CMAKE_INSTALL_PREFIX=$SUNDIALS_HOME \
       ..
make install

# CAMP
CAMP_ROOT=$MUSIC_BOX_HOME/music-box/libs/camp
export CAMP_HOME=$CAMP_ROOT/build
mkdir -p $CAMP_HOME
cd $CAMP_ROOT
sed -i '/^add_executable(unit_test_rxn_arrhenius/d' CMakeLists.txt
sed -i '/^target_link_libraries(unit_test_rxn_arrhenius/d' CMakeLists.txt
sed -i '/add_test(test_rxn_arrhenius_mech/d' CMakeLists.txt
mkdir -p build
cd build
cmake3 -D CMAKE_C_COMPILER=gcc \
       -D CMAKE_Fortran_COMPILER=gfortran \
       -D CMAKE_BUILD_TYPE=release \
       -D CMAKE_C_FLAGS="-std=c99" \
       -D ENABLE_JSON=ON \
       -D ENABLE_SUNDIALS=ON \
       -D ENABLE_GSL=ON \
       -D GSL_CBLAS_LIB=$GSL_HOME/lib/libgslcblas.so \
       -D GSL_INCLUDE_DIR=$GSL_HOME/include/gsl \
       -D GSL_LIB=$GSL_HOME/lib/libgsl.so \
       -D SUITE_SPARSE_AMD_LIB=$SUITE_SPARSE_HOME/lib/libamd.so \
       -D SUITE_SPARSE_BTF_LIB=$SUITE_SPARSE_HOME/lib/libbtf.so \
       -D SUITE_SPARSE_COLAMD_LIB=$SUITE_SPARSE_HOME/lib/libcolamd.so \
       -D SUITE_SPARSE_CONFIG_LIB=$SUITE_SPARSE_HOME/lib/libsuitesparseconfig.so \
       -D SUITE_SPARSE_KLU_LIB=$SUITE_SPARSE_HOME/lib/libklu.so \
       -D SUITE_SPARSE_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
       -D NETCDF_INCLUDE_DIR=$NETCDF_HOME/include \
       -D NETCDF_C_LIB=$NETCDF_HOME/lib64/libnetcdf.so \
       -D NETCDF_FORTRAN_LIB=$NETCDF_HOME/lib64/libnetcdff.so \
       ..
make

# MusicBox
MUSIC_BOX_ROOT=$MUSIC_BOX_HOME/music-box
cd $MUSIC_BOX_ROOT
mkdir -p build
cd build
cmake3 -D CMAKE_C_COMPILER=gcc \
       -D CMAKE_Fortran_COMPILER=gfortran \
       -D CMAKE_BUILD_TYPE=release \
       -D CMAKE_C_FLAGS="-std=c99" \
       -D GSL_CBLAS_LIB=$GSL_HOME/lib/libgslcblas.so \
       -D GSL_INCLUDE_DIR=$GSL_HOME/include/gsl \
       -D GSL_LIB=$GSL_HOME/lib/libgsl.so \
       -D SUITE_SPARSE_AMD_LIB=$SUITE_SPARSE_HOME/lib/libamd.so \
       -D SUITE_SPARSE_BTF_LIB=$SUITE_SPARSE_HOME/lib/libbtf.so \
       -D SUITE_SPARSE_COLAMD_LIB=$SUITE_SPARSE_HOME/lib/libcolamd.so \
       -D SUITE_SPARSE_CONFIG_LIB=$SUITE_SPARSE_HOME/lib/libsuitesparseconfig.so \
       -D SUITE_SPARSE_KLU_LIB=$SUITE_SPARSE_HOME/lib/libklu.so \
       -D SUITE_SPARSE_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
       -D NETCDF_INCLUDE_DIR=$NETCDF_HOME/include \
       -D NETCDF_C_LIB=$NETCDF_HOME/lib64/libnetcdf.so \
       -D NETCDF_FORTRAN_LIB=$NETCDF_HOME/lib64/libnetcdff.so \
       -D CAMP_LIB=$CAMP_HOME/libcamp.a \
       -D CAMP_INCLUDE_DIR=$CAMP_HOME \
       ..
make

