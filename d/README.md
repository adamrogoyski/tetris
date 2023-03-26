# D Tetris

The SDL2 library is used.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install dub gdc libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev

$ dub build
```

To build with Docker, from the top-level directory:

```
$ docker build -f d/Dockerfile -t adamrogoyski/tetris-d .

# Copy the dynamically-linked binary out of the image.
$ docker cp $(docker create --name temp_container_tetris_d adamrogoyski/tetris-d:latest):/usr/src/tetris/tetris . && docker rm temp_container_tetris_d

# Install the SDL2 dependencies
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0

$ ./tetris
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-d ./tetris
```

