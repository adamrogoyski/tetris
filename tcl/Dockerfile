FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install tcl tcl-snack tk
RUN apt install -y --no-install-recommends pulseaudio
COPY graphics/ graphics/
COPY sound/ sound/
COPY tcl/tetris.tcl .
