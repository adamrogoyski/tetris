# CSH Tetris.

A csh implementation of Tetris.

Run using the supplied wrapper run.sh:

```sh
$ ./run.sh
```

This version has no music, but otherwise functions the same as other implementations.

Assumes these [escape sequences](https://misc.flogisoft.com/bash/tip_colors_and_formatting) and a
supporting terminal.

## Limitations of CSH

The CSH language has many limitations that need to be worked around.

### No Raw Keyboard Input

There's no way to read the keyboard other than a line at a time. To work 
around this, a bash wrapper is used that polls and reads the raw 
character input and appends it to an "input" file 1 character per line. 
tetris.csh can then poll the number of lines on this file and read the 
next unread line.

### No way to redirect stderr

CSH can redirect stdout, or both stdout and stderr, but no way to redirect just stderr. The bash wrapper runs the command in the background with stderr redirected. This is needed because other workarounds would otherwise print stderr messages to the screen. For example, random numbers.

### No Random Numbers

Since there is no random number functionality in CSH, the program assumes the existence of /dev/urandom and gets random bytes there. With no way to read input other than a line at a time, the following expression is used:

```sh
dd if=/dev/urandom bs=1 count=1 | od -Anone -tu1
```

### No Functions

There are no functions or subroutines that can be defined in CSH. The three options are to create an alias, use GOTO statements, or inline the function. All 3 were used due to inherent limitations of CSH.

Aliases have serious limitation in that you need to quote the alias in 'single quotes' so as to not evaluate variables at alias definition time. But this means that single quotes cannot be used within the entirety of the alias definition. This makes some functionality needed in tetris.csh impossible to represent. I also ran into trouble passing any positional arguments to more than a single alias.

GOTO statements are limited in that you cannot jump into a loop and finish the loop. This means that you cannot use a GOTO to execute a function and then return to continue execution if that execution is within a "which" or "foreach" block. For example:

```csh
@ i = 1
goto MIDDLE
while ( ${i} < 100 )
 MIDDLE:
  echo ${i}
end
```

```sh
$ csh test.csh
1
end: Not in while/foreach.
```

Notice that the goto worked, but the "end" statement was encountered without knowing it was in a while loop. Since the entirety of the program is a "while" game loop, GOTOs are all structured to return prior to the game loop.

The place where a line-clearing function call would be is inlined. It is within the game loop and must return to the same spot.

With both aliases and GOTOs, there's no uniform way to return values, so global variables are often used.

### No way to handle SIGWINCH Window Resize

The size of the Tetris logo is not adjusted on window resize because there's no way to trap signals in CSH.

### Variable Variable names must be accessed in multiple steps

The various starting_position and rotation data is accessed with names 
like ${starting_positions_4} since there is no multi-dimensional arrays. 
Multi-dimensional arrays are easily worked around by suffixing the 
dimensions to the variable name and having as many variables as needed. 

A limitation is that the name of the variable cannot be variable. For instance:

```csh
% @ i = 5
% set a_5 = 1

% echo ${a_5}
1

% echo ${a_${i}}
Missing }.
```

To make this work, more steps are needed to access these array-like variables:

```csh
% @ i = 5
% set a_5 = 1
% set t = '${a_'"${i}"'}'

% echo ${t}
$a_5

% @ r = `eval echo "${t}"`

% echo ${r}
1
```

This is used throughout the program.

### Short Circuit Logical Operations Evaluate the Short Circuited Operands

The short-circuit logical operator || should only execute the right side of the OR statement when the left side is false. CSH works this way, but it evaluates all the variables prior to execution. For example:

```csh
set a = (foo bar baz quux)
if ( 1 > 2 || ${a[5]} == "pizza" ) then
  echo OK
endif
```

```csh
a: Subscript out of range.
```

There are many checks that a piece is within the bounds of the game board before checking that the ${board_x_y} variable is filled in. Since the x or y may be beyond the board, this type of check cannot be in a single if block.

BASH has the same behavior in evaluating all the variables first. But BASH allows accessing any array element that doesn't exist and just gives back a null value:

```sh
declare -a a=(foo bar baz quux)
if [[ 1 -gt 2 || "${a[4]}" == "pizza" ]]; then
  echo OK
fi
```

works fine because while ${a[4]} is out of the previously-used range [0-3], it is valid to access an unused element. Making it fail needs to be explicitly asked for:

```sh
declare -a a=(foo bar baz quux)
if [[ 1 -gt 2 || "${a[4]:?error}" == "pizza" ]]; then
  echo OK
fi
```

```
example.sh: line 2: a[4]: error
```

# CSH Implementation Memory Leak

The Tetris game is supposed to increase the speed the tetrominos fall as the level increases, but sadly, this version gets slower the longer you play. This appears to be due to a memory leak in CSH from eval. To demonstrate the memory leak, just run the following program:

```csh
@ a = 1
while ( 1 )
  eval echo ${a} > /dev/null
end
```

```sh
adam@xps:~/tetris/csh$ while :; do ps v | grep [c]sh |& grep -v grep; sleep 1; done
    PID TTY      STAT   TIME  MAJFL   TRS   DRS   RSS %MEM COMMAND
2325615 pts/1    R+     0:00      0   106 14125 10748  0.0 csh ./leak.csh
2325615 pts/1    R+     0:01      0   106 36829 33452  0.2 csh ./leak.csh
2325615 pts/1    R+     0:02      0   106 60985 57476  0.3 csh ./leak.csh
2325615 pts/1    R+     0:03      0   106 84217 80708  0.5 csh ./leak.csh
2325615 pts/1    R+     0:04      0   106 108373 104996  0.6 csh ./leak.csh
2325615 pts/1    R+     0:05      0   106 132397 129020  0.8 csh ./leak.csh
2325615 pts/1    R+     0:06      0   106 156685 153308  0.9 csh ./leak.csh
2325615 pts/1    R+     0:07      0   106 180841 177332  1.1 csh ./leak.csh
2325615 pts/1    R+     0:08      0   106 204205 200828  1.2 csh ./leak.csh
2325615 pts/1    R+     0:09      0   106 225985 222476  1.3 csh ./leak.csh
```

Needless to say, this is not good. Since eval is critical to even access the suffixed variables taking the role of mulit-dimensional arrays, memory usage goes up rather quickly and performance suffers.

Performance is already not great due to the busy loop in the bash wrapper.

![Tetris gameplay](https://raw.githubusercontent.com/adamrogoyski/tetris/main/screenshots/play-bash.png)
