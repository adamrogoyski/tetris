#!/usr/bin/wish
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.

package require sound
snack::sound sound_bwv814menuet; sound_bwv814menuet read "sound/bwv814menuet.wav"
snack::sound sound_korobeiniki;  sound_korobeiniki  read "sound/korobeiniki.wav"
snack::sound sound_russiansong;  sound_russiansong  read "sound/russiansong.wav"
snack::sound sound_gameover;     sound_gameover     read "sound/gameover.wav"
set current_sound 1

proc stop_music {sound} {
  switch $sound {
    0 { sound_bwv814menuet stop }
    1 { sound_korobeiniki  stop }
    2 { sound_russiansong  stop }
  }
}

proc play_music {sound} {
  global current_sound
  switch $sound {
    0 { sound_bwv814menuet play -blocking 0 -command {play_music 0} }
    1 { sound_korobeiniki  play -blocking 0 -command {play_music 1} }
    2 { sound_russiansong  play -blocking 0 -command {play_music 2} }
    3 { sound_gameover     play -blocking 0 }
  }
}

play_music $current_sound

wm protocol . WM_DELETE_WINDOW {
  stop_music $current_sound
  exit
}

set WIDTH 10
set HEIGHT 20
set SCALE_FACTOR 3
set BLOCK_SIZE [expr {$SCALE_FACTOR * 32}]
set ::fontsize [expr {6 + 6*$SCALE_FACTOR}]
set WIDTH_PX [expr $WIDTH * $BLOCK_SIZE + 50 + 6*$BLOCK_SIZE]
set HEIGHT_PX [expr $HEIGHT * $BLOCK_SIZE]
set NUM_TETROMINOS 7
set state "PLAY"
set MS_PER_FRAME [expr {int(1000 / 60)}]
set current_piece [expr {int(rand()*7)}]
set next_piece [expr {int(rand()*7)}]
set current_orientation 0
set completed_lines 0
if {$::argc > 0} {
  set completed_lines [expr {max(0, min(45, 3*[lindex $::argv 0]))}]
}

set block_black  [image create photo]; $block_black  read "graphics/block_black.png";  set blocks(0) $block_black
set block_blue   [image create photo]; $block_blue   read "graphics/block_blue.png";   set blocks(1) $block_blue
set block_cyan   [image create photo]; $block_cyan   read "graphics/block_cyan.png";   set blocks(2) $block_cyan
set block_green  [image create photo]; $block_green  read "graphics/block_green.png";  set blocks(3) $block_green
set block_orange [image create photo]; $block_orange read "graphics/block_orange.png"; set blocks(4) $block_orange
set block_purple [image create photo]; $block_purple read "graphics/block_purple.png"; set blocks(5) $block_purple
set block_red    [image create photo]; $block_red    read "graphics/block_red.png";    set blocks(6) $block_red
set block_yellow [image create photo]; $block_yellow read "graphics/block_yellow.png"; set blocks(7) $block_yellow
set wall         [image create photo]; $wall         read "graphics/wall.png"
set logo         [image create photo]; $logo         read "graphics/logo.png"
$block_black   copy $block_black  -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_blue    copy $block_blue   -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_cyan    copy $block_cyan   -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_green   copy $block_green  -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_orange  copy $block_orange -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_purple  copy $block_purple -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_red     copy $block_red    -zoom $SCALE_FACTOR $SCALE_FACTOR
$block_yellow  copy $block_yellow -zoom $SCALE_FACTOR $SCALE_FACTOR
$wall copy $wall -zoom 1 $SCALE_FACTOR
$logo copy $logo -zoom $SCALE_FACTOR [expr {$SCALE_FACTOR*2}]

for {set y 0} {$y < $HEIGHT} {incr y} {
  for {set x 0} {$x < $WIDTH} {incr x} {
    set board($y,$x) 0
  }
}

# Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
# Leftward L Piece:
set starting_positions(0,0,0) -1
set starting_positions(0,0,1) 0
set starting_positions(0,1,0) -1
set starting_positions(0,1,1) 1
set starting_positions(0,2,0) 0
set starting_positions(0,2,1) 1
set starting_positions(0,3,0) 1
set starting_positions(0,3,1) 1
# Rightward Z Piece.
set starting_positions(1,0,0) -1
set starting_positions(1,0,1) 1
set starting_positions(1,1,0) 0
set starting_positions(1,1,1) 1
set starting_positions(1,2,0) 0
set starting_positions(1,2,1) 0
set starting_positions(1,3,0) 1
set starting_positions(1,3,1) 0
# Long straight piece.
set starting_positions(2,0,0) -2
set starting_positions(2,0,1) 0
set starting_positions(2,1,0) -1
set starting_positions(2,1,1) 0
set starting_positions(2,2,0) 0
set starting_positions(2,2,1) 0
set starting_positions(2,3,0) 1
set starting_positions(2,3,1) 0
# Bump in middle piece.
set starting_positions(3,0,0) -1
set starting_positions(3,0,1) 1
set starting_positions(3,1,0) 0
set starting_positions(3,1,1) 1
set starting_positions(3,2,0) 0
set starting_positions(3,2,1) 0
set starting_positions(3,3,0) 1
set starting_positions(3,3,1) 1
# L piece.
set starting_positions(4,0,0) -1
set starting_positions(4,0,1) 1
set starting_positions(4,1,0) 0
set starting_positions(4,1,1) 1
set starting_positions(4,2,0) 1
set starting_positions(4,2,1) 1
set starting_positions(4,3,0) 1
set starting_positions(4,3,1) 0
# Z piece.
set starting_positions(5,0,0) -1
set starting_positions(5,0,1) 0
set starting_positions(5,1,0) 0
set starting_positions(5,1,1) 0
set starting_positions(5,2,0) 0
set starting_positions(5,2,1) 1
set starting_positions(5,3,0) 1
set starting_positions(5,3,1) 1
# Square piece.
set starting_positions(6,0,0) -1
set starting_positions(6,0,1) 0
set starting_positions(6,1,0) -1
set starting_positions(6,1,1) 1
set starting_positions(6,2,0) 0
set starting_positions(6,2,1) 0
set starting_positions(6,3,0) 0
set starting_positions(6,3,1) 1

# Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
# Each piece has 4 rotations -- one for each orientation of a tetromino.
# For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
# The coordinate diffs map each block to its new location.
# Thus: (block,orientation,component,x|y) to map the 4 components of each block in each orientation.
# Leftward L piece.
set rotations(0,0,0,0) 0
set rotations(0,0,0,1) 2
set rotations(0,0,1,0) 1
set rotations(0,0,1,1) 1
set rotations(0,0,2,0) 0
set rotations(0,0,2,1) 0
set rotations(0,0,3,0) -1
set rotations(0,0,3,1) -1
set rotations(0,1,0,0) 2
set rotations(0,1,0,1) 0
set rotations(0,1,1,0) 1
set rotations(0,1,1,1) -1
set rotations(0,1,2,0) 0
set rotations(0,1,2,1) 0
set rotations(0,1,3,0) -1
set rotations(0,1,3,1) 1
set rotations(0,2,0,0) 0
set rotations(0,2,0,1) -2
set rotations(0,2,1,0) -1
set rotations(0,2,1,1) -1
set rotations(0,2,2,0) 0
set rotations(0,2,2,1) 0
set rotations(0,2,3,0) 1
set rotations(0,2,3,1) 1
set rotations(0,3,0,0) -2
set rotations(0,3,0,1) 0
set rotations(0,3,1,0) -1
set rotations(0,3,1,1) 1
set rotations(0,3,2,0) 0
set rotations(0,3,2,1) 0
set rotations(0,3,3,0) 1
set rotations(0,3,3,1) -1
# Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
set rotations(1,0,0,0) 1
set rotations(1,0,0,1) 0
set rotations(1,0,1,0) 0
set rotations(1,0,1,1) 1
set rotations(1,0,2,0) -1
set rotations(1,0,2,1) 0
set rotations(1,0,3,0) -2
set rotations(1,0,3,1) 1
set rotations(1,1,0,0) -1
set rotations(1,1,0,1) 0
set rotations(1,1,1,0) 0
set rotations(1,1,1,1) -1
set rotations(1,1,2,0) 1
set rotations(1,1,2,1) 0
set rotations(1,1,3,0) 2
set rotations(1,1,3,1) -1
set rotations(1,2,0,0) 1
set rotations(1,2,0,1) 0
set rotations(1,2,1,0) 0
set rotations(1,2,1,1) 1
set rotations(1,2,2,0) -1
set rotations(1,2,2,1) 0
set rotations(1,2,3,0) -2
set rotations(1,2,3,1) 1
set rotations(1,3,0,0) -1
set rotations(1,3,0,1) 0
set rotations(1,3,1,0) 0
set rotations(1,3,1,1) -1
set rotations(1,3,2,0) 1
set rotations(1,3,2,1) 0
set rotations(1,3,3,0) 2
set rotations(1,3,3,1) -1
# Long straight piece. Orientation symmetry: 0==2 and 1==3.
set rotations(2,0,0,0) 2
set rotations(2,0,0,1) -2
set rotations(2,0,1,0) 1
set rotations(2,0,1,1) -1
set rotations(2,0,2,0) 0
set rotations(2,0,2,1) 0
set rotations(2,0,3,0) -1
set rotations(2,0,3,1) 1
set rotations(2,1,0,0) -2
set rotations(2,1,0,1) 2
set rotations(2,1,1,0) -1
set rotations(2,1,1,1) 1
set rotations(2,1,2,0) 0
set rotations(2,1,2,1) 0
set rotations(2,1,3,0) 1
set rotations(2,1,3,1) -1
set rotations(2,2,0,0) 2
set rotations(2,2,0,1) -2
set rotations(2,2,1,0) 1
set rotations(2,2,1,1) -1
set rotations(2,2,2,0) 0
set rotations(2,2,2,1) 0
set rotations(2,2,3,0) -1
set rotations(2,2,3,1) 1
set rotations(2,3,0,0) -2
set rotations(2,3,0,1) 2
set rotations(2,3,1,0) -1
set rotations(2,3,1,1) 1
set rotations(2,3,2,0) 0
set rotations(2,3,2,1) 0
set rotations(2,3,3,0) 1
set rotations(2,3,3,1) -1
# Bump in middle piece.
set rotations(3,0,0,0) 1
set rotations(3,0,0,1) 1
set rotations(3,0,1,0) 0
set rotations(3,0,1,1) 0
set rotations(3,0,2,0) -1
set rotations(3,0,2,1) 1
set rotations(3,0,3,0) -1
set rotations(3,0,3,1) -1
set rotations(3,1,0,0) 1
set rotations(3,1,0,1) -1
set rotations(3,1,1,0) 0
set rotations(3,1,1,1) 0
set rotations(3,1,2,0) 1
set rotations(3,1,2,1) 1
set rotations(3,1,3,0) -1
set rotations(3,1,3,1) 1
set rotations(3,2,0,0) -1
set rotations(3,2,0,1) -1
set rotations(3,2,1,0) 0
set rotations(3,2,1,1) 0
set rotations(3,2,2,0) 1
set rotations(3,2,2,1) -1
set rotations(3,2,3,0) 1
set rotations(3,2,3,1) 1
set rotations(3,3,0,0) -1
set rotations(3,3,0,1) 1
set rotations(3,3,1,0) 0
set rotations(3,3,1,1) 0
set rotations(3,3,2,0) -1
set rotations(3,3,2,1) -1
set rotations(3,3,3,0) 1
set rotations(3,3,3,1) -1
# L Piece.
set rotations(4,0,0,0) 1
set rotations(4,0,0,1) 1
set rotations(4,0,1,0) 0
set rotations(4,0,1,1) 0
set rotations(4,0,2,0) -1
set rotations(4,0,2,1) -1
set rotations(4,0,3,0) -2
set rotations(4,0,3,1) 0
set rotations(4,1,0,0) 1
set rotations(4,1,0,1) -1
set rotations(4,1,1,0) 0
set rotations(4,1,1,1) 0
set rotations(4,1,2,0) -1
set rotations(4,1,2,1) 1
set rotations(4,1,3,0) 0
set rotations(4,1,3,1) 2
set rotations(4,2,0,0) -1
set rotations(4,2,0,1) -1
set rotations(4,2,1,0) 0
set rotations(4,2,1,1) 0
set rotations(4,2,2,0) 1
set rotations(4,2,2,1) 1
set rotations(4,2,3,0) 2
set rotations(4,2,3,1) 0
set rotations(4,3,0,0) -1
set rotations(4,3,0,1) 1
set rotations(4,3,1,0) 0
set rotations(4,3,1,1) 0
set rotations(4,3,2,0) 1
set rotations(4,3,2,1) -1
set rotations(4,3,3,0) 0
set rotations(4,3,3,1) -2
# Z piece. Orientation symmetry: 0==2 and 1==3.
set rotations(5,0,0,0) 1
set rotations(5,0,0,1) 0
set rotations(5,0,1,0) 0
set rotations(5,0,1,1) 1
set rotations(5,0,2,0) -1
set rotations(5,0,2,1) 0
set rotations(5,0,3,0) -2
set rotations(5,0,3,1) 1
set rotations(5,1,0,0) -1
set rotations(5,1,0,1) 0
set rotations(5,1,1,0) 0
set rotations(5,1,1,1) -1
set rotations(5,1,2,0) 1
set rotations(5,1,2,1) 0
set rotations(5,1,3,0) 2
set rotations(5,1,3,1) -1
set rotations(5,2,0,0) 1
set rotations(5,2,0,1) 0
set rotations(5,2,1,0) 0
set rotations(5,2,1,1) 1
set rotations(5,2,2,0) -1
set rotations(5,2,2,1) 0
set rotations(5,2,3,0) -2
set rotations(5,2,3,1) 1
set rotations(5,3,0,0) -1
set rotations(5,3,0,1) 0
set rotations(5,3,1,0) 0
set rotations(5,3,1,1) -1
set rotations(5,3,2,0) 1
set rotations(5,3,2,1) 0
set rotations(5,3,3,0) 2
set rotations(5,3,3,1) -1
# Square piece. Orientation symmetry: 0==1==2==3.
set rotations(6,0,0,0) 0
set rotations(6,0,0,1) 0
set rotations(6,0,1,0) 0
set rotations(6,0,1,1) 0
set rotations(6,0,2,0) 0
set rotations(6,0,2,1) 0
set rotations(6,0,3,0) 0
set rotations(6,0,3,1) 0
set rotations(6,1,0,0) 0
set rotations(6,1,0,1) 0
set rotations(6,1,1,0) 0
set rotations(6,1,1,1) 0
set rotations(6,1,2,0) 0
set rotations(6,1,2,1) 0
set rotations(6,1,3,0) 0
set rotations(6,1,3,1) 0
set rotations(6,2,0,0) 0
set rotations(6,2,0,1) 0
set rotations(6,2,1,0) 0
set rotations(6,2,1,1) 0
set rotations(6,2,2,0) 0
set rotations(6,2,2,1) 0
set rotations(6,2,3,0) 0
set rotations(6,2,3,1) 0
set rotations(6,3,0,0) 0
set rotations(6,3,0,1) 0
set rotations(6,3,1,0) 0
set rotations(6,3,1,1) 0
set rotations(6,3,2,0) 0
set rotations(6,3,2,1) 0
set rotations(6,3,3,0) 0
set rotations(6,3,3,1) 0

canvas .myCanvas -background black -width $WIDTH_PX -height $HEIGHT_PX
pack .myCanvas
update

# Clear completed (filled) rows.
# Start from the bottom of the board, moving all rows down to fill in a completed row, with
# the completed row cleared and placed at the top.
proc clear_board {} {
  global HEIGHT WIDTH board completed_lines
  set rows_deleted 0
  set row [expr {$HEIGHT -1}]
  while {$row >= $rows_deleted} {
    set has_hole 0
    for {set x 0} {($x < $WIDTH) && !$has_hole} {incr x} {
      set has_hole [expr {!$board($row,$x)}]
    }
    if {!$has_hole} {
      for {set y $row} {$y > $rows_deleted} {incr y -1} {
        for {set x 0} {$x < $WIDTH} {incr x} {
          set board($y,$x) $board([expr {$y-1}],$x)
        }
      }
      for {set x 0} {$x < $WIDTH} {incr x} {
        set board($rows_deleted,$x) 0
      }
      incr rows_deleted
    } else {
      incr row -1
    }
  }
  incr completed_lines $rows_deleted
}

proc move_tetromino {dx dy} {
  global current_coords current_piece board
  # Clear the board where the piece currently is.
  for {set i 0} {$i < 4} {incr i} {
    set x $current_coords($i,0)
    set y $current_coords($i,1)
    set board($y,$x) 0
  }
  # Update the current piece's coordinates and fill the board in the new coordinates.
  for {set i 0} {$i < 4} {incr i} {
    set x [expr {$current_coords($i,0) + $dx}]
    set y [expr {$current_coords($i,1) + $dy}]
    set current_coords($i,0) $x
    set current_coords($i,1) $y
    set board($y,$x) [expr {$current_piece + 1}]
  }
}

proc set_coords {coords_ block} {
  global board
  upvar $coords_ coords
  for {set i 0} {$i < 4} {incr i} {
    set board($coords($i,1),$coords($i,0)) $block
  }
}

proc collision_detected {dx dy} {
  global current_coords current_piece WIDTH HEIGHT board
  set collision 0
  # Clear the board where the piece currently is to not detect self collision.
  set_coords current_coords 0
  for {set i 0} {$i < 4} {incr i} {
    set x $current_coords($i,0)
    set y $current_coords($i,1)
    set new_x [expr {$x + $dx}]
    set new_y [expr {$y + $dy}]
    # Collision is hitting the left wall, right wall, bottom, or a non-black block.
    # Since this collision detection is only for movement, check the top (y < 0) is not needed.
    if {[expr {($x + $dx) < 0}] || [expr {($x + $dx) >= $WIDTH}] || [expr {($y + $dy) >= $HEIGHT}] || [expr $board($new_y,$new_x)]} {
      set collision 1
      break
    }
  }
  # Restore the current piece.
  set_coords current_coords [expr {$current_piece + 1}]
  return $collision
}

proc rotate {} {
  global rotations current_piece current_coords current_orientation WIDTH HEIGHT board
  for {set i 0} {$i < 4} {incr i} {
    set new_coords($i,0) [expr {$current_coords($i,0) + $rotations($current_piece,$current_orientation,$i,0)}]
    set new_coords($i,1) [expr {$current_coords($i,1) + $rotations($current_piece,$current_orientation,$i,1)}]
  }

  # Clear the board where the piece currently is to not detect self collision.
  set_coords current_coords 0
  for {set i 0} {$i < 4} {incr i} {
    set x $new_coords($i,0)
    set y $new_coords($i,1)
    # Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
    if {[expr {$x < 0}] || [expr {$x >= $WIDTH}] || [expr {$y < 0}] || [expr {$y >= $HEIGHT}] || $board($y,$x)} {
      # Restore the current piece.
      set_coords current_coords [expr {$current_piece + 1}]
      return false
    }
  }

  for {set i 0} {$i < 4} {incr i} {
    set current_coords($i,0) $new_coords($i,0)
    set current_coords($i,1) $new_coords($i,1)
    set board($new_coords($i,1),$new_coords($i,0)) [expr {$current_piece + 1}]
  }
  set current_orientation [expr {($current_orientation + 1) % 4}]
  return true
}

bind all <Escape> exit
bind all <q> exit
bind all <Key> {
  switch "%K" {
    "p" {
      set state [expr {$state eq "PLAY" ? "PAUSE" : "PLAY"}]
    }
    "F1" { stop_music $current_sound; set current_sound 0; play_music 0 }
    "F2" { stop_music $current_sound; set current_sound 1; play_music 1 }
    "F3" { stop_music $current_sound; set current_sound 2; play_music 2 }
  }
  if {"%K" eq "p"} {
  }
  if {$state eq "PLAY"} {
    switch "%K" {
      "Left" {
        if {![collision_detected -1 0]} {
          move_tetromino -1 0
        }
      }
      "Right" {
        if {![collision_detected 1 0]} {
          move_tetromino 1 0
        }
      }
      "Down" {
        if {![collision_detected 0 1]} {
          move_tetromino 0 1
        }
      }
      "space" {
        while {![collision_detected 0 1]} {
          move_tetromino 0 1
        }
      }
      "Up" {
        rotate
      }
    }
  }

  draw
  update
}

proc add_board_piece {current_piece} {
  global WIDTH starting_positions board current_coords
  set center [expr int($WIDTH / 2)]
  for {set i 0} {$i < 4} {incr i} {
    set x [expr $center + $starting_positions($current_piece,$i,0)]
    set y $starting_positions($current_piece,$i,1)
    if {$board($y,$x)} {
      return 1
    }
  }
  for {set i 0} {$i < 4} {incr i} {
    set x [expr $center + $starting_positions($current_piece,$i,0)]
    set y $starting_positions($current_piece,$i,1)
    set board($y,$x) [expr {$current_piece + 1}]
    set current_coords($i,0) $x
    set current_coords($i,1) $y
  }
  return 0
}

proc draw {} {
  global HEIGHT WIDTH HEIGHT_PX BLOCK_SIZE SCALE_FACTOR blocks board wall logo starting_positions next_piece completed_lines
  .myCanvas delete "all"

  # Wall extends from top to bottom, separating the board from the status area.
  .myCanvas create image [expr {$WIDTH*$BLOCK_SIZE}] 0 -image $wall -anchor "nw"

  # The logo sits at the top right of the screen right of the wall.
  set left_border [expr {$WIDTH*$BLOCK_SIZE + 50 + int(6*$BLOCK_SIZE*0.20)}]
  set width [expr {int(6*$BLOCK_SIZE*0.90)}]
  .myCanvas create image $left_border 0 -image $logo -anchor "nw"

  # Write the number of completed lines.
  .myCanvas create text $left_border [expr {int($HEIGHT_PX*0.25)}] -width [expr {int(6*$BLOCK_SIZE*0.80)}] -anchor "nw" -fill "red" -font [list Courier $::fontsize] -text "Lines: $completed_lines"

  # Write the current game level.
  .myCanvas create text $left_border [expr {int($HEIGHT_PX*0.35)}] -width [expr {int(6*$BLOCK_SIZE*0.80)}] -anchor "nw" -fill "red"  -font [list Courier $::fontsize] -text "Level: [expr {int($completed_lines / 3)}]"

  # Draw the next tetromino piece.
  for {set i 0} {$i < 4} {incr i} {
    set top_border [expr {int($HEIGHT_PX * 0.45)}]
    set left_border [expr {($WIDTH + 2)*$BLOCK_SIZE + 50 + int(6*$BLOCK_SIZE*0.05)}]
    set x [expr {$left_border + $starting_positions([expr {$next_piece}],$i,0)*$BLOCK_SIZE}]
    set y [expr {$top_border + $starting_positions([expr {$next_piece}],$i,1)*$BLOCK_SIZE}]
    .myCanvas create image $x $y -image $blocks([expr {$next_piece+1}]) -anchor "nw"
  }

  for {set y 0} {$y < $HEIGHT} {incr y} {
    for {set x 0} {$x < $WIDTH} {incr x} {
      #.myCanvas create image [expr {$x*$BLOCK_SIZE}] [expr {$y*$BLOCK_SIZE}] -image $blocks([expr {int(rand()*7+1)}]) -anchor "nw"
      .myCanvas create image [expr {$x*$BLOCK_SIZE}] [expr {$y*$BLOCK_SIZE}] -image $blocks($board($y,$x)) -anchor "nw"
    }
  }
}


puts "
TETЯIS:

  usage: $::argv0 \[level 1-15\]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.
"


add_board_piece $current_piece
draw
update
set last_frame_ms [clock clicks -milliseconds]
set game_ticks 0
set drop_ticks 0

while {$state ne "GAMEOVER"} {
  if {$state eq "PLAY"} {
    if {[expr {$game_ticks >= ($drop_ticks + max(15 - $completed_lines / 3, 1))}]} {
      set drop_ticks $game_ticks
      if {![collision_detected 0 1]} {
        move_tetromino 0 1
        draw
      } else {
        clear_board
        set current_orientation 0
        set current_piece $next_piece
        set next_piece [expr {int(rand()*7)}]
        if {[add_board_piece $current_piece]} {
          set state "GAMEOVER"
        }
      }
    }
  }
  update
  set now_ms [clock clicks -milliseconds]
  if {[expr {($now_ms - $last_frame_ms) >= $MS_PER_FRAME}]} {
    incr game_ticks
    set last_frame_ms $now_ms
  }
  after 1
}

# Game over.
puts "Game over."
stop_music $current_sound
play_music 3

# Clear a rectangle for the game-over message and write the message.
.myCanvas create rectangle 0 [expr {$HEIGHT_PX*0.4375}] $WIDTH_PX [expr {$HEIGHT_PX*0.5625}] -fill "black"
.myCanvas create text [expr {$WIDTH_PX*0.05}] [expr {$HEIGHT_PX*0.48}] -width $WIDTH_PX -anchor "nw" -fill "red" -font [list Courier $::fontsize] -text "The only winning move is not to play"

update
bind all <Key> {
  switch "%K" {
    "q" { exit }
    "Esc" { exit }
  }
}

while {1 < 2} {
  after 10
  update
}
