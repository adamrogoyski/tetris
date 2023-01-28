.PHONY: all clean

CC = fpc
SDL2UNITS = SDL2-for-Pascal/units
CFLAGS = -g -Fu$(SDL2UNITS)

all: pascal_sdl tetris

pascal_sdl:
	test -e SDL2-for-Pascal || git clone https://github.com/PascalGameDevelopment/SDL2-for-Pascal.git

tetris:
	$(CC) $(CFLAGS) -otetris tetris.pas

clean:
	rm -f tetris *.o
