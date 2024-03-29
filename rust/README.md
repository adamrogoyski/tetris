# Rust Tetris

The SDL2 library is used.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install rustc cargo gcc libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
$ cargo build
$ cargo run
```

To build with Docker, from the top-level directory:

```
$ docker build -f rust/Dockerfile -t adamrogoyski/tetris-rust .

# Copy the dynamically-linked binary out of the image.
$ docker cp $(docker create --name temp_container_tetris_rust adamrogoyski/tetris-rust:latest):/usr/src/tetris/target/debug/tetris . && docker rm temp_container_tetris_rust

# Install the SDL2 dependencies
$ apt install libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0

$ ./tetris
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-rust cargo run
```
