#!/bin/csh
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.
set esc = `/bin/echo -ne "\e"`
set cr = `/bin/echo -ne "\r"`
set nl = `/bin/echo -ne "\n"`
set DOLLAR = '$'
echo -e "${esc}c"

set completed_lines = 0
if ( "${#argv}" >= 1 ) then
  @ completed_lines = ${argv[1]} * 3
  if ( "${completed_lines}" < 0 ) then
    set completed_lines = 0
  else if ( "${completed_lines}" > 45 ) then
    set completed_lines = 45
  endif
  # Clear out command-line args so args can be used with aliases.
  set argv = ()
endif

onintr QUIT
set input_lines = 0
set exc = '!'
set return = 0

set WIDTH = 10
set HEIGHT = 20
set COLUMNS = `tput cols`
set BLOCK_SIZE = "  "
set NUM_TETROMINOS = 7
@ FRAME_RATE_MS = 1000 / 60
set FRED = "${esc}[91m"
set BLACK = "${esc}[40m"
set BLUE = "${esc}[104m"
set CYAN = "${esc}[46m"
set GREEN = "${esc}[102m"
set LRED = "${esc}[101m"
set PURPLE = "${esc}[45m"
set RED = "${esc}[41m"
set YELLOW = "${esc}[103m"
set DARK_GRAY = "${esc}[100m"
set LIGHT_GRAY = "${esc}[47m "
set COLORS = ("${BLUE}" "${CYAN}" "${GREEN}" "${LRED}" "${PURPLE}" "${RED}" "${YELLOW}")

set x = 1
while ( ${x} <= ${WIDTH} )
  set y = 1
  while ( ${y} <= ${HEIGHT} )
      set board_${x}_${y} = "${BLACK}"
      @ y++
  end
  @ x++
end

alias random 'expr `dd if=/dev/urandom bs=1 count=1 | od -Anone -tu1` % ${1}'

set current_piece = `random ${NUM_TETROMINOS}`; @ current_piece++
set next_piece = `random ${NUM_TETROMINOS}`; @ next_piece++
set current_orientation = 0

set starting_positions_1 = ('-1,0' '-1,1' '0,1' '1,1') # Leftward L piece.
set starting_positions_2 = ('-1,1'  '0,1' '0,0' '1,0') # Rightward Z piece.
set starting_positions_3 = ('-2,0' '-1,0' '0,0' '1,0') # Long straight piece.
set starting_positions_4 = ('-1,1'  '0,1' '0,0' '1,1') # Bump in middle piece.
set starting_positions_5 = ('-1,1'  '0,1' '1,1' '1,0') # L piece.
set starting_positions_6 = ('-1,0'  '0,0' '0,1' '1,1') # Z piece.
set starting_positions_7 = ('-1,0' '-1,1' '0,0' '0,1') # Square piece.

# Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
# Each rotation is a set of 4 rotations -- one for each orientation of a tetromino.
# For each rotation, there is an array of 4 (int x, int y) coordinate diffs for
# each block of the tetromino. The coordinate diffs map each block to its new location.
# The variable suffix is (piece,orientation) and maps to (dx,dy) for each block
# of the tetromino.
# Tetromino 0: Leftward L.
set rotations_1_0 = ( '0,2'   '1,1'  '0,0' '-1,-1')
set rotations_1_1 = ( '2,0'   '1,-1' '0,0' '-1,1')
set rotations_1_2 = ( '0,-2' '-1,-1' '0,0'  '1,1')
set rotations_1_3 = ( '-2,0' '-1,1' '0,0'  '1,-1')
# Tetromino 1: Rightward Z. Orientation symmetry: 0==2 and 1==3.
set rotations_2_0 = ( '1,0' '0,1' '-1,0' '-2,1')
set rotations_2_1 = ('-1,0' '0,-1' '1,0' ' 2,-1')
set rotations_2_2 = ( '1,0' '0,1' '-1,0' '-2,1')
set rotations_2_3 = ('-1,0' '0,-1' '1,0'  '2,-1')
# Tetromino 2: Long straight. Orientation symmetry: 0==2 and 1==3.
set rotations_3_0 = ( '2,-2' '1,-1' '0,0' '-1,1')
set rotations_3_1 = ('-2,2' '-1,1'  '0,0'  '1,-1')
set rotations_3_2 = ( '2,-2' '1,-1' '0,0' '-1,1')
set rotations_3_3 = ('-2,2' '-1,1'  '0,0'  '1,-1')
# Tetromino 3: Bump in middle.
set rotations_4_0 = ( '1,1'  '0,0' '-1,1'  '-1,-1')
set rotations_4_1 = ( '1,-1' '0,0'  '1,1'  '-1,1')
set rotations_4_2 = ('-1,-1' '0,0'  '1,-1'  '1,1')
set rotations_4_3 = ('-1,1'  '0,0' '-1,-1'  '1,-1')
# Tetromino 4: L.
set rotations_5_0 = ( '1,1'  '0,0' '-1,-1' '-2,0')
set rotations_5_1 = ( '1,-1' '0,0' '-1,1'   '0,2')
set rotations_5_2 = ('-1,-1' '0,0'  '1,1'   '2,0')
set rotations_5_3 = ('-1,1'  '0,0'  '1,-1'  '0,-2')
# Tetromino 5: Z. Orientation symmetry: 0==2 and 1==3.
set rotations_6_0 = ( '1,0' '0,1' '-1,0' '-2,1')
set rotations_6_1 = ('-1,0' '0,-1' '1,0'  '2,-1')
set rotations_6_2 = ( '1,0' '0,1' '-1,0' '-2,1')
set rotations_6_3 = ('-1,0' '0,-1' '1,0'  '2,-1')
# Tetromino 6: Square. Orientation symmetry: 0==1==2==3.
set rotations_7_0 = ('0,0' '0,0' '0,0' '0,0')
set rotations_7_1 = ('0,0' '0,0' '0,0' '0,0')
set rotations_7_2 = ('0,0' '0,0' '0,0' '0,0')
set rotations_7_3 = ('0,0' '0,0' '0,0' '0,0')

set logobig_width = 66
set logobig_height = 8
set logobig = ('*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT    *RRRRRR    *II     *SSSSS' \
               '*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT   *RR   RR    *II   *SSSS' \
               '    *TT       *E             *TT      *RR    RR    *II   *SS' \
               '    *TT       *EEEEEEE       *TT       *RR   RR    *II     *SSSS' \
               '    *TT       *EEEEEEE       *TT         *RRRRR    *II        *SSS' \
               '    *TT       *E             *TT       *RR   RR    *II         *SS' \
               '    *TT       *EEEEEEE       *TT      *RR    RR    *II      *SSSS' \
               '    *TT       *EEEEEEE       *TT     *RR     RR    *II    *SSSS ')

set logosml_width = 42
set logosml_height = 5
set logosml = ('*TTTTTT *EEEEE *TTTTTT   *RRRR  *II   *SSS' \
               '  *TT   *E       *TT   *RR  RR  *II  *S' \
               '  *TT   *EEEEE   *TT      *RRR  *II   *SSS' \
               '  *TT   *E       *TT    *R  RR  *II     *S' \
               '  *TT   *EEEEE   *TT  *RR   RR  *II  *SSS')

alias getchar ' \
  set input_line_count = `wc -l input | cut -f 1 -d\ ` \
  if ( ${input_line_count} > ${input_lines} ) then \
    @ input_lines++ \
    set input = `sed "${input_lines}${exc}"d input` \
    if ( "${input}" == "${esc}" ) then \
      set input_line_count = `wc -l input | cut -f 1 -d\ ` \
      if ( ${input_line_count} > ${input_lines} ) then \
        @ input_lines++ \
        set input = `sed "${input_lines}${exc}"d input` \
      endif \
      if ( "${input}" == "[" ) then \
        set input_line_count = `wc -l input | cut -f 1 -d\ ` \
        if ( ${input_line_count} > ${input_lines} ) then \
          @ input_lines++ \
          set input = `sed "${input_lines}${exc}"d input` \
        endif \
        switch ( "${input}" ) \
          case "D": \
            set input = "LEFT" \
            breaksw \
          case "C": \
            set input = "RIGHT" \
            breaksw \
          case "B": \
            set input = "DOWN" \
            breaksw \
          case "A": \
            set input = "UP" \
            breaksw \
          default: \
            breaksw \
        endsw \
      endif \
    endif \
    @ return = 0 \
  else \
    @ return = 1 \
  endif'

set collision_detected = 0
alias collisiondetected ' \
  set dx = "${arg[1]}" \
  set dy = "${arg[2]}" \
  set color = "${COLORS[${current_piece}]}" \
  set collision_detected = 0 \
  # Clear the board where the piece currently is to not detect self collision. \
  foreach coord ( ${current_coords[*]} ) \
    set x = `echo ${coord} | cut -f1 -d,` \
    set y = `echo ${coord} | cut -f2 -d,` \
    set board_${x}_${y} = "${BLACK}" \
  end \
  foreach coord ( ${current_coords[*]} ) \
    set x = `echo ${coord} | cut -f1 -d,` \
    set y = `echo ${coord} | cut -f2 -d,` \
    # Collision is hitting the left wall, right wall, bottom, or a non-black block. \
    # Since this collision detection is only for movement, check the top (y < 0) is not needed. \
    @ new_x = ${x} + ${dx} \
    @ new_y = ${y} + ${dy} \
    if ( ${new_x} < 1 || ${new_x} > ${WIDTH} || ${new_y} > ${HEIGHT} ) then \
      @ collision_detected = 1 \
      break \
    endif \
    set t = "${DOLLAR}{board_${new_x}_${new_y}}" \
    if ( `eval echo \"${t}\"` != "${BLACK}" ) then \
      @ collision_detected = 1 \
      break \
    endif \
  end \
  # Restore the current piece. \
  foreach coord ( ${current_coords[*]} ) \
    set x = `echo ${coord} | cut -f1 -d,` \
    set y = `echo ${coord} | cut -f2 -d,` \
    set board_${x}_${y} = "${color}" \
  end'

set updated = 0
set rotated = 0
set game_status = "play"
set game_ticks = 0
set drop_ticks = 0
set last_frame_ms = `date +%s.%N | cut -c6-14 | tr -d .`

set return_goto = "INITIAL_DRAW"
goto ADD_BOARD_PIECE

INITIAL_DRAW:
  set return_goto = "GAME_LOOP"
  goto DRAW

ROTATED:
  set return_goto = "GAME_LOOP"
  if ( "${rotated}" == "0" ) then
    set updated = 1
  endif
GAME_LOOP:
  set return_goto = "GAME_LOOP"
  while (1)
    getchar
    if ( ${return} == 0 ) then
      if ( "${game_status}" == "pause" ) then
        switch ( "${input}" )
          case "${esc}":
          case "q":
            exit 0
          case "p":
            set game_status = "play"
            breaksw
        default:
          breaksw
        endsw
      else
        switch ( "${input}" )
          case "${esc}":
          case "q":
            exit 0
          case "p":
            set game_status = "pause"
            breaksw
          case "UP":
            set return_goto = "ROTATED"
            goto ROTATE
            breaksw
          case "LEFT":
            set arg = (-1 0)
            collisiondetected
            if ( "${collision_detected}" == "0" ) then
              set updated = 1
              goto MOVE_TETROMINO
            endif
            breaksw
          case "RIGHT":
            set arg = (1 0)
            collisiondetected
            if ( "${collision_detected}" == "0" ) then
              set updated = 1
              goto MOVE_TETROMINO
            endif
            breaksw
          case "DOWN":
            set arg = (0 1)
            collisiondetected
            if ( "${collision_detected}" == "0" ) then
              set updated = 1
              goto MOVE_TETROMINO
            endif
            breaksw
          case " ":
          case "${nl}":
            set arg = (0 1)
            set return_goto = "ALL_THE_WAY_DOWN"
           ALL_THE_WAY_DOWN:
            collisiondetected
            if ( "${collision_detected}" == "0" ) then
              set updated = 1
              goto MOVE_TETROMINO
            endif
            set return_goto = "GAME_LOOP"
            breaksw
          default:
            breaksw
        endsw
      endif
    endif

    if ( "${game_status}" == "play" ) then
      @ drop_speed = 15 - ${completed_lines} / 3
      if ( ${drop_speed} < 1 ) @ drop_speed = 1
      if ( ${game_ticks} >= ${drop_ticks} + ${drop_speed}) then
        @ changed = 1
        @ drop_ticks = ${game_ticks}
        set arg = (0 1)
        collisiondetected
        if ( "${collision_detected}" == "0" ) then
          set updated = 1
          goto MOVE_TETROMINO
        else
          # Clear completed (filled) rows.
          # Start from the bottom of the board, moving all rows down to fill in a completed row, with
          # the completed row cleared and placed at the top.
          @ rows_deleted = 0
          @ row = ${HEIGHT}
          while ( ${row} > ${rows_deleted} )
            @ has_hole = 0
            @ x = 1
            while ( ${x} <= ${WIDTH} && ${has_hole} == 0 )
              set t = '${board_'"${x}_${row}"'}'
              if ( `eval echo -n \"${t}\"` == "${BLACK}" ) then
                @ has_hole = 1
              endif
              @ x++
            end
            if ( ${has_hole} == 0 ) then
              @ y = ${row}
              while ( ${y} > ${rows_deleted} + 1 )
                @ col = 1
                while ( ${col} <= ${WIDTH} )
                  @ prow = ${y} - 1
                  set t = '${board_'"${col}_${prow}"'}'
                  set board_${col}_${y} = `eval echo -n \"${t}\"`
                  @ col++
                end
                @ y--
              end
              @ col = 1
              while ( ${col} <= ${WIDTH} )
               set board_${col}_${rows_deleted} = "${BLACK}"
                @ col++
              end
              @ rows_deleted++
            else
              @ row--
            endif
          end
          @ completed_lines += ${rows_deleted}
          # End line clearing.

          @ current_orientation = 0
          @ current_piece = ${next_piece}
          set next_piece = `random ${NUM_TETROMINOS}`; @ next_piece++
          goto ADD_BOARD_PIECE
        endif
      endif
      @ now_ms = `date +%s.%N | cut -c6-14 | tr -d .`
      @ frame_delta = ${now_ms} - ${last_frame_ms}
      if ( ${frame_delta} > ${FRAME_RATE_MS} ) then
        @ game_ticks++
        @ last_frame_ms = ${now_ms}
      endif
    else
      sleep 0.01
    endif

UPDATED:
    if ( ${updated} == 1 ) then
      set updated = 0
      goto DRAW
    endif
    sleep 0.001
  end

QUIT:
  set line = ""
  @ i = 0
  while ( ${i} <= ${WIDTH} + 8 )
    set line = "${line}${BLOCK_SIZE}"
    @ i++
  end
  @ HEIGHT_MB = ${HEIGHT} / 2 - 1
  @ HEIGHT_MID = ${HEIGHT} / 2
  @ HEIGHT_MA = ${HEIGHT} / 2 + 1
  @ HEIGHT_13 = ${HEIGHT} + 13
  echo -n "${esc}[${HEIGHT_MB};0H${BLACK}${line}"
  echo -n "${esc}[${HEIGHT_MID};0H${BLACK}${line}"
  echo -n "${esc}[${HEIGHT_MA};0H${BLACK}${line}"
  echo -n "${esc}[${HEIGHT_MID};0H${FRED} The only winning move is not to play"
  echo -n "${esc}[${HEIGHT_13};0H${esc}[39m${esc}[49m"
  exit 0

DRAW:
  echo -n "${esc}[1;0H"
  # Draw the play board.
  @ y = 1
  while ( ${y} <= ${HEIGHT} )
    @ x = 1
    while ( ${x} <= ${WIDTH} )
      set t = '${board_'"${x}_${y}"'}'
      eval echo -n \"${t}\"
      echo -n "${BLOCK_SIZE}"
      @ x++
      unset t
    end
    # Draw the wall separating the board and status area.
    echo -n "${DARK_GRAY} ${LIGHT_GRAY}"
    echo "${esc}[49m${cr}"
    @ y++
  end
  echo "${FRED}\
\
TETЯIS:${cr}\
${cr}\
  usage: ./tetris [level 1-15]${cr}\
${cr}\
  ESC - Quit.${cr}\
  p   - Pause.${cr}\
${cr}\
  Up - Rotate.${cr}\
  Down - Lower.${cr}\
  Space - Drop completely.${cr}"

  # Draw the logo.
  @ status_left = ${WIDTH} * 2 + 4
  @ status_width = ${COLUMNS} - ${WIDTH} * 2 - 4
  set status_height = 3
  if ( ${status_width} >= ${logobig_width} ) then
    @ i = 0
    while ( ${i} < ${logobig_height} )
      @ i2 = ${i} + 1
      echo -n "${esc}[${i2};${status_left}H${FRED}${logobig[${i2}]}"
      @ i++
    end
    @ status_height = ${logobig_height} + 2
  else if ( ${status_width} >= ${logosml_width} ) then
    @ i = 0
    while ( ${i} < ${logosml_height} )
      @ i2 = ${i} + 1
      echo -n "${esc}[${i2};${status_left}H${FRED}${logosml[${i2}]}"
      @ i++
    end
    @ status_height = ${logosml_height} + 2
  else
    echo -n "${esc}[1;${status_left}H${FRED} TETRIS"
  endif

  # Draw status elements.
  @ s2 = ${status_height} + 2
  @ level = ${completed_lines} / 3
  echo -n "${esc}[${status_height};${status_left}H${FRED} Lines: ${completed_lines}"
  echo -n "${esc}[${s2};${status_left}H${FRED} Level: ${level}"

  # Clear out previous next tetromino.
  @ s5 = ${status_height} + 5
  @ s6 = ${status_height} + 6
  @ sl1 = ${status_left} + 1
  echo -n "${esc}[${s5};${sl1}H${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}"
  echo -n "${esc}[${s6};${sl1}H${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}${BLOCK_SIZE}"

  # Draw next tetromino.
  set color = "${COLORS[${next_piece}]}"
  set tpos = '${starting_positions_'"${next_piece}"'}'
  foreach coord ( `eval echo \"${tpos}\"` )
    set x = `echo ${coord} | cut -f1 -d,`
    set y = `echo ${coord} | cut -f2 -d,`
    @ s5y = ${status_height} + 5 + ${y}
    @ s5x2 = ${status_left} + 5 + ${x} * 2
    echo -n "${esc}[${s5y};${s5x2}H${color}  "
  end
  @ HEIGHT_13 = ${HEIGHT} + 13
  echo -n "${esc}[${HEIGHT_13};0H${esc}[39m${esc}[49m"

  goto "${return_goto}"

ADD_BOARD_PIECE:
  set color = "${COLORS[${current_piece}]}"
  @ center = ${WIDTH} / 2
  set current_coords = ()
  set tpos = '${starting_positions_'"${current_piece}"'}'
  foreach coord ( `eval echo \"${tpos}\"` )
    set x = `echo ${coord} | cut -f1 -d,`
    set y = `echo ${coord} | cut -f2 -d,`
    @ x_ = ${center} + ${x}
    @ y_ = 1 + ${y}
    set t = '${board_'"${x_}_${y_}"'}'
    if ( `eval echo -n \"${t}\"` != "${BLACK}" ) then
      goto QUIT
    endif
    set board_${x_}_${y_} = "${color}"
    set current_coords = (${current_coords} "${x_},${y_}")
  end
  goto "${return_goto}"

MOVE_TETROMINO:
  set dx = "${arg[1]}"
  set dy = "${arg[2]}"
  set color = "${COLORS[${current_piece}]}"
  set coord = ()
  foreach coord ( ${current_coords[*]} )
    set x = `echo ${coord} | cut -f1 -d,`
    set y = `echo ${coord} | cut -f2 -d,`
    set board_${x}_${y} = "${BLACK}"
  end
  set new_coords = ()
  foreach coord ( ${current_coords[*]} )
    set x = `echo ${coord} | cut -f1 -d,`
    set y = `echo ${coord} | cut -f2 -d,`
    @ nx = ${x} + ${dx}
    @ ny = ${y} + ${dy}
    set board_${nx}_${ny} = "${color}"
    set new_coords = (${new_coords} "${nx},${ny}")
  end
  set current_coords = (${new_coords[*]})
  goto "${return_goto}"

ROTATE:
  @ rotated = 0
  set new_coords = ()
  set i = 1
  set tpos = '${rotations_'"${current_piece}_${current_orientation}"'}'
  set color = "${COLORS[${current_piece}]}"
  foreach dxdy ( `eval echo \"${tpos}\"` )
    set dx = `echo ${dxdy} | cut -f1 -d,`
    set dy = `echo ${dxdy} | cut -f2 -d,`
    set x = `echo ${current_coords[${i}]} | cut -f1 -d,`
    set y = `echo ${current_coords[${i}]} | cut -f2 -d,`
    @ nx = ${x} + ${dx}
    @ ny = ${y} + ${dy}
    set xy = "${nx},${ny}"
    set new_coords = (${new_coords} "${xy}")
    @ i++
  end
  foreach coord ( ${current_coords[*]} )
    set x = `echo ${coord} | cut -f1 -d,`
    set y = `echo ${coord} | cut -f2 -d,`
    set board_${x}_${y} = "${BLACK}"
  end
  foreach i ( 1 2 3 4 )
    set x = `echo ${new_coords[${i}]} | cut -f1 -d,`
    set y = `echo ${new_coords[${i}]} | cut -f2 -d,`
    set xy = "${x},${y}"
    set t = '${board_'"${x}_${y}"'}'
    # It is an error to access an undefined variable even with short-circuiting ||, so don't access board_${x}_${y}
    # if out of range.
    if ( ${x} < 1 || ${x} > ${WIDTH} || ${y} < 1 || ${y} > ${HEIGHT} ) then
      @ rotated = 1
      foreach coord ( ${current_coords[*]} )
        set x = `echo ${coord} | cut -f1 -d,`
        set y = `echo ${coord} | cut -f2 -d,`
        set board_${x}_${y} = "${color}"
      end
    endif
    if ( "${rotated}" == 0) then
      if ( `eval echo \"${t}\"` != "${BLACK}" ) then
        @ rotated = 1
        foreach coord ( ${current_coords[*]} )
          set x = `echo ${coord} | cut -f1 -d,`
          set y = `echo ${coord} | cut -f2 -d,`
          set board_${x}_${y} = "${color}"
        end
      endif
    endif
  end
  if ( "${rotated}" == 0 ) then
    foreach coord ( ${new_coords[*]} )
      set x = `echo ${coord} | cut -f1 -d,`
      set y = `echo ${coord} | cut -f2 -d,`
      set board_${x}_${y} = "${color}"
    end
    set current_coords = (${new_coords[*]})
    @ current_orientation = (${current_orientation} + 1) % 4
  endif
  goto "${return_goto}"
