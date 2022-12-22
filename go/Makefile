.PHONY: all clean

CC = go

all: tetris

tetris:	tetris.go
	$(CC) get github.com/veandco/go-sdl2/img
	$(CC) get github.com/veandco/go-sdl2/mix
	$(CC) get github.com/veandco/go-sdl2/sdl
	$(CC) get github.com/veandco/go-sdl2/ttf
	$(CC) build

clean:
	$(CC) clean
