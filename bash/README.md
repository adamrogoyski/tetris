# Bash Tetris.

A pure bash 4 or newer implementation of Tetris using no shelled-out commands other than stty.

The game functions the same as other implementations other than the graphics and sound.

There is a version with no music (_tetris.sh_) that is more portable. The version with music
(_tetris-with-music.sh_) has ony been tested on Linux with pulseaudio.

Assumes these [escape sequences](https://misc.flogisoft.com/bash/tip_colors_and_formatting) and a
supporting terminal.

On Mac OSX that ships with only bash 3, load a newer bash with

```
# Install Homebrew:
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Bash:
$ brew install bash

# Run with homebrew bash:
$ /opt/homebrew/bin/bash tetris.bash
```

Bash prior to version 4 doesn't support associative arrays or ${EPOCHREALTIME} which are used.

![Tetris gameplay](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/play-bash.png)
