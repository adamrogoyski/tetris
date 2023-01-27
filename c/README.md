# C Tetris

The SDL2 library is used. Build with "make".

To build with Docker, from the top-level directory:

```
$ docker build -f c/Dockerfile -t adamrogoyski/tetris-c .
$ docker cp $(docker create --name temp_container_tetris_c adamrogoyski/tetris-c:latest):/usr/src/tetris/tetris . && docker rm temp_container_tetris_c
```

To build on Debian (bookworm), in the current directory:

```
$ apt -y install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
$ make
```

To run the dynamically-linked binary on Debian (bookworm), the SDL libraries are required:

```
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0
$ ./tetris
```
