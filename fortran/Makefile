.PHONY: all clean

CC = gfortran
CFLAGS = -g -O0 -Wall -pedantic -Ifortran-sdl2
SDL2FLAGS = $(shell sdl2-config --cflags)
SDL2LIBS = fortran-sdl2/*.a $(shell sdl2-config --libs) -lSDL2_image -lSDL2_ttf -lSDL2_mixer

%.o: %.f90
	$(CC) $(CFLAGS) $(SDL2FLAGS) -c $<

all: fortran_sdl tetris

fortran_sdl:
	test -e fortran-sdl2 || git clone https://github.com/interkosmos/fortran-sdl2.git
	$(MAKE) -C fortran-sdl2

tetris: tetris.o
	$(CC) $(CFLAGS) $(SDL2FLAGS) -o tetris tetris.f90 $(SDL2LIBS)

clean:
	rm -f tetris *.o
	$(MAKE) -C fortran-sdl2 clean
