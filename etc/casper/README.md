# Building MusicBox on CASPER

## Get the source code

- Copy one of the build scripts in this folder to GLADE, depending on what compilers you would like to use.

- Log in to CASPER and start an interactive session (BASH shell)

- Create a directory to build MusicBox in:

```
mkdir my-music-box-build
```

- Create an environment variable named `MUSIC_BOX_HOME` pointing to the absolute path of your build directory:

```
export MUSIC_BOX_HOME=/path/to/my-music-box-build
```

## Build MusicBox

Choose one of the following options, replacing `/path/to/` with the path to the directory you copied the build script to.

### Option 1: Build with Intel compilers
With the Intel compilers, you have the option of generating a set of module files during the build that can be used with the LMOD environment module system on CHEYENNE and CASPER. To generate the module files, create an environment variable named `MUSIC_BOX_MODULE_ROOT` pointing to the absolute path of your `modulefiles/` folder:

```
export MUSIC_BOX_MODULE_ROOT=/path/to/my/modulefiles
```

To build MusicBox, run:

```
cd $MUSIC_BOX_HOME
. /path/to/build_music_box_casper_intel.sh
```

### Option 2: Build with GNU compilers
```
cd $MUSIC_BOX_HOME
. /path/to/build_music_box_casper_gnu.sh
```

## Run MusicBox

- Run the tests

```
cd $MUSIC_BOX_HOME/music-box/build
make test
```

- The executable will be here: `$MUSIC_BOX_HOME/music-box/build/music-box`