# Groovy Tetris

The AWT library is used with a canvas element.

To build on Debian (bookworm), in the current directory:

```
$ apt -y install openjdk-17-jre:amd64 openjdk-17-jdk:amd64 groovy
```

To build with Docker, from the top-level directory:

```
$ docker build -f groovy/Dockerfile -t adamrogoyski/tetris-groovy .
```

To run the binary from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -e JAVA_HOME=/ -v ${XDG_RUNTIME_DIR} ${XAUTHORITY:+-v ${XAUTHORITY}:/root/.Xauthority} --net=host adamrogoyski/tetris-groovy groovy tetris.groovy

```
