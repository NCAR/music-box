# Downloads and build MusicBox and its dependencies on CASPER using Intel compilers
#
# The MUSIC_BOX_HOME environment variable must be set to the directory to build Music
# in prior to calling this script.

module purge
module load ncarenv/1.3
module load intel/19.1.1
module load ncarcompilers/0.5.0
module load mkl/2020.0.1
module load netcdf/4.7.3
module load cmake/3.18.2
module load gsl/2.6

if [[ -z "${MUSIC_BOX_HOME}" ]]; then
  echo "You must set the MUSIC_BOX_HOME environment variable to the directory where MusicBox should be built."
  echo "You can optionally set the MUSIC_BOX_MODULE_ROOT environment variable to the directory where you " \\
       "would like module files to be put."
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
export SUITE_SPARSE_HOME=$INSTALL_ROOT/suitesparse-intel-5.1.0
mkdir -p $SUITE_SPARSE_HOME
cd $SUITE_SPARSE_ROOT
sed -i 's/\-openmp/\-qopenmp/' SuiteSparse_config/SuiteSparse_config.mk
make install INSTALL=$SUITE_SPARSE_HOME BLAS="-lmkl_intel_lp64 -lmkl_core -lmkl_intel_thread -lpthread -lm" LAPACK=""

# json-fortran
JSON_FORTRAN_ROOT=$MUSIC_BOX_HOME/json-fortran-8.2.1
export JSON_FORTRAN_HOME=$INSTALL_ROOT/jsonfortran-intel-8.2.1
cd $JSON_FORTRAN_ROOT
mkdir -p build
cd build
cmake -D SKIP_DOC_GEN:BOOL=TRUE -D CMAKE_INSTALL_PREFIX=$INSTALL_ROOT ..
make install
mkdir -p $JSON_FORTRAN_HOME/lib/shared
mv $JSON_FORTRAN_HOME/lib/*.so* $JSON_FORTRAN_HOME/lib/shared

# CVODE
SUNDIALS_ROOT=$MUSIC_BOX_HOME/cvode-3.4-alpha
export SUNDIALS_HOME=$INSTALL_ROOT/cvode-intel-3.4-alpha
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
sed -i "s/'unit_test_rxn_arrhenius_t()'/unit_test_rxn_arrhenius_t()/" CMakeLists.txt
mkdir -p build
cd build
cmake -D CMAKE_C_COMPILER=icc \
      -D CMAKE_Fortran_COMPILER=ifort \
      -D CMAKE_BUILD_TYPE=release \
      -D CMAKE_C_FLAGS="-std=c99 ${NCAR_LIBS_GSL}" \
      -D SUITE_SPARSE_AMD_LIB=$SUITE_SPARSE_HOME/lib/libamd.so \
      -D SUITE_SPARSE_BTF_LIB=$SUITE_SPARSE_HOME/lib/libbtf.so \
      -D SUITE_SPARSE_COLAMD_LIB=$SUITE_SPARSE_HOME/lib/libcolamd.so \
      -D SUITE_SPARSE_CONFIG_LIB=$SUITE_SPARSE_HOME/lib/libsuitesparseconfig.so \
      -D SUITE_SPARSE_KLU_LIB=$SUITE_SPARSE_HOME/lib/libklu.so \
      -D SUITE_SPARSE_INCLUDE_DIR=$SUITE_SPARSE_HOME/include \
      -D ENABLE_JSON=ON \
      -D ENABLE_SUNDIALS=ON \
      -D ENABLE_MPI=OFF \
      -D ENABLE_GSL=ON \
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
cmake -D CMAKE_C_COMPILER=icc \
      -D CMAKE_Fortran_COMPILER=ifort \
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

# Set up environment module files, if a MUSIC_BOX_MODULE_ROOT folder exists

if [[ -z "${MUSIC_BOX_MODULE_ROOT}" ]]; then
  return
fi

if [[ ! -d "${MUSIC_BOX_MODULE_ROOT}" ]]; then
  echo "MUSIC_BOX_MODULE_ROOT must point to an existing directory"
  return
fi

echo "Outputting environment module files"

# set up environment module folders
MODULE_ROOT=$MUSIC_BOX_MODULE_ROOT
mkdir -p $MODULE_ROOT

SUITE_SPARSE_MODULE=$MODULE_ROOT/suite-sparse/5.1.0
mkdir -p $SUITE_SPARSE_MODULE
cp -r $SUITE_SPARSE_HOME/include $SUITE_SPARSE_MODULE
cp -r $SUITE_SPARSE_HOME/lib $SUITE_SPARSE_MODULE
printf "help([[\n"\
"For detailed instructions, go to:\n"\
"   https://people.engr.tamu.edu/davis/suitesparse.html\n"\
"\n"\
"]])\n"\
"whatis(\"Version: 5.1.0\")\n"\
"whatis(\"URL: https://people.engr.tamu.edu/davis/suitesparse.html\")\n"\
"whatis(\"Description: A suite of sparse matrix software\")\n"\
"always_load(\"intel/19.1.1\", \"mkl/2020.0.1\")\n"\
"setenv(\"SUITESPARSE_INC\", \"${SUITE_SPARSE_MODULE}/include\")\n"\
"setenv(\"SUITESPARSE_LIB\", \"${SUITE_SPARSE_MODULE}/lib\")\n"\
"prepend_path( \"LD_LIBRARY_PATH\", \"${SUITE_SPARSE_MODULE}/lib\")\n" \
>> $MODULE_ROOT/suite-sparse/5.1.0.lua

JSON_FORTRAN_MODULE=$MODULE_ROOT/json-fortran/8.2.1
mkdir -p $JSON_FORTRAN_MODULE
mkdir -p $JSON_FORTRAN_MODULE/lib
mkdir -p $JSON_FORTRAN_MODULE/include
cp $JSON_FORTRAN_HOME/lib/lib* $JSON_FORTRAN_MODULE/lib
cp -r $JSON_FORTRAN_HOME/lib/pkgconfig $JSON_FORTRAN_MODULE/lib
cp $JSON_FORTRAN_HOME/lib/*.mod $JSON_FORTRAN_MODULE/include
printf "help([[\n"\
"For detailed instructions, go to:\n"\
"   http://jacobwilliams.github.io/json-fortran/\n"\
"\n"\
"]])\n"\
"whatis(\"Version: 8.2.1\")\n"\
"whatis(\"URL: http://jacobwilliams.github.io/json-fortran/\")\n"\
"whatis(\"Description: A Fortran 2008 JSON API\")\n"\
"always_load(\"intel/19.1.1\")n"\
"setenv(\"JSONFORTRAN_INC\", \"${JSON_FORTRAN_MODULE}/include\")\n"\
"setenv(\"JSONFORTRAN_LIB\", \"${JSON_FORTRAN_MODULE}/lib\")\n"\
"prepend_path(\"PKG_CONFIG_PATH\", \"${JSON_FORTRAN_MODULE}/lib/pkgconfig\")\n"\
"prepend_path(\"LD_LIBRARY_PATH\", \"${JSON_FORTRAN_MODULE}/lib\")\n" \
>> $MODULE_ROOT/json-fortran/8.2.1.lua

CVODE_MODULE=$MODULE_ROOT/cvode/3.4-alpha
mkdir -p $CVODE_MODULE
cp -r $SUNDIALS_HOME/include $CVODE_MODULE
cp -r $SUNDIALS_HOME/lib $CVODE_MODULE
printf "help([[\n"\
"For detailed instructions, go to:\n"\
"   https://computing.llnl.gov/projects/sundials/cvode\n"\
"\n"\
"]])\n"\
"whatis(\"Version: 3.4-alpha\")\n"\
"whatis(\"URL: https://computing.llnl.gov/projects/sundials/cvode\")\n"\
"whatis(\"Description: Solver for stiff and non-stiff ODE systems\")\n"\
"always_load(\"intel/19.1.1\", \"mkl/2020.0.1\", \"suite-sparse/5.1.0\")\n"\
"setenv(\"CVODE_INC\", \"${CVODE_MODULE}/include\")\n"\
"setenv(\"CVODE_LIB\", \"${CVODE_MODULE}/lib\")\n"\
"prepend_path(\"LD_LIBRARY_PATH\", \"${CVODE_MODULE}/lib\")\n" \
>> $MODULE_ROOT/cvode/3.4-alpha.lua

CAMP_MODULE=$MODULE_ROOT/camp/2.6.0
mkdir -p $CAMP_MODULE
mkdir -p $CAMP_MODULE/bin
mkdir -p $CAMP_MODULE/lib
mkdir -p $CAMP_MODULE/include
cp $CAMP_ROOT/build/camp $CAMP_MODULE/bin/
cp $CAMP_ROOT/build/*.mod $CAMP_MODULE/include/
cp $CAMP_ROOT/src/*.h $CAMP_MODULE/include/
printf "help([[\n"\
"For detailed instructions, go to:\n"\
"   https://github.com/compdyn/camp\n"\
"\n"\
"]])\n"\
"whatis(\"Version: 2.6.0\")\n"\
"whatis(\"URL: https://github.com/compdyn/camp\")\n"\
"whatis(\"Description: Multiphase atmospheric chemistry model\")\n"\
"always_load(\"intel/19.1.1\", \"gsl/2.6\", \"netcdf/4.7.3\", \"cvode/3.4-alpha\")\n"\
"setenv(\"CAMP_INC\", \"${CAMP_MODULE}/include\")\n"\
"setenv(\"CAMP_LIB\", \"${CAMP_MODULE}/lib\")\n"\
"prepend_path(\"PATH\", \"${CAMP_MODULE}/bin\")\n"\
"prepend_path(\"LD_LIBRARY_PATH\", \"${CAMP_MODULE}/lib\")\n" \
>> $MODULE_ROOT/camp/2.6.0.lua

MUSIC_BOX_MODULE=$MODULE_ROOT/music-box/0.0.1
mkdir -p $MUSIC_BOX_MODULE
mkdir -p $MUSIC_BOX_MODULE/bin
cp $MUSIC_BOX_ROOT/build/music_box $MUSIC_BOX_MODULE/bin/music_box
printf "help([[\n"\
"For detailed instructions, go to:\n"\
"   https://github.com/NCAR/music-box\n"\
"\n"\
"]])\n"\
"whatis(\"Version: 0.0.1\")\n"\
"whatis(\"URL: https://github.com/NCAR/music-box\")\n"\
"whatis(\"Description: A MUSICA model for boxes and columns\")\n"\
"always_load(\"intel/19.1.1\", \"netcdf/4.7.3\", \"camp/2.6.0\")\n"\
"prepend_path(\"PATH\", \"${MUSIC_BOX_MODULE}/bin\")\n" \
>> $MODULE_ROOT/music-box/0.0.1.lua
