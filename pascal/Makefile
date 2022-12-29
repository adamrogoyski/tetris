.PHONY: all clean

CC = fpc
SDL2UNITS = /home/adam/pascal/SDL2-for-Pascal/units
CFLAGS = -g -Fu$(SDL2UNITS)

all: tetris

tetris:
	$(CC) $(CFLAGS) -otetris tetris.pas

clean:
	rm -f tetris *.o
