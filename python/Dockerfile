FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt install -y --no-install-recommends python3 python3-pygame python3-pygame-sdl2 
RUN apt install -y --no-install-recommends pulseaudio 
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY python/tetris.py .
