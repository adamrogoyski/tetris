FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends golang
RUN apt install -y --no-install-recommends pulseaudio ca-certificates
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY go/Makefile .
COPY go/go.mod .
COPY go/tetris.go .
RUN make
