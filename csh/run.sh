#!/bin/bash
#
# Wrap tetris.csh to work around two limitations of csh:
#   1. No ability to redirect only stderr
#   2. No ability to read input other than a line at a time.
#
# To accomplish (1), stderr is redirected from the invication below.
# To accomplish (2), raw mode is set in this wrapper, and a busy-loop
# polls for input. When it sees input, it reads 1 character and appends
# that caracter to file "input" on a line of its own. This allows
# tetris.csh to poll the lines of "input" and read the next line of
# input a line at a time.

function quit() {
  stty echo -raw
  exit 0
}

function end() {
  kill ${tetris_pid} 2>/dev/null
  quit
}

cat /dev/null > input
stty -echo raw
./tetris.csh "$@" 2>/dev/null &
declare -r tetris_pid=$!

trap quit SIGCHLD
trap end SIGINT
trap end SIGTERM
trap end EXIT
while :; do
  if IFS= read -n1 -t0 -r; then
    read -n1 -r v
    echo "${v}" >> input
  fi
done
