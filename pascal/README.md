# Pascal Tetris

Uses the [SDL2-for-Pascal](https://github.com/PascalGameDevelopment/SDL2-for-Pascal.git) library.

Written for the FPC free-pascal compiler.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install fpc gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
$ make
```

To build with Docker, from the top-level directory:

```
$ docker build -f pascal/Dockerfile -t adamrogoyski/tetris-pascal .

# Copy the dynamically-linked binary out of the image.
$ docker cp $(docker create --name temp_container_tetris_pascal adamrogoyski/tetris-pascal:latest):/usr/src/tetris/tetris . && docker rm temp_container_tetris_pascal

# Install the SDL2 dependencies
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0

$ ./tetris
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-pascal ./tetris
```

