FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt update && apt -y --no-install-recommends install php php-dev php-pear
RUN apt install -y --no-install-recommends pulseaudio git ca-certificates
RUN pear channel-update pear.php.net
RUN pecl channel-update pecl.php.net
RUN pecl install sdl-beta
RUN git clone https://github.com/kea/php-sdl-mixer.git
RUN cd php-sdl-mixer && phpize && ./configure --enable-sdl-mixer && make && make install
RUN git clone https://github.com/kea/php-sdl-image.git
RUN cd php-sdl-image && phpize && ./configure --enable-sdl_image && make && make install
RUN git clone https://github.com/Ponup/php-sdl-ttf.git
RUN cd php-sdl-ttf && phpize && ./configure --enable-sdl_ttf && make && make install
RUN echo "extension=sdl.so\nextension=sdl_mixer.so\nextension=sdl_image.so\nextension=sdl_ttf.so\n" > php.ini
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY php/tetris.php .
