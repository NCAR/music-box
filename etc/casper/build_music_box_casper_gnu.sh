# Downloads and build MusicBox and its dependencies on CASPER using GNU compilers
#
# The MUSIC_BOX_HOME environment variable must be set to the directory to build Music
# in prior to calling this script.


module purge
module load gnu/10.1.0
module load openblas/0.3.9
module load ncarenv/1.3
module load netcdf/4.7.4
module load ncarcompilers/0.5.0
module load cmake/3.18.2
module load gsl/2.6

if [[ -z "${MUSIC_BOX_HOME}" ]]; then
  echo "You must set the MUSIC_BOX_HOME environment variable to the directory where MusicBox should be built."
  return
fi

if [[ ! -d "${MUSIC_BOX_HOME}" ]]; then
  echo "MUSIC_BOX_HOME must point to an existing directory"
  return
fi

echo "Building MusicBox"

# get source code
cd ${MUSIC_BOX_HOME}
curl -LO http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.1.0.tar.gz
curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.2.1.tar.gz
git clone --recurse-submodules https://github.com/NCAR/music-box.git

# extract
cd ${MUSIC_BOX_HOME}
cp music-box/libs/camp/cvode-3.4-alpha.tar.gz .
tar -zxf SuiteSparse-5.1.0.tar.gz
tar -zxf 8.2.1.tar.gz
tar -zxf cvode-3.4-alpha.tar.gz

INSTALL_ROOT=$MUSIC_BOX_HOME/install
mkdir -p $INSTALL_ROOT

# Suite Sparse
SUITE_SPARSE_ROOT=$MUSIC_BOX_HOME/SuiteSparse
export SUITE_SPARSE_HOME=$INSTALL_ROOT/suitesparse-gnu-5.1.0
mkdir -p $SUITE_SPARSE_HOME
cd $SUITE_SPARSE_ROOT
sed -i 's/\-openmp/\-qopenmp/' SuiteSparse_config/SuiteSparse_config.mk
make install INSTALL=$SUITE_SPARSE_HOME BLAS="-lopenblas" LAPACK="-lopenblas"

# json-fortran
JSON_FORTRAN_ROOT=$MUSIC_BOX_HOME/json-fortran-8.2.1
export JSON_FORTRAN_HOME=$INSTALL_ROOT/jsonfortran-gnu-8.2.1
cd $JSON_FORTRAN_ROOT
mkdir -p build
cd build
cmake -D SKIP_DOC_GEN:BOOL=TRUE -D CMAKE_INSTALL_PREFIX=$INSTALL_ROOT ..
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
cmake -D CMAKE_BUILD_TYPE=release \
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
mkdir -p build
cd build
cmake -D CMAKE_C_COMPILER=gcc \
      -D CMAKE_Fortran_COMPILER=gfortran \
      -D CMAKE_BUILD_TYPE=release \
      -D CMAKE_C_FLAGS="-std=c99 ${NCAR_LIBS_GSL}" \
      -D ENABLE_JSON=ON \
      -D ENABLE_SUNDIALS=ON \
      -D ENABLE_GSL=ON \
      -D SUITE_SPARSE_AMD_LIB=$SUITE_SPARSE_HOME/lib/libamd.so \
      -D SUITE_SPARSE_BTF_LIB=$SUITE_SPARSE_HOME/lib/libbtf.so \
      -D SUITE_SPARSE_COLAMD_LIB=$SUITE_SPARSE_HOME/lib/libcolamd.so \
      -D SUITE_SPARSE_CONFIG_LIB=$SUITE_SPARSE_HOME/lib/libsuitesparseconfig.so \
      -D SUITE_SPARSE_KLU_LIB=$SUITE_SPARSE_HOME/lib/libklu.so \
      -D SUITE_SPARSE_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
      -D NETCDF_INCLUDE_DIR=$NCAR_INC_NETCDF \
      -D NETCDF_C_LIB=$NCAR_LDFLAGS_NETCDF/libnetcdf.so \
      -D NETCDF_FORTRAN_LIB=$NCAR_LDFLAGS_NETCDF/libnetcdff.so \
      -D GSL_CBLAS_LIB=$NCAR_LDFLAGS_GSL/libgslcblas.so \
      -D GSL_INCLUDE_DIR=$NCAR_INC_GSL \
      -D GSL_LIB=$NCAR_LDFLAGS_GSL/libgsl.so \
      ..
make

# MusicBox
MUSIC_BOX_ROOT=$MUSIC_BOX_HOME/music-box
cd $MUSIC_BOX_ROOT
mkdir -p build
cd build
cmake -D CMAKE_C_COMPILER=gcc \
      -D CMAKE_Fortran_COMPILER=gfortran \
      -D CMAKE_BUILD_TYPE=release \
      -D CMAKE_C_FLAGS="-std=c99 ${NCAR_LIBS_GSL}" \
      -D SUITE_SPARSE_AMD_LIB=$SUITE_SPARSE_HOME/lib/libamd.so \
      -D SUITE_SPARSE_BTF_LIB=$SUITE_SPARSE_HOME/lib/libbtf.so \
      -D SUITE_SPARSE_COLAMD_LIB=$SUITE_SPARSE_HOME/lib/libcolamd.so \
      -D SUITE_SPARSE_CONFIG_LIB=$SUITE_SPARSE_HOME/lib/libsuitesparseconfig.so \
      -D SUITE_SPARSE_KLU_LIB=$SUITE_SPARSE_HOME/lib/libklu.so \
      -D SUITE_SPARSE_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
      -D NETCDF_INCLUDE_DIR=$NCAR_INC_NETCDF \
      -D NETCDF_C_LIB=$NCAR_LDFLAGS_NETCDF/libnetcdf.so \
      -D NETCDF_FORTRAN_LIB=$NCAR_LDFLAGS_NETCDF/libnetcdff.so \
      -D GSL_CBLAS_LIB=$NCAR_LDFLAGS_GSL/libgslcblas.so \
      -D GSL_INCLUDE_DIR=$NCAR_INC_GSL \
      -D GSL_LIB=$NCAR_LDFLAGS_GSL/libgsl.so \
      -D CAMP_LIB=$CAMP_HOME/libcamp.a \
      -D CAMP_INCLUDE_DIR=$CAMP_HOME \
      ..
make

