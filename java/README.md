# Java Tetris

The AWT library is used with a canvas element.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install openjdk-17-jre:amd64 openjdk-17-jdk:amd64
$ javac -encoding ISO-8859-1 Tetris.java
```

To build with Docker, from the top-level directory:

```
$ docker build -f java/Dockerfile -t adamrogoyski/tetris-java .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} ${XAUTHORITY:+-v ${XAUTHORITY}:/root/.Xauthority} --net=host adamrogoyski/tetris-java java Tetris
```
