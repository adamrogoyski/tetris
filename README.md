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
