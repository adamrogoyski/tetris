FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install ruby ruby-sdl
RUN apt install -y --no-install-recommends pulseaudio 
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY ruby/tetris.rb .
