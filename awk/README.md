# AWK Tetris.

An AWK implementation of Tetris.

Shells out for functionality not available in AWK:

* obtaining the time in milliseconds (bash4 ${EPOCHREALTIME})
* polling the keyboard (bash4 read)
* reading the keyboard (dd)
* getting the screen width (tput cols)
* sleeping (sleep)

This version has no music, but otherwise functions the same as other implementations.

Assumes these [escape sequences](https://misc.flogisoft.com/bash/tip_colors_and_formatting) and a
supporting terminal.

Compare with the [Bash 4n](https://github.com/adamrogoyski/tetris/tree/main/bash) and
[ZSH](https://github.com/adamrogoyski/tetris/tree/main/zsh) implementations.

![Tetris gameplay](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/play-bash.png)
