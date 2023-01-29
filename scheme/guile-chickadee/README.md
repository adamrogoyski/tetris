# Scheme Guile Chickadee Tetris

Runs with the Scheme guile implementation using the
[Chickadee](https://dthompson.us/projects/chickadee.html) game library,
which is based on SDL. After installing chickadee and its dependencies, run with:

```
$ chickadee play tetris.scm
```

If you'd like to run and try modifying the code without installing GNU guile
and the Chickadee prerequisites, a bundled version is available for x86 Linux:
https://www.rogoyski.com/adam/programs/tetris-chickadee.tar.bz2

To run on Debian (bookworm), in the current directory:

```
# Install basic C SDL dependencies.
$ apt install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev

# Install Guile and dependencies to build Chickadee and its dependencies.
$ apt install -y --no-install-recommends guile-3.0 guile-3.0-dev autoconf automake texinfo libturbojpeg0-dev libopenal-dev

# Fetch and build guile-sdl2.
$ git clone https://git.dthompson.us/guile-sdl2.git 
$ cd guile-sdl2
$ autoreconf --install
$ ./configure
$ make
$ make install

# Fetch and build guile-opengl.
$ curl -oguile-opengl-0.1.0.tar.gz https://ftp.gnu.org/gnu/guile-opengl/guile-opengl-0.1.0.tar.gz
$ tar -zxvf guile-opengl-0.1.0.tar.gz
$ cd guile-opengl-0.1.0
# Update autoconf script for Guile 3.0
$ sed -i 's/2.2 2.0/3.0 2.2 2.0/' configure
$ sed -i 's/2.2 2.0/3.0 2.2 2.0/' configure.ac
$ autoreconf
$ ./configure
$ make
$ make install

# Fetch and build Chickadee.
$ git clone https://git.dthompson.us/chickadee.git
$ cd chickadee
$ autoreconf --install
$ ./configure
$ make
$ make install"

$ chickadee play tetris.scm
```

To build with Docker, from the top-level directory:

```
$ docker build -f scheme/guile-chickadee/Dockerfile -t adamrogoyski/tetris-chickadee .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-chickadee chickadee play tetris.scm
```



