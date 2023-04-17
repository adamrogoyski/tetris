#!/usr/bin/awk -f
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.
#
# Shells out for:
# - obtaining the time in milliseconds
# - polling the keyboard
# - reading the keyboard
# - getting the screen width
# - sleeping

BEGIN {
  srand()
  system("stty -echo raw")
  print "\x1bc\r"
  FRAME_RATE_MS = 16
  BLUE = "\x1b[104m";   COLORS[0] = BLUE
  CYAN = "\x1b[46m";    COLORS[1] = CYAN
  GREEN = "\x1b[102m";  COLORS[2] = GREEN
  RED = "\x1b[101m";    COLORS[3] = RED
  PURPLE = "\x1b[45m";  COLORS[4] = PURPLE
  RED = "\x1b[41m";     COLORS[5] = RED
  YELLOW = "\x1b[103m"; COLORS[6] = YELLOW
  BLACK = "\x1b[40m";   COLORS[7] = BLACK
  DARK_GRAY = "\x1b[100m"
  LIGHT_GRAY = "\x1b[47m"
  WALL = DARK_GRAY " " LIGHT_GRAY " "
  state = "PLAY"
  WIDTH = 10
  HEIGHT = 20
  completed_lines = ARGV[1] > 0 ? ARGV[1] : 0
  completed_lines = completed_lines > 45 ? 45 : completed_lines
  for (x = 0; x < WIDTH; x++) {
    for (y = 0; y < HEIGHT; y++) {
      xy = x "," y
      board[xy] = BLACK
    }
  }
  current_piece = int(7 * rand())
  next_piece = int(7 * rand())
  current_orientation[0] = 0
  COLUMNS = get_screen_width()
  current_coords[0] = current_coords[1] = current_coords[2] = current_coords[3] = ""
  add_board_piece(board, current_coords, current_piece, WIDTH, COLORS)
  game_ticks = drop_ticks = 0
  last_frame_ms = time_ms()
  draw(board, next_piece, completed_lines, logosml, WALL, COLUMNS, WIDTH, COLORS)
  while (state != "GAMEOVER") {
    if (poll_keyboard()) {
      c = getchar()
      if (c == "p") {
        state = state == "PAUSE" ? "PLAY" : "PAUSE"
      } else if (c == "q") {
        state = "GAMEOVER"
      } else if (c == "\x1b") {
        if (!poll_keyboard()) {
          state = "GAMEOVER"
          continue
        }
      }

      if (state == "PLAY") {
        if (c == " ") {
          while (!boundary_condition(0, 1, current_coords, WIDTH, HEIGHT) &&
                !colission_detected(0, 1, board, current_coords, WIDTH, HEIGHT, BLACK)) {
            move_tetromino(0, 1, board, current_piece, current_coords, COLORS)
            changed = 1
          }
        }
        else if (c == "\x1b") {
          if (!poll_keyboard()) {
            state = "GAMEOVER"
            continue
          }
          c1 = getchar()
          if (poll_keyboard()) {
            c2 = getchar()
            if (c1 c2 == "[A") {
            changed = rotate(board, current_piece, current_orientation, current_coords, COLORS)
            }
            else if (c1 c2 == "[D") {
              if (!boundary_condition(-1, 0, current_coords, WIDTH, HEIGHT) &&
                  !colission_detected(-1, 0, board, current_coords, WIDTH, HEIGHT, BLACK)) {
                move_tetromino(-1, 0, board, current_piece, current_coords, COLORS)
                changed = 1
              }
            }
            else if (c1 c2 == "[C") {
              if (!boundary_condition(1, 0, current_coords, WIDTH, HEIGHT) &&
                  !colission_detected(1, 0, board, current_coords, WIDTH, HEIGHT, BLACK)) {
                move_tetromino(1, 0, board, current_piece, current_coords, COLORS)
                changed = 1
              }
            }
            else if (c1 c2 == "[B") {
              if (!boundary_condition(0, 1, current_coords, WIDTH, HEIGHT) &&
                  !colission_detected(0, 1, board, current_coords, WIDTH, HEIGHT, BLACK)) {
                move_tetromino(0, 1, board, current_piece, current_coords, COLORS)
                changed = 1
              }
            }
          }
        }
      }
    }

    if (state == "PLAY") {
      drop_speed = 15 - (completed_lines / 3)
      if (game_ticks >= drop_ticks + (drop_speed < 1 ? 1 : drop_speed)) {
        changed = 1
        drop_ticks = game_ticks
        if (!boundary_condition(0, 1, current_coords, WIDTH, HEIGHT) &&
            !colission_detected(0, 1, board, current_coords, WIDTH, HEIGHT, BLACK)) {
          move_tetromino(0, 1, board, current_piece, current_coords, COLORS)
        } else {
          completed_lines += clear_board(board, WIDTH, HEIGHT, COLORS[7])
          current_orientation[0] = 0
          current_piece = next_piece
          next_piece = int(7 * rand())
          if (add_board_piece(board, current_coords, current_piece, WIDTH, COLORS)) {
            gameover(COLORS[7])
          }
        }
      }
    }

    if (changed) {
      draw(board, next_piece, completed_lines, logosml, WALL, COLUMNS, WIDTH, COLORS)
    }
    now_ms = time_ms()
    if (now_ms - last_frame_ms > FRAME_RATE_MS) {
      game_ticks++
      last_frame_ms = now_ms
    }
    s = now_ms - last_frame_ms
   #   print "\r  rsleep = " s, now_ms, last_frame_ms
    if (s > 0) {
      fsleep("0.00" s)
    }
  }
  exit(0)
}

function set_coords(board, coords, color) {
  for (i in coords) {
    xy = coords[i]
    board[xy] = color
  }
}

function rotate(board, current_piece, current_orientation, current_coords, COLORS) {
  # Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
  # Each rotation is a set of 4 rotations -- one for each orientation of a tetromino.
  # For each rotation, there is an array of 4 (int x, int y) coordinate diffs for
  # each block of the tetromino. The coordinate diffs map each block to its new location.
  # The associative-array index is (piece,orientation) and maps to (dx,dy) for each block
  # of the tetromino.
  # Tetromino 0: Leftward L.
  rotations["0,0"] = "0,2 1,1 0,0 -1,-1"
  rotations["0,1"] = "2,0 1,-1 0,0 -1,1"
  rotations["0,2"] = "0,-2 -1,-1 0,0 1,1"
  rotations["0,3"] = "-2,0 -1,1 0,0 1,-1"
  # Tetromino 1: Rightward Z. Orientation symmetry: 0 = 2 and 1 = 3.
  rotations["1,0"] = "1,0 0,1 -1,0 -2,1"
  rotations["1,1"] = "-1,0 0,-1 1,0 2,-1"
  rotations["1,2"] = "1,0 0,1 -1,0 -2,1"
  rotations["1,3"] = "-1,0 0,-1 1,0 2,-1"
  # Tetromino 2: Long straight. Orientation symmetry: 0 = 2 and 1 = 3.
  rotations["2,0"] = "2,-2 1,-1 0,0 -1,1"
  rotations["2,1"] = "-2,2 -1,1 0,0 1,-1"
  rotations["2,2"] = "2,-2 1,-1 0,0 -1,1"
  rotations["2,3"] = "-2,2 -1,1 0,0 1,-1"
  # Tetromino 3: Bump in middle.
  rotations["3,0"] = "1,1  0,0 -1,1 -1,-1"
  rotations["3,1"] = "1,-1 0,0 1,1 -1,1"
  rotations["3,2"] = "-1,-1 0,0 1,-1 1,1"
  rotations["3,3"] = "-1,1 0,0 -1,-1 1,-1"
  # Tetromino 4: L.
  rotations["4,0"] = "1,1 0,0 -1,-1 -2,0"
  rotations["4,1"] = "1,-1 0,0 -1,1 0,2"
  rotations["4,2"] = "-1,-1 0,0 1,1 2,0"
  rotations["4,3"] = "-1,1 0,0 1,-1 0,-2"
  # Tetromino 5: Z. Orientation symmetry: 0 = 2 and 1 = 3.
  rotations["5,0"] = "1,0 0,1 -1,0 -2,1"
  rotations["5,1"] = "-1,0 0,-1 1,0 2,-1"
  rotations["5,2"] = "1,0 0,1 -1,0 -2,1"
  rotations["5,3"] = "-1,0 0,-1 1,0 2,-1"
  # Tetromino 6: Square. Orientation symmetry: 0 = 1 = 2 = 3.
  rotations["6,0"] = "0,0 0,0 0,0 0,0"
  rotations["6,1"] = "0,0 0,0 0,0 0,0"
  rotations["6,2"] = "0,0 0,0 0,0 0,0"
  rotations["6,3"] = "0,0 0,0 0,0 0,0"

  rots = rotations[current_piece "," current_orientation[0]]
  split(rots, dxdy, " ")
  i= 0
  for (e in dxdy) {
    split(dxdy[e], r, ",")
    split(current_coords[e-1], coords, ",")
    nx = coords[1] + r[1]
    ny = coords[2] + r[2]
    n_coords[i++] = nx "," ny
  }
  set_coords(board, current_coords, COLORS[7])
  for (i = 0; i < 4; i++) {
    split(n_coords[i], coord, ",")
    x = coord[1]
    y = coord[2]
    if ((x < 0) || (x > WIDTH-1) || (y < 0) || (y > HEIGHT-1) || (board[n_coords[i]] != COLORS[7])) {
      set_coords(board, current_coords, COLORS[current_piece])
      return 0
    }
  }
  set_coords(board, n_coords, COLORS[current_piece])
  for (i = 0; i < 4; i++) {
    current_coords[i] = n_coords[i]
  }
  current_orientation[0] = (current_orientation[0] + 1) % 4
  return 1
}

function move_tetromino(dx, dy, board, current_piece, current_coords, COLORS) {
  color = COLORS[current_piece]
  for (xy in current_coords) {
    xy = current_coords[xy]
    board[xy] = COLORS[7]
  }
  i = 0
  for (xy in current_coords) {
    xy = current_coords[xy]
    split(xy, coord, ",")
    nx = coord[1] + dx
    ny = coord[2] + dy
    nxy = nx "," ny
    board[nxy] = color
    new_coords[i++] = nxy
  }
  for (i = 0; i < 4; i++) {
    current_coords[i] = new_coords[i]
  }
}

function boundary_condition(dx, dy, current_coords, WIDTH, HEIGHT) {
  for (i = 0; i < 4; i++) {
    split(current_coords[i], coord, ",")
    nx = coord[1] + dx
    ny = coord[2] + dy
    if ((nx < 0) || (nx >= WIDTH) || (ny < 0) || (ny >= HEIGHT)) {
      return 1
    }
  }
  return 0
}

function colission_detected(dx, dy, board, current_coords, WIDTH, HEIGHT, BLACK) {
  # Create a copy of the board.
  for (x = 0; x < WIDTH; x++) {
    for (y = 0; y < HEIGHT; y++) {
      xy = x "," y
      tboard[xy] = board[xy]
    }
  }
  # Clear the current location of the tetromino.
  for (i in current_coords) {
    c = current_coords[i]
    tboard[c] = BLACK
  }
  # Check if the updated coordinates collide with a non-black block.
  for (i in current_coords) {
    split(current_coords[i], coord, ",")
    nx = coord[1] + dx
    ny = coord[2] + dy
    nxy = nx "," ny
    if (tboard[nxy] != BLACK) {
      return 1
    }
  }
  return 0
}

function starting_position(p) {
  # Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
  starting_positions[0] = "-1,0 -1,1 0,1 1,1" # Leftward L piece.
  starting_positions[1] = "-1,1 0,1 0,0 1,0"  # Rightward Z piece.
  starting_positions[2] = "-2,0 -1,0 0,0 1,0" # Long straight piece.
  starting_positions[3] = "-1,1 0,1 0,0 1,1"  # Bump in middle piece.
  starting_positions[4] = "-1,1 0,1 1,1 1,0"  # L piece.
  starting_positions[5] = "-1,0 0,0 0,1 1,1"  # Z piece.
  starting_positions[6] = "-1,0 -1,1 0,0 0,1" # Square piece.
  return starting_positions[p]
}

function add_board_piece(board, current_coords, current_piece, WIDTH, COLORS) {
  center = WIDTH / 2
  split(starting_position(current_piece), coords, " ")
  for (i=1; i <= 4; i++) {
    split(coords[i], coord, ",")
    x = center + coord[1]
    y = coord[2]
    xy = x "," y
    if (board[xy] != COLORS[7]) {
      return 1
    }
    board[xy] = COLORS[current_piece]
    current_coords[i-1] = xy
  }
  return 0
}

function getchar() {
  cmd = "dd bs=1 count=1 2>/dev/null"
  cmd | getline input
  close(cmd)
  return input
}

function poll_keyboard() {
  return !system("bash -c 'IFS= read -n1 -t0 -r'")
}

function get_screen_width() {
  cmd = "tput cols"
  cmd | getline output
  close(cmd)
  return output
}

function fsleep(t) {
  system("sleep " t)
}

function time_ms() {
  cmd = "bash -c \"echo \\$((\\${EPOCHREALTIME%%.*}\\${EPOCHREALTIME##*.} / 1000))\""
  cmd | getline output
  close(cmd)
  return output
}

# Clear completed (filled) rows.
# Start from the bottom of the board, moving all rows down to fill in a completed row, with
# the completed row cleared and placed at the top.
function clear_board(board, WIDTH, HEIGHT, BLACK) {
  rows_deleted = 0
  for (row = HEIGHT-1; row >= rows_deleted;) {
    has_hole = 0
    for (x = 0; x < WIDTH && !has_hole; x++) {
      if (board[x "," row] == BLACK) {
        has_hole = 1
      }
    }
    if (!has_hole) {
      for (y = row; y > rows_deleted; y--) {
        for (col = 0; col < WIDTH; col++) {
          board[col "," y] = board[col "," (y-1)]
        }
      }
      for (col = 0; col < WIDTH; col++) {
        board[col "," rows_deleted] = BLACK
      }
      rows_deleted++
    } else {
      row--
    }
  }
  return rows_deleted
}

function draw(board, next_piece, completed_lines, logosml, wall, columns, width, COLORS) {
  BLOCK_SIZE="  "
  # Move cursor to top left.
  printf "\x1b[1;0H"
  # Draw the play board.
  for (y = 0; y < HEIGHT; y++) {
    printf "\r"
    for (x = 0; x < WIDTH; x++) {
      xy = x "," y
      printf board[xy] "  "
    }
    # Draw the wall separating the board and status area.
    print wall "\x1b[49m"
  }
  FRED = "\x1b[91m"
  print "\r\n\n" FRED "TETЯIS:\n"
  print "\r  usage: ./tetris [level 1-15]\n"
  print "\r  ESC - Quit."
  print "\r  p   - Pause.\n"
  print "\r  Up - Rotate."
  print "\r  Down - Lower."
  printf "\r  Space - Drop completely."

  # Draw the logo.
  logobig_width = 66
  logobig_height = 8
  logobig[0]="*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT    *RRRRRR    *II     *SSSSS"
  logobig[1]="*TTTTTTTTTT   *EEEEEEE   *TTTTTTTTTT   *RR   RR    *II   *SSSS"
  logobig[2]="    *TT       *E             *TT      *RR    RR    *II   *SS"
  logobig[3]="    *TT       *EEEEEEE       *TT       *RR   RR    *II     *SSSS"
  logobig[4]="    *TT       *EEEEEEE       *TT         *RRRRR    *II        *SSS"
  logobig[5]="    *TT       *E             *TT       *RR   RR    *II         *SS"
  logobig[6]="    *TT       *EEEEEEE       *TT      *RR    RR    *II      *SSSS"
  logobig[7]="    *TT       *EEEEEEE       *TT     *RR     RR    *II    *SSSS "

  logosml_width = 42
  logosml_height = 5
  logosml[0]="*TTTTTT *EEEEE *TTTTTT   *RRRR  *II   *SSS"
  logosml[1]="  *TT   *E       *TT   *RR  RR  *II  *S"
  logosml[2]="  *TT   *EEEEE   *TT      *RRR  *II   *SSS"
  logosml[3]="  *TT   *E       *TT    *R  RR  *II     *S"
  logosml[4]="  *TT   *EEEEE   *TT  *RR   RR  *II  *SSS"
  status_left = width*2 + 4
  status_width = columns - width*2 - 4
  status_height = 3
  if (status_width >= logobig_width) {
    for (i = 0; i < logobig_height; i++) {
      print "\x1b[" i+1 ";" status_left "H" FRED logobig[i]
    }
    status_height = logobig_height + 2
  }
  else if (status_width >= logosml_width) {
    for (i = 0; i < logosml_height; i++) {
      print "\x1b[" i+1 ";" status_left "H" FRED logosml[i]
    }
    status_height = logosml_height + 2
  }
  else {
    print "\x1b[1;" status_left "H" FRED " TETRIS"
  }

  # Draw status elements.
  print "\x1b[" status_height ";" status_left "H" FRED "Lines: " completed_lines
  print "\x1b[" (status_height+2) ";" status_left "H" FRED "Level: " int(completed_lines / 3)

  # Clear out previous next tetromino.
  print "\x1b[" (status_height+5) ";" (status_left+1) "H" BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE
  print "\x1b[" (status_height+6) ";" (status_left+1) "H" BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE BLOCK_SIZE

  # Draw next tetromino.
  color = COLORS[next_piece]

  split(starting_position(next_piece), coords, " ")
  for (i=1; i <= 4; i++) {
    split(coords[i], coord, ",")
    print "\x1b[" (status_height + 5 + coord[2]) ";" (status_left + 5 + coord[1]*2) "H" color "  "
  }
  print "\x1b[" (HEIGHT+13) ";0H\x1b[39m\x1b[49m"
}

function gameover(BLACK) {
  BLOCK_SIZE="  "
  # Clear out a rectangular box.
  for (i = 0; i <= WIDTH+8; i++) {
    line = line BLOCK_SIZE
  }
  FRED = "\x1b[91m"
  print "\x1b[" (HEIGHT/2-1) ";0H" BLACK line
  print "\x1b[" (HEIGHT/2)   ";0H" BLACK line
  print "\x1b[" (HEIGHT/2+1) ";0H" BLACK line
  print "\x1b[" (HEIGHT/2)   ";0H" FRED " The only winning move is not to play"
  print "\x1b[" (HEIGHT+13)  ";0H\x1b[39m\x1b[49m"

  while (1) {
    if (poll_keyboard()) {
      c = getchar()
      if (c == "q") {
        exit(0)
      }
      else if (c == "\x1b") {
        if (!poll_keyboard()) {
          exit(0)
        }
        getchar()
      }
    }
    fsleep(0.1)
  }
}

END {
  system("stty echo -raw")
  print
}
