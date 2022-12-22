.PHONY: all clean

CC = g++
CFLAGS = -g -O0 -Wall -pedantic -Wno-format-truncation -std=c++20
SDL2FLAGS = $(shell sdl2-config --cflags)
SDL2LIBS = $(shell sdl2-config --libs) -lSDL2_image -lSDL2_mixer -lSDL2_ttf

%.o: %.cc
	$(CC) $(CFLAGS) $(SDL2FLAGS) -c $<

all: tetris

tetris:	tetris.o
	$(CC) $(CFLAGS) $(SDL2FLAGS) -o tetris tetris.o $(SDL2LIBS)

clean:
	rm -f tetris *.o
