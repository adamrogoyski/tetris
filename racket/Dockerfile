FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install racket libgtk2.0-0
RUN apt install -y --no-install-recommends pulseaudio 
COPY graphics/ graphics/
COPY sound/ sound/
COPY racket/tetris.scm .
