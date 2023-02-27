# Tcl Tetris

The TK library and canvas is used. Tested with TCL 8.6.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install tcl tcl-snack
$ make
```

To build with Docker, from the top-level directory:

```
$ docker build -f tcl/Dockerfile -t adamrogoyski/tetris-tcl .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-tcl ./tetris.tcl
```

