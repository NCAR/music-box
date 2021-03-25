# Building MusicBox on modeling2

## Get the source code

- Copy the build script in this folder to modeling2

- Log in to modeling2 (BASH shell)

- Create a directory to build MusicBox in:

```
mkdir my-music-box-build
```

- Create an environment variable named `MUSIC_BOX_HOME` pointing to the absolute path of your build directory:

```
export MUSIC_BOX_HOME=/path/to/my-music-box-build
```

## Build MusicBox

Replace `/path/to/` with the path to the directory you copied the build script to, in the following:

```
cd $MUSIC_BOX_HOME
. /path/to/build_music_box_modeling2_gnu.sh
```

## Run MusicBox

- Run the tests

```
cd $MUSIC_BOX_HOME/music-box/build
make test
```

- The executable will be here: `$MUSIC_BOX_HOME/music-box/build/music-box`