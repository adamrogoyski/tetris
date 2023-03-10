# Python3 Tetris

Uses the [pygame](https://www.pygame.org/docs/) library.

To run on Debian (bookworm), in the current directory:

```
$ apt -y install python3 python3-pygame python3-pygame-sdl2

$ ./tetris.py
```

To build with Docker, from the top-level directory:

```
$ docker build -f python/Dockerfile -t adamrogoyski/tetris-python .
```

To run the program from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-python ./tetris.py
```
