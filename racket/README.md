# Scheme Guile SDL Tetris

Uses [Racket](https://racket-lang.org/) and its native
[drawing toolkit](https://docs.racket-lang.org/draw/index.html) and
[canvas](https://docs.racket-lang.org/gui/canvas_.html).

A limitation of racket/gui is that it can play sounds, but it cannot
stop them. Thus music selection is not useful. Instead, music plays,
randomly selecting the music throughout the game. But the music will
continue playing even after the game ends until the current song
completes.
