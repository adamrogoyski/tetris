# PHP Tetris

Uses the SDL library. Testing with PHP 8.2.1

To run on Debian (bookworm), in the current directory:

```
$ apt install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
$ apt install php php-dev php-pear

$ pear channel-update pear.php.net
$ pecl channel-update pecl.php.net
$ pecl install sdl-beta

$ git clone https://github.com/kea/php-sdl-mixer.git
$ cd php-sdl-mixer && phpize && ./configure --enable-sdl-mixer && make && make install

$ git clone https://github.com/kea/php-sdl-image.git
$ cd php-sdl-image && phpize && ./configure --enable-sdl_image && make && make install

$ git clone https://github.com/Ponup/php-sdl-ttf.git
$ cd php-sdl-ttf && phpize && ./configure --enable-sdl_ttf && make && make install

$ echo "extension=sdl.so\nextension=sdl_mixer.so\nextension=sdl_image.so\nextension=sdl_ttf.so\n" > php.ini

$ ./tetris.rb
```

To build with Docker, from the top-level directory:

```
$ docker build -f php/Dockerfile -t adamrogoyski/tetris-php .
```

To run the program from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-php ./tetris.php
```

