FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install perl libsdl-perl make
RUN apt install -y --no-install-recommends pulseaudio 
RUN bash -c "yes  $'\n' | cpan -i Readonly"
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY perl/tetris.pl .
