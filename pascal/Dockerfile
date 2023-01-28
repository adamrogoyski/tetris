FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc fpc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends pulseaudio 
RUN apt install -y --no-install-recommends git ca-certificates
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY pascal/Makefile .
COPY pascal/tetris.pas .
RUN make
