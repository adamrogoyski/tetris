# C++ Tetris

The SDL2 library is used.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install g++ make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
$ make
```

To run the dynamically-linked binary on Debian (bookworm), the SDL libraries are required:

```
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0
$ ./tetris
```

To build with Docker, from the top-level directory:

```
$ docker build -f cpp/Dockerfile -t adamrogoyski/tetris-cpp .

# Copy the dynamically-linked binary out of the image.
$ docker cp $(docker create --name temp_container_tetris_cpp adamrogoyski/tetris-cpp:latest):/usr/src/tetris/tetris . && docker rm temp_container_tetris_cpp
$ ./tetris
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-cpp ./tetris
```

