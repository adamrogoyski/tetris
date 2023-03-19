# ZSH Tetris.

A pure zsh implementation of Tetris using no shelled-out commands other than stty.

This version has no music, but otherwise functions the same as other implementations.

Assumes these [escape sequences](https://misc.flogisoft.com/bash/tip_colors_and_formatting) and a
supporting terminal.

```
$ ./tetris.sh
```

Differences from the [Bash 4 implementation](https://github.com/adamrogoyski/tetris/tree/main/bash):

* Requires loading the [zsh/datetime](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#The-zsh_002fdatetime-Module) module
* Arrays indexed starting from 1 rather than 0
* Use of `${=var}` for [word splitting](https://zsh.sourceforge.io/Doc/Release/Expansion.html#Parameter-Expansion)
* Variables cannot be redeclared with declare without outputting to the screen
* The read builtin parameter -n instead of -k, and there's no way to poll without reading input
* `${EPOCHREALTIME}` has nanosecond resolution rather than millisecond
* `${status}` is a mirror of `$?` and can't be used, so is renamed `${state}`

![Tetris gameplay](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/play-bash.png)
