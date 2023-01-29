# Typescript targeting NodeJS Tetris

Uses the [kmamal/node-sdl](https://github.com/kmamal/node-sdl) SDL library
and [node-aplay](https://www.npmjs.com/package/node-aplay) sound library.

On Debian (bookworm), install Typescript for NodeJS and required modules:

```
$ npm install typescript
$ npm install @types/node --save-dev
$ npm install @kmamal/sdl
$ npm install canvas
$ npm install node-aplay
```

Build:

```
$ npx tsc tetris.ts
```

Run:

```
$ node tetris.js
```

To build with Docker, from the top-level directory:

```
$ docker build -f typescript/Dockerfile -t adamrogoyski/tetris-typescript .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-typescript node tetris.js
```

