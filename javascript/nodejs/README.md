# Javascript NodeJS Tetris

Uses the [kmamal/node-sdl](https://github.com/kmamal/node-sdl) SDL library
and [node-aplay](https://www.npmjs.com/package/node-aplay) sound library.

To build with Docker, from the top-level directory:

```
$ docker build -f javascript/nodejs/Dockerfile -t adamrogoyski/tetris-nodejs .
```

To run the program from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-nodejs node .
```

