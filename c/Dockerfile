FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY c/Makefile .
COPY c/tetris.c .
RUN make
