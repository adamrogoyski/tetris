# Tetris [![License: CC0-1.0](https://img.shields.io/badge/License-CC0_1.0-lightgrey.svg)](https://spdx.org/licenses/CC-PDDC.html)

Multiple implementations of a simple Tetris game in many languages.

![Tetris gameplay](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/play.png)

Tetris is simple enough to write in 400-500 lines, yet encompasses many
different elements of a program:

* Graphics
* Sound
* Bitmaps or Textures
* Keyboard input
* Font rendering
* Command-line text output
* Multi-dimensional data structures
* Time and frame handling
* State that needs to be accessed and updated
* Command-line arguments

The following languages are implemented:

* AWK (ASCII)
* Bash (ASCII)
* C (SDL)
* C++ (SDL)
* D (SDL)
* Fortran (SDL)
* Go (SDL)
* Groovy (JVM AWT)
* Java (JVM AWT)
* Javascript
    * NodeJS using SDL and Canvas
    * Web browser with Canvas ([try it](https://www.rogoyski.com/adam/programs/tetris-web/))
* Lua (SDL)
* Pascal (SDL)
* Perl (SDL, SDLx)
* PHP (SDL)
* Python3 (Pygame using SDL)
* Racket (racket/gui)
* Ruby (SDL)
* Rust (SDL)
* Scheme
    * Guile (SDL)
    * Guile (Chickadee based on SDL)
* TCL (TK)
* Typescript (NodeJS using SDL and Canvas)
* Zsh (ASCII)

I intend to write more language implementations.

The implementations are meant to function almost identically, though small
differees exist. Some differences are:

* Keyboard handling and repeated key presses are close but not identical.
* The timing of the frame rate and piece-drop rate is within a few percent the same.
* Implementation that can render the PNGs and font text as textures can be resized and scaled.
* The Scheme version makes unnecessary copies of the board game-state to keep a consistent style.
* The Scheme version uses lists rather than vectors for everything.
* The Scheme chickadee version has the y coordinate axis flipped.
* The Javascript versions are written with asynchronous callbacks.
* The Fortran, Lua, and Zsh version uses arrays indexed starting at 1.
* The Fortran version uses column-based arrays.
* The Racket version has limited support for music, and no command-line arguments.
* The AWK, Bash, and Zsh versions have no sound and don't support resizing.

The music is performed by me on guitar. They should be close to note-for-note identical to the
three Nintendo Gameboy Tetris songs.

The graphics are 7 32x32-pixel blocks created with GNU Gimp, a wall image created with GNU Gimp,
and the TETЯIS logo due to the free font used not having the Я character.

The game is intentionally harder than other Tetris implementations. The level increases every 3
lines instead of 10. Lines are tracked, but there's no score. Embrace the inevitability of losing.

## Specification

### Rotation System

The rotation system specifies the 4 rotations of each tetromino.

![Rotation System](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/rotation_system.png)

### Randomizer

Piece selection uses an unbiased random selection of pieces. All pieces are
equally likely at all times.

### Layout

The board (left of the wall separator) must be at least 4 blocks wide and 3 blocks in height, though the game will
end after 1 or any 2 non-long tetrominos at that size. The recommended board size is 10 blocks wide
and 20 blocks in height.

The status area (right of the wall separator) is 6 blocks wide. It contains the logo, lines completed, and level.

### Positions

* Board: left adjent to playing board. Height of the screen equal to board height
* Wall: right adjacent to playing board
* Logo: status area, centered, 90% status width, 20% status height, at top of screen
* Level: status area, centered, 90% status width, 10% status height, 25% from top
* Lines completed: status area, centered, 90% status width, 10% status height, 35% from top
* Gameover message: Centered, full width, 12.5% height
* Next piece: status area, 45% from top, 2 block size left margin from wall

### Scoring

There is no score. Level is increased every 3 cleared lines. Maximum level is 15.

## Code Walk through

Each implementation is similar in approach, with various changes for the style
or convenience of the language.

### Initialization

The SDL or higher-level library usually needs to initialize a window or canvas, load the
graphics files as bitmaps or textures, load the music and sound, setup event handling,
load the custom font, print the console instructions, seed the random-number generator, and
then get going with the game logic.

As part of the setup, an initial piece and the next piece are chosen prior to entering the
game loop.

### Game Loop

The game loop loops until reaching the game-over condition and has three functions:

* Handle keyboard events
* Track the passage of time in terms of screen-update frames and various frame-counting ticks
* Auto-advance blocks downward at a set rate based on the number of lines completed.

When auto-advance collides, line clearing is performed, and the next piece is started unless
the game is over.

The game intends to stick to 60 frames-per-second (FPS), with counters (ticks) counting frames.

### Screen Updates

Updates to the screen use double buffering: Updates are written to the frame-buffer and then flipped
with the current buffer to update the screen in one go per frame.

The placement on the screen is done relative to the block size. The PNG images of the 7 colored blocks
are 32x32 pixels. For implementations using bitmaps, this is a fixed screen size and placement. For
implementations using GPU textures, the block_size constant can be changed to change the size and scale
of the window.

Drawing the screen each frame performs the following steps:

* Clear or fill the screen with a black rectangle (if needed per implementation)
* Fill the play board with colored blocks matching the board 2d array
    * A black is used to make this a simple table lookup and overwriting the entire board
* Draw the non-play (status) part of the screen
    * Draw the wall separator
    * Print the logo
    * Write the lines and level
    * Show the next piece

### Line Clearing

Full lines being cleared is the goal of Tetris. After auto-advancing a piece collides, all
lines are checked for fullness and removed -- up to 4 lines possibly cleared at once.

This is the area where each implementation is likely to be the most different, based on what feels
natural for the language and data structure used:

* C/C++/Go/Pascal/Perl: a cleared row pointer is set aside, all other row pointers moved down one, and the cleared row placed at the top.
* Python: rows of the board are deleted and new all-zero rows are added to the top.
* Scheme: The create-board initialization is reused, passing a partial board filtering full lines.

Every 3 lines cleared ups the level of the game, which is controlled by waiting fewer game ticks
(frames) before auto-advancing the piece down.

### Placing a new piece

A new piece is always placed at the top of the board, centered. A table of starting positions gives
each piece's coordinates relative to the top center of the screen. The same table is used to place
the status view of the next available piece relative to its position in the status area.

A piece is represented by its color, a set of 4 (x,y) coordinates, and it's one of four orientations (rotations).

### Moving a Piece

Moving a piece assumes there will not be a collision. The piece's coordinates are zeroed
on the board (i.e.replace colored blocks with black blocks) and added to the new coordinates.

### Rotating a Piece

Rotating a piece assumes there will not be a collision. The basic arithmetic to rotate a
piece's coordinates, while not difficult, is avoidable with a few minutes of drawing
pieces on graph paper and mapping each block of each piece from each orientation to what its
next location would be when rotated. Using this table of rotations is the approach taken.

There is more to learn about each programming language dealing with creating and accessing
this table of rotations than to write the arithmetic function.

Rotation of the 2x2 square tetromino is a no-op. Similarly, other pieces have rotational symmetries.
Despite this, all rotations of each piece in each orientation are provided.

### Collision Detection

A piece has collided with something if it tries to go beyond the 4 walls or go where another
block already exists. Colliding with the top wall is possible when rotating a piece after
placement due to placing the piece as high as is possible. Some implementations of Tetris
place the piece low enough that a rotation is possible without exceeding the top of the board.

### Game Over Condition

The game-over condition is reached when placing a board piece is no longer possible due to the
new board piece colliding.

Once the game-over condition is reached, the game loop is exited. The game-over melody and message
are presented and the screen is updated one last time. Then a new game loop is entered to handle
key presses to exit the program.

### Keyboard Events

Polling of keyboard events checks whether a keyboard press has occurred. Rather than busy loop polling,
a short millisecond delay is usually added to each game-loop iteration to reduce load.

Keyboard handling is an area that likely has the most variance across the implementations.
