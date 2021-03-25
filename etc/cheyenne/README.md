# Building MusicBox on CHEYENNE

## Get the source code

- Log in to CASPER (not CHEYENNE) and create a directory to build MusicBox in:

```
mkdir my-music-box-build
```

- Download the source code to your build directory:

```
cd /path/to/my-music-box-build
curl -LO http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-5.1.0.tar.gz
curl -LO https://github.com/jacobwilliams/json-fortran/archive/8.2.1.tar.gz
git clone --recurse-submodules https://github.com/NCAR/music-box.git
```

- Log out of CASPER, log in to CHEYENNE, and start an interactive session (BASH shell)

- Create an environment variable named `MUSIC_BOX_HOME` pointing to the absolute path of your build directory:

```
export MUSIC_BOX_HOME=/path/to/my-music-box-build
```

## Build MusicBox

### Option 1: Build with Intel compilers

```
cd $MUSIC_BOX_HOME
. music-box/etc/cheyenne/build_music_box_cheyenne_intel.sh
```

### Option 2: Build with GNU compilers
```
cd $MUSIC_BOX_HOME
. music-box/etc/cheyenne/build_music_box_cheyenne_gnu.sh
```

## Run MusicBox

- Run the tests

```
cd $MUSIC_BOX_HOME/music-box/build
make test
```

- The executable will be here: `$MUSIC_BOX_HOME/music-box/build/music-box`