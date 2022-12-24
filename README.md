# Tetris

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

The following languages are implemented:

* C (SDL)
* C++ (SDL)
* Go (SDL)
* Perl (SDL, SDLx)
* Python3 (Pygame using SDL)
* Scheme (guile using Chickadee (SDL based))

I intend to write more language implementations.

The implementations are meant to function almost identically, though small
differences exist. Some differences are:

* Keyboard handling and repeated key presses are close but not identical.
* The timing of the frame rate and piece-drop rate is within a few percent the same.
* The C, C++, and Go versions use GPU textures, so the board can be easily scaled.
    * The Python and Scheme versions use bitmaps and are at a fixed size.
* The Scheme version makes unnecessary copies of the board game-state to keep a consistent style.
* The Scheme version uses lists rather than vectors for everything.

The music is performed by me on guitar. They should be close to note-for-note identical to the
three Nintendo Gameboy Tetris songs.

The graphics are 7 32x32-pixel blocks created with GNU Gimp, a wall image created with GNU Gimp,
and the TETЯIS logo due to the free font used not having the Я character.

The game is intentionally harder than other Tetris implementations. The level increases every 3
lines instead of 10. Lines are tracked, but there's no score. Embrace the inevitability of losing.

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

When auto-advance collides, line clearing is is performed, and the next piece is started unless
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

* C/C++/Go: a cleared row pointer is set aside, all other row pointers moved down one, and the cleared row placed at the top.
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
place the piece low enough that a rotation is possible without exceed the top of the board.

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
