# Scheme Guile SDL Tetris

Uses [Racket](https://racket-lang.org/) and its native
[drawing toolkit](https://docs.racket-lang.org/draw/index.html) and
[canvas](https://docs.racket-lang.org/gui/canvas_.html).

A limitation of racket/gui is that it can play sounds, but it cannot
stop them. Thus music selection is not useful. Instead, music plays,
randomly selecting the music throughout the game. But the music will
continue playing even after the game ends until the current song
completes.

To run on Debian (bookworm), in the current directory:

```
$ apt -y install racket libgtk2.0-0

$ racket tetris.scm
```

To build with Docker, from the top-level directory:

```
$ docker build -f racken/Dockerfile -t adamrogoyski/tetris-racken .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-racket racket tetris.scm
```

