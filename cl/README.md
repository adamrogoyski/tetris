# Common Lisp Tetris

Uses [Steel Bank Common Lisp](https://www.sbcl.org/) with SDL.

Run with:

```
$ ./tetris.lisp

$ sbcl --load ${HOME}/quicklisp/setup.lisp --script tetris.lisp
```

To run on Debian (bookworm), in the current directory:

```
$ apt -y install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev git ca-certificates pulseaudio sbcl cl-quicklisp libsdl2-2.0-0 libsdl2-mixer-2.0-0

# Install the SDL bindings.
$ git clone https://github.com/rpav/cl-autowrap.git quicklisp/cl-autowrap
$ git clone https://github.com/lispgames/cl-sdl2.git quicklisp/cl-sdl2
$ git clone https://github.com/lispgames/cl-sdl2-mixer quicklisp/cl-sdl2-mixer
$ git clone https://github.com/lispgames/cl-sdl2-image quicklisp/cl-sdl2-image
$ git clone https://github.com/Failproofshark/cl-sdl2-ttf.git quicklisp/cl-sdl-ttf

$ ./tetris.lisp
```

To build with Docker, from the top-level directory:

```
$ docker build -f cl/Dockerfile -t adamrogoyski/tetris-cl .
```

To run the binary from the docker image to avoid installing the dependencies:

```
sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} ${XAUTHORITY:+-v ${XAUTHORITY}:/root/.Xauthority} --net=host adamrogoyski/tetris-cl ./tetris.lisp
```



