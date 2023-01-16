.PHONY: all clean

CC = gfortran
CFLAGS = -g -O0 -Wall -pedantic -I ~/f90/fortran-sdl2
SDL2FLAGS = $(shell sdl2-config --cflags)
SDL2LIBS = ~/f90/fortran-sdl2/*.a $(shell sdl2-config --libs) -lSDL2_image -lSDL2_ttf -lSDL2_mixer

%.o: %.f90
	$(CC) $(CFLAGS) $(SDL2FLAGS) -c $<

all: tetris

tetris:	tetris.o
	$(CC) $(CFLAGS) $(SDL2FLAGS) -o tetris tetris.f90 $(SDL2LIBS)

clean:
	rm -f tetris *.o
