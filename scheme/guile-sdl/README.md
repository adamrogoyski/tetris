# Scheme Guile SDL Tetris

Uses [GNU Guile](https://www.gnu.org/software/guile/) interpreter and
[guile-sdl2](https://dthompson.us/projects/guile-sdl2.html).

Run with:

```
$ guile -s tetris.scm
```

You may need to set the path to the SDL libraries when running:

```
$ env GUILE_LOAD_COMPILED_PATH=/usr/local/lib/guile/3.0/site-ccache:/usr/local/lib/guile/3.0/ccache guile -s tetris.scm
```

To run on Debian (bookworm), in the current directory:

```
$ apt -y install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev git ca-certificates guile-3.0 guile-3.0-dev autoconf automake texinfo

# Install the SDL bindings.
$ git clone https://git.dthompson.us/guile-sdl2.git
$ cd guile-sdl2
$ autoreconf --install
$ ./configure
$ make
$ make install
$ cd ..

$ env GUILE_LOAD_COMPILED_PATH=/usr/local/lib/guile/3.0/site-ccache:/usr/local/lib/guile/3.0/ccache guile -s tetris.scm
```

To build with Docker, from the top-level directory:

```
$ docker build -f scheme/guile-sdl/Dockerfile -t adamrogoyski/tetris-guile .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-guile env GUILE_LOAD_COMPILED_PATH=/usr/local/lib/guile/3.0/site-ccache:/usr/local/lib/guile/3.0/ccache guile -s tetris.scm
```



