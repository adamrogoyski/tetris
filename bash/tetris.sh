#!/bin/bash
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.
#
# The only non-bash dependency is stty.

function quit() {
  stty echo -raw
  exit
}
trap quit SIGINT
trap quit SIGQUIT
trap quit SIGTERM

# Don't echo characters, use raw terminal input, and clear the screen.
stty -echo raw
shopt -s checkwinsize
echo -e "\ec"

declare -i completed_lines=0
if [[ ${#*} -gt 0 ]]; then
  completed_lines=$((${1} * 3))
fi

declare -ir WIDTH=10
declare -ir HEIGHT=20
declare -r BLOCK_SIZE="  "
declare -ir NUM_TETROMINOS=7
declare -ir FRAME_RATE_MS=$((1000 / 60))
declare -r FRED='\e[91m'
declare -r BLACK='\e[40m'
declare -r BLUE='\e[104m'
declare -r CYAN='\e[46m'
declare -r GREEN='\e[102m'
declare -r LRED='\e[101m'
declare -r PURPLE='\e[45m'
declare -r RED='\e[41m'
declare -r YELLOW='\e[103m'
declare -r DARK_GRAY='\e[100m'
declare -r LIGHT_GRAY='\e[47m '
declare -ra COLORS=("${BLUE}" "${CYAN}" "${GREEN}" "${LRED}" "${PURPLE}" "${RED}" "${YELLOW}")

declare -A board=()
function make_board() {
  declare -i x=0
  declare -i y=0
  for ((x=1; x <= WIDTH; x++)) do
    for ((y=1; y <= HEIGHT; y++)) do
      board[${x},${y}]="${BLACK}"
    done
  done
}
make_board

declare -i current_piece=$((RANDOM % NUM_TETROMINOS))
declare -i next_piece=$((RANDOM % NUM_TETROMINOS))
declare -i current_orientation=0

# Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
declare -a starting_positions
starting_positions[0]='-1,0 -1,1 0,1 1,1' # Leftward L piece.
starting_positions[1]='-1,1 0,1 0,0 1,0'  # Rightward Z piece.
starting_positions[2]='-2,0 -1,0 0,0 1,0' # Long straight piece.
starting_positions[3]='-1,1 0,1 0,0 1,1'  # Bump in middle piece.
starting_positions[4]='-1,1 0,1 1,1 1,0'  # L piece.
starting_positions[5]='-1,0 0,0 0,1 1,1'  # Z piece.
starting_positions[6]='-1,0 -1,1 0,0 0,1' # Square piece.

# Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
# Each rotation is a set of 4 rotations -- one for each orientation of a tetromino.
# For each rotation, there is an array of 4 (int x, int y) coordinate diffs for
# each block of the tetromino. The coordinate diffs map each block to its new location.
# The associative-array index is (piece,orientation) and maps to (dx,dy) for each block
# of the tetromino.
declare -A rotations=()
# Tetromino 0: Leftward L.
rotations[0,0]='0,2 1,1 0,0 -1,-1'
rotations[0,1]='2,0 1,-1 0,0 -1,1'
rotations[0,2]='0,-2 -1,-1 0,0 1,1'
rotations[0,3]='-2,0 -1,1 0,0 1,-1'
# Tetromino 1: Rightward Z. Orientation symmetry: 0==2 and 1==3.
rotations[1,0]='1,0 0,1 -1,0 -2,1'
rotations[1,1]='-1,0 0,-1 1,0 2,-1'
rotations[1,2]='1,0 0,1 -1,0 -2,1'
rotations[1,3]='-1,0 0,-1 1,0 2,-1'
# Tetromino 2: Long straight. Orientation symmetry: 0==2 and 1==3.
rotations[2,0]='2,-2 1,-1 0,0 -1,1'
rotations[2,1]='-2,2 -1,1 0,0 1,-1'
rotations[2,2]='2,-2 1,-1 0,0 -1,1'
rotations[2,3]='-2,2 -1,1 0,0 1,-1'
# Tetromino 3: Bump in middle.
rotations[3,0]='1,1  0,0 -1,1 -1,-1'
rotations[3,1]='1,-1 0,0 1,1 -1,1'
rotations[3,2]='-1,-1 0,0 1,-1 1,1'
rotations[3,3]='-1,1 0,0 -1,-1 1,-1'
# Tetromino 4: L.
rotations[4,0]='1,1 0,0 -1,-1 -2,0'
rotations[4,1]='1,-1 0,0 -1,1 0,2'
rotations[4,2]='-1,-1 0,0 1,1 2,0'
rotations[4,3]='-1,1 0,0 1,-1 0,-2'
# Tetromino 5: Z. Orientation symmetry: 0==2 and 1==3.
rotations[5,0]='1,0 0,1 -1,0 -2,1'
rotations[5,1]='-1,0 0,-1 1,0 2,-1'
rotations[5,2]='1,0 0,1 -1,0 -2,1'
rotations[5,3]='-1,0 0,-1 1,0 2,-1'
# Tetromino 6: Square. Orientation symmetry: 0==1==2==3.
rotations[6,0]='0,0 0,0 0,0 0,0'
rotations[6,1]='0,0 0,0 0,0 0,0'
rotations[6,2]='0,0 0,0 0,0 0,0'
rotations[6,3]='0,0 0,0 0,0 0,0'

declare -a current_coords

function add_board_piece() {
  declare -r piece=$1; shift
  declare -r color="${COLORS[${piece}]}"
  declare -ri center=$((WIDTH / 2))
  declare coord
  current_coords=()
  for coord in ${starting_positions[${piece}]}; do
    declare -i x=$((center + ${coord%%,*}))
    declare -i y=$((1 + ${coord##*,}))
    declare xy="${x},${y}"
    if [[ ${board[${xy}]} != "${BLACK}" ]]; then
      return 1
    fi
    board[${xy}]="${color}"
    current_coords+=("${xy}")
  done
}
add_board_piece ${current_piece}

function move_tetromino() {
  declare -ri dx=$1; shift
  declare -ri dy=$1; shift
  declare -r color="${COLORS[${current_piece}]}"
  declare coord
  for coord in ${current_coords[*]}; do
    board[${coord}]="${BLACK}"
  done
  declare -a new_coords=()
  for coord in ${current_coords[*]}; do
    declare -i nx=$((${coord//,*} + dx))
    declare -i ny=$((${coord##*,} + dy))
    declare xy="${nx},${ny}"
    board[${xy}]="${color}"
    new_coords+=("${xy}")
  done
  current_coords=("${new_coords[@]}")
}

function boundary_condition() {
  declare -ri dx=$1; shift
  declare -ri dy=$1; shift
  declare coord
  for coord in ${current_coords[*]}; do
    declare -i nx=$((${coord//,*} + dx))
    declare -i ny=$((${coord##*,} + dy))
    if [[ ${nx} -lt 1 || ${nx} -gt ${WIDTH} || ${ny} -lt 1 || ${ny} -gt ${HEIGHT} ]]; then
      return 0
    fi
  done
  return 1
}

function colission_detected() {
  declare -ri dx=$1; shift
  declare -ri dy=$1; shift
  # Create a copy of the board.
  declare -A tboard
  declare -i x y
  for ((x=1; x <= WIDTH; x++)) do
    for ((y=1; y <= HEIGHT; y++)) do
      declare xy="${x},${y}"
      tboard[${xy}]="${board[${xy}]}"
    done
  done
  # Clear the current location of the tetromino.
  declare coord
  for coord in ${current_coords[*]}; do
    tboard[${coord}]="${BLACK}"
  done
  # Check if the updated coordinates collide with a non-black block.
  for coord in ${current_coords[*]}; do
    declare -i nx=$((${coord//,*} + dx))
    declare -i ny=$((${coord##*,} + dy))
    declare xy="${nx},${ny}"
    if [[ "${tboard[${xy}]}" != "${BLACK}" ]]; then
      return 0
    fi
  done
  return 1
}

function set_coords() {
  declare -r color=$1; shift
  while [[ $# -gt 0 ]]; do
    declare -i x=$((${1%%,*}))
    declare -i y=$((${1##*,}))
    declare xy="${x},${y}"
    board[${xy}]=${color}
    shift
  done
}

function rotate() {
  declare -a new_coords
  declare -i i=0
  for dxdy in ${rotations[${current_piece},${current_orientation}]}; do
    declare -i dx=$((${dxdy%%,*}))
    declare -i dy=$((${dxdy##*,}))
    declare -i x=$((${current_coords[${i}]%%,*}))
    declare -i y=$((${current_coords[${i}]##*,}))
    declare -i nx=$((x + dx))
    declare -i ny=$((y + dy))
    declare xy="${nx},${ny}"
    new_coords+=("${xy}")
    ((i++))
  done
  set_coords "${BLACK}" "${current_coords[@]}"
  for ((i=0; i < 4; i++)); do
    declare -i x=$((${new_coords[${i}]%%,*}))
    declare -i y=$((${new_coords[${i}]##*,}))
    if [[ ${x} -lt 1 || ${x} -gt ${WIDTH} || ${y} -lt 1 || ${y} -gt ${HEIGHT} ]]; then
      set_coords "${COLORS[${current_piece}]}" "${current_coords[@]}"
      return 1
    fi
  done
  set_coords "${COLORS[${current_piece}]}" "${new_coords[@]}"
  current_coords=("${new_coords[@]}")
  ((current_orientation = (current_orientation + 1) % 4))
  return 0
}

# Clear completed (filled) rows.
# Start from the bottom of the board, moving all rows down to fill in a completed row, with
# the completed row cleared and placed at the top.
function clear_board() {
  declare -i rows_deleted=0
  declare -i row

  for ((row=HEIGHT; row > rows_deleted;)); do
    declare -i has_hole=0
    declare -i x
    for ((x=1; x <= WIDTH && has_hole == 0; x++)); do
      if [[ "${board[${x},${row}]}" == "${BLACK}" ]]; then
        has_hole=1
      fi
    done
    if [[ has_hole -eq 0 ]]; then
      declare -i y
      for ((y=row; y > rows_deleted+1; y--)); do
        declare -i col
        for ((col=1; col <= WIDTH; col++)); do
          declare -i prow=$((y - 1))
          board[${col},${y}]=${board[${col},${prow}]}
        done
      done
      declare -i col
      for ((col=1; col <= WIDTH; col++)); do
        board[${col},${rows_deleted}]="${BLACK}"
      done
      ((rows_deleted++))
    else
      ((row--))
    fi
  done
  ((completed_lines += rows_deleted))
}

function poll_keyboard() {
  declare -ri chars=${1:-1}
  IFS= read -n${chars} -t0 -r
}

declare -ir logobig_width=66
declare -ir logobig_height=8
declare -a logobig
logobig[0]='*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT    *RRRRRR    *II     *SSSSS'
logobig[1]='*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT   *RR   RR    *II   *SSSS'
logobig[2]='    *TT       *E             *TT      *RR    RR    *II   *SS'
logobig[3]='    *TT       *EEEEEEE       *TT       *RR   RR    *II     *SSSS'
logobig[4]='    *TT       *EEEEEEE       *TT         *RRRRR    *II        *SSS'
logobig[5]='    *TT       *E             *TT       *RR   RR    *II         *SS'
logobig[6]='    *TT       *EEEEEEE       *TT      *RR    RR    *II      *SSSS'
logobig[7]='    *TT       *EEEEEEE       *TT     *RR     RR    *II    *SSSS '

declare -ir logosml_width=42
declare -ir logosml_height=5
declare -a logosml
logosml[0]='*TTTTTT *EEEEE *TTTTTT   *RRRR  *II   *SSS'
logosml[1]='  *TT   *E       *TT   *RR  RR  *II  *S'
logosml[2]='  *TT   *EEEEE   *TT      *RRR  *II   *SSS'
logosml[3]='  *TT   *E       *TT    *R  RR  *II     *S'
logosml[4]='  *TT   *EEEEE   *TT  *RR   RR  *II  *SSS'

function draw_screen() {
  echo -ne "\e[1;0H"
  # Draw the play board.
  for ((y=1; y <= HEIGHT; y++)) do
    for ((x=1; x <= WIDTH; x++)) do
      echo -ne "${board[${x},${y}]}${BLOCK_SIZE}"
    done
    # Draw the wall separating the board and status area.
    echo -ne "${DARK_GRAY} ${LIGHT_GRAY}"
    echo -e '\e[49m\r'
  done
  echo -e "${FRED}\r
\r
TETЯIS:\r
\r
  usage: ./tetris [level 1-15]\r
\r
  ESC - Quit.\r
  p   - Pause.\r
\r
  Up - Rotate.\r
  Down - Lower.\r
  Space - Drop completely.\r"

  # Draw the logo.
  declare -i logo_w
  declare -i logo_h
  declare logo
  declare -ir status_left=$((WIDTH*2 + 4))
  declare -ir status_width=$((COLUMNS - WIDTH*2 - 4))
  declare -i status_height=3
  if [[ ${status_width} -ge ${logobig_width} ]]; then
    declare -i i
    for ((i=0; i < logobig_height; i++)); do
      echo -ne "\e[$((i+1));${status_left}H${FRED}${logobig[${i}]}"
    done
    status_height="$((logobig_height + 2))"
  elif [[ ${status_width} -ge ${logosml_width} ]]; then
    declare -i i
    for ((i=0; i < logosml_height; i++)); do
      echo -ne "\e[$((i+1));${status_left}H${FRED}${logosml[${i}]}"
    done
    status_height="$((logosml_height + 2))"
  else
    echo -ne "\e[1;${status_left}H${FRED} TETRIS"
  fi

  # Draw status elements.
  echo -ne "\e[${status_height};${status_left}H${FRED} Lines: ${completed_lines}"
  echo -ne "\e[$((status_height+2));${status_left}H${FRED} Level: $((completed_lines / 3))"

  # Clear out previous next tetromino.
  echo -ne "\e[$((status_height+5));$((status_left+1))H${color}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}"
  echo -ne "\e[$((status_height+6));$((status_left+1))H${color}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}"

  # Draw next tetromino.
  declare -r color="${COLORS[${current_piece}]}"
  declare coord
  for coord in ${starting_positions[${current_piece}]}; do
    declare -i x=$((${coord%%,*}))
    declare -i y=$((${coord##*,}))
    echo -ne "\e[$((status_height+5+y));$((status_left+5+x*2))H${color}  "
  done
  echo -ne "\e[$((HEIGHT+13));0H\e[39m\e[49m"
}

function gameover() {
  # Clear out a rectangular box.
  declare line i
  for ((i=0; i <= WIDTH+8; i++)); do
    line="${line}${BLOCK_SIZE}"
  done
  echo -ne "\e[$((HEIGHT/2-1));0H${BLACK}${line}"
  echo -ne "\e[$((HEIGHT/2));0H${BLACK}${line}"
  echo -ne "\e[$((HEIGHT/2+1));0H${BLACK}${line}"
  echo -ne "\e[$((HEIGHT/2));0H${FRED} The only winning move is not to play"
  echo -ne "\e[$((HEIGHT+13));0H\e[39m\e[49m"

  while :; do
    if poll_keyboard; then
      declare key
      IFS= read -n1 -r key
      # An escape sequence followed by 2 additional characters could
      # be an arrow key. Otherwise, just treat it as the esc key.
      poll_keyboard 2
      if [[ "${key}" == $'\e' && $? == 0 ]]; then
        IFS= read -n2 -r key
      fi
      case "${key}" in
        q|$'\e')
          quit
        ;;
      esac
    fi
    sleep 0.1
  done
}

# Append seconds and microseconds, dividing by 1000 to get milliseconds.
# Fall back to the date command for old versions of bash.
declare -i start_ms="$((${EPOCHREALTIME%%.*}${EPOCHREALTIME##*.} / 1000))"
start_ms=${start_ms:-$(($(date +%s%N)/1000000))}
function time_ms() {
  declare -i now_msd
  if [[ -n "${EPOCHREALTIME}" ]]; then
    now_ms=$((${EPOCHREALTIME%%.*}${EPOCHREALTIME##*.} / 1000))
  else
    now_ms=$(($(date +%s%N)/1000000))
  fi
  echo "$((now_ms - start_ms))"
}

draw_screen
declare status="play"
declare -i game_ticks=0
declare -i drop_ticks=0
declare -i last_frame_ms=$(time_ms)
while :; do
  declare changed=""
  if poll_keyboard; then
    declare key
    IFS= read -n1 -r key
    # An escape sequence followed by 2 additional characters could
    # be an arrow key. Otherwise, just treat it as the esc key.
    poll_keyboard 2
    if [[ "${key}" == $'\e' && $? == 0 ]]; then
      IFS= read -n2 -r key
    fi
    case "${key}" in
      q|$'\e')
        quit
      ;;
      p)
        if [[ "${status}" == "play" ]]; then
          status="pause"
        else
          status="play"
        fi
      ;;
    esac
    if [[ "${status}" == "play" ]]; then
      case "${key}" in
        a|'[D') #Left.
          if ! boundary_condition -1 0 && ! colission_detected -1 0; then
            move_tetromino -1 0
            changed=1
          fi
        ;;
        e|d|'[C') # Right.
          if ! boundary_condition 1 0 && ! colission_detected 1 0; then
            move_tetromino 1 0
            changed=1
          fi
        ;;
        o|s|'[B') # Down.
          if ! boundary_condition 0 1 && ! colission_detected 0 1; then
            move_tetromino 0 1
            changed=1
          fi
        ;;
        ' ') # Drop.
          while ! boundary_condition 0 1 && ! colission_detected 0 1; do
            move_tetromino 0 1
            changed=1
          done
        ;;
        ,|w|'[A') # Up.
          if rotate; then
            changed=1
          fi
        ;;
      esac
    fi
  fi

  if [[ "${status}" == "play" ]]; then
    declare -i drop_speed=$((15 - completed_lines / 3))
    if ((game_ticks >= drop_ticks + $((drop_speed < 1 ? 1 : drop_speed)))); then
      changed=1
      drop_ticks=${game_ticks}
      if ! boundary_condition 0 1 && ! colission_detected 0 1; then
        move_tetromino 0 1
      else
        clear_board
        current_orientation=0
        current_piece=${next_piece}
        next_piece=$((RANDOM % NUM_TETROMINOS))
        if ! add_board_piece ${current_piece}; then
          gameover
        fi
      fi
    fi

    if [ -n "${changed}" ]; then
      draw_screen
    fi
    declare -i now_ms=$(time_ms)
    if ((now_ms - last_frame_ms > FRAME_RATE_MS)); then
      ((game_ticks++))
      last_frame_ms=${now_ms}
    fi
    sleep 0.00$((now_ms - last_frame_ms))
  else
    sleep 0.1
  fi
done
