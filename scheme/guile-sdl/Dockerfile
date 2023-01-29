FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends pulseaudio git ca-certificates
RUN apt install -y --no-install-recommends guile-3.0 guile-3.0-dev autoconf automake texinfo
RUN git clone https://git.dthompson.us/guile-sdl2.git && cd guile-sdl2 && autoreconf --install && ./configure && make && make install
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY scheme/guile-sdl/tetris.scm .
