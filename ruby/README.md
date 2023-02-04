# Ruby Tetris

Uses the SDL library.

To run on Debian (bookworm), in the current directory:

```
$ apt -y install ruby ruby-sdl

$ ./tetris.rb
```

To build with Docker, from the top-level directory:

```
$ docker build -f ruby/Dockerfile -t adamrogoyski/ruby-perl .
```

To run the program from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-ruby ./tetris.rb
```

