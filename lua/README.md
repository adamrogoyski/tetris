# Lua Tetris

Lua style is to use arrays indexed starting by 1 rather than 0. The Tetris
implementation conforms to this style, which is rather different than the other
implementations.

Uses the [lua-sdl2](https://github.com/Tangent128/luasdl2) library. Install with

```
$ luarocks install lua-sdl2

$ ./tetris.lua
```

To build on Debian (bookworm), in the current directory:

```
$ apt -y install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev libsdl2-net-dev luarocks
$ luarocks install lua-sdl2
```

To build with Docker, from the top-level directory:

```
$ docker build -f lua/Dockerfile -t adamrogoyski/tetris-lua .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-lua ./tetris.lua
```
