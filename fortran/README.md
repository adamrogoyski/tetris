# Fortran Tetris

I, too, was surprised that there are SDL2 bindings for Fortran.

Requires https://github.com/interkosmos/fortran-sdl2.git.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install gfortan git
$ make
```

To build with Docker, from the top-level directory:

```
$ docker build -f fortran/Dockerfile -t adamrogoyski/tetris-fortran .

# Copy the dynamically-linked binary out of the image.
$ docker cp $(docker create --name temp_container_tetris_fortran adamrogoyski/tetris-fortran:latest):/usr/src/tetris/tetris . && docker rm temp_container_tetris_fortran

# Install the SDL2 dependencies
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0

$ ./tetris
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-fortran ./tetris
```

