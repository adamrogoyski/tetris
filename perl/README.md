# Perl Tetris

Uses the SDL and SDLx modules.

See the Perl SDL [manual](https://raw.githubusercontent.com/PerlGameDev/SDL_Manual/master/dist/SDL_Manual.pdf).
and CPAN [page](https://metacpan.org/dist/SDL) for SDL and SDLx module APIs.

For the style used, see [Perl Critic](https://perlmaven.com/perl-critic).

To build with Docker, from the top-level directory:

```
$ docker build -f perl/Dockerfile -t adamrogoyski/tetris-perl .
```

To run the program from the docker image to avoid installing the dependencies:

```
$ sudo docker run --privileged -it -e DISPLAY=${DISPLAY} -e ${XDG_RUNTIME_DIR} -v ${XDG_RUNTIME_DIR} -v ${XAUTHORITY}:/root/.Xauthority --net=host adamrogoyski/tetris-perl ./tetris.pl
```

