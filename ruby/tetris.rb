#!/usr/bin/env ruby
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.

require 'sdl'

SDL.init(SDL::INIT_AUDIO | SDL::INIT_TIMER | SDL::INIT_VIDEO)
SDL::Mixer.open(44100)
SDL::TTF.init

module States
  PLAY     = 1
  PAUSE    = 2
  GAMEOVER = 3
end

# Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
$starting_positions = [
  [[-1,0], [-1,1], [0,1], [1,1]],  # Leftward L piece.
  [[-1,1], [0,1],  [0,0], [1,0]],  # Rightward Z piece.
  [[-2,0], [-1,0], [0,0], [1,0]],  # Long straight piece.
  [[-1,1], [0,1],  [0,0], [1,1]],  # Bump in middle piece.
  [[-1,1], [0,1],  [1,1], [1,0]],  # L piece.
  [[-1,0], [0,0],  [0,1], [1,1]],  # Z piece.
  [[-1,0], [-1,1], [0,0], [0,1]],  # Square piece.
]

# Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
# Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
# For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
# The coordinate diffs map each block to its new location.
# Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
$rotations = [
  # Leftward L piece.
  [[[0,2],  [1,1],   [0,0], [-1,-1]],
   [[2,0],  [1,-1],  [0,0], [-1,1]],
   [[0,-2], [-1,-1], [0,0], [1,1]],
   [[-2,0], [-1,1],  [0,0], [1,-1]]],
  # Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
  [[[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]],
   [[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]]],
  # Long straight piece. Orientation symmetry: 0==2 and 1==3.
  [[[2,-2], [1,-1], [0,0], [-1,1]],
   [[-2,2], [-1,1], [0,0], [1,-1]],
   [[2,-2], [1,-1], [0,0], [-1,1]],
   [[-2,2], [-1,1], [0,0], [1,-1]]],
  # Bump in middle piece.
  [[[1,1],   [0,0], [-1,1],  [-1,-1]],
   [[1,-1],  [0,0], [1,1],   [-1,1]],
   [[-1,-1], [0,0], [1,-1],  [1,1]],
   [[-1,1],  [0,0], [-1,-1], [1,-1]]],
  # L Piece.
  [[[1,1],   [0,0], [-1,-1], [-2,0]],
   [[1,-1],  [0,0], [-1,1],  [0,2]],
   [[-1,-1], [0,0], [1,1],   [2,0]],
   [[-1,1],  [0,0], [1,-1],  [0,-2]]],
  # Z piece. Orientation symmetry: 0==2 and 1==3.
  [[[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]],
   [[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]]],
  # Square piece. Orientation symmetry: 0==1==2==3.
  [[[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]]]
]

$NUM_TETROMINOS = 7
$MS_PER_FRAME = 1000 / 60

class GameContext
  def initialize(width, height, block_size, level)
    @width = width
    @height = height
    @block_size = block_size
    @width_px = @width*@block_size + 50 + 6*@block_size
    @height_px = @height*@block_size
    @state = States::PLAY
    @current_piece = rand(1..$NUM_TETROMINOS)
    @next_piece = rand(1..$NUM_TETROMINOS)
    @current_coords = Array.new(4){Array.new(2){0}}
    @current_orientation = 0
    @completed_lines = [0, [45, level * 3].min].max
    @board = Array.new(@height){Array.new(@width){0}}
    @game_ticks = 0
    @drop_ticks = 0
    @last_frame_ms = 0

    @window = SDL::Screen.open(@width_px, @height_px, 24, SDL::SWSURFACE)
    @logo         = File.open("graphics/logo.png",         "rb"){|f| SDL::Surface.loadFromIO(f)}
    @wall         = File.open("graphics/wall.png",         "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_black  = File.open("graphics/block_black.png",  "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_blue   = File.open("graphics/block_blue.png",   "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_cyan   = File.open("graphics/block_cyan.png",   "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_green  = File.open("graphics/block_green.png",  "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_orange = File.open("graphics/block_orange.png", "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_purple = File.open("graphics/block_purple.png", "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_red    = File.open("graphics/block_red.png",    "rb"){|f| SDL::Surface.loadFromIO(f)}
    @block_yellow = File.open("graphics/block_yellow.png", "rb"){|f| SDL::Surface.loadFromIO(f)}
    @blocks = [@block_black, @block_blue, @block_cyan, @block_green, @block_orange, @block_purple, @block_red, @block_yellow]

    @bwv814menuet = SDL::Mixer::Music.loadFromString(File.read("sound/bwv814menuet.wav"))
    @korobeiniki  = SDL::Mixer::Music.loadFromString(File.read("sound/korobeiniki.wav"))
    @russiansong  = SDL::Mixer::Music.loadFromString(File.read("sound/russiansong.wav"))
    @gameover     = SDL::Mixer::Music.loadFromString(File.read("sound/gameover.wav"))
    SDL::Mixer.playMusic(@korobeiniki, -1)

    @font = SDL::TTF.open('fonts/Montserrat-Regular.ttf', 40)
    @font_small = SDL::TTF.open('fonts/Montserrat-Regular.ttf', 28)
  end

  attr_writer :completed_lines
  attr_reader :state

  def pause
    @state = @state == States::PLAY ? States::PAUSE : States::PLAY
  end

  def draw_screen
    for y in 0..@height-1
      for x in 0..@width-1
        SDL.blitSurface(@blocks[@board[y][x]], 0, 0, @block_size, @block_size, @window, x*@block_size, y*@block_size)
      end
    end

    # Wall extends from top to bottom, separating the board from the status area.
    y = 0
    until y >= @height_px do
      SDL.blitSurface(@wall, 0, 0, 50, 640, @window, @width*@block_size, y)
      y += 640
    end

    # Clear the status area.
    @window.fill_rect(@width*@block_size + 50, 0, @width_px-1, @height_px-1, 0x000000)

    # The logo sits at the top right of the screen right of the wall.
    left_border = @width*@block_size + 50 + 6*@block_size*0.05
    width = 6*@block_size*0.90
    SDL.blitSurface(@logo, 0, 0, 99, 44, @window, left_border, 0)

    # Write the number of completed lines.
    @font.draw_solid_utf8(@window, "Lines: #{@completed_lines}", left_border, @height_px*0.25, 255, 0, 0)

    # Write the current game level.
    @font.draw_solid_utf8(@window, "Level: #{@completed_lines / 3}", left_border, @height_px*0.35, 255, 0, 0)

    # Draw the next tetromino piece.
    for i in 0..3 do
      top_border = @height_px * 0.45
      left_border = (@width + 2)*@block_size + 50 + 6*@block_size*0.05
      x = left_border + $starting_positions[@next_piece-1][i][0]*@block_size
      y = top_border + $starting_positions[@next_piece-1][i][1]*@block_size
      SDL.blitSurface(@blocks[@next_piece], 0, 0, @block_size, @block_size, @window, x, y)
    end
    @window.flip
  end

  def play_music(song)
    case song
    when 1 then SDL::Mixer.playMusic(@bwv814menuet, -1)
    when 2 then SDL::Mixer.playMusic(@korobeiniki,  -1)
    when 3 then SDL::Mixer.playMusic(@russiansong,  -1)
    when 4 then SDL::Mixer.playMusic(@gameover,  0)
    end
  end

  def execute_board_piece(execute)
    center = @width / 2
    for i in 0..3
      x = center + $starting_positions[@current_piece-1][i][0]
      y = $starting_positions[@current_piece-1][i][1]
      if @board[y][x] != 0 then
        return true
      end
      execute.call(i, x, y)
    end
    return false
  end

  def active_placement(i, x, y)
    @board[y][x] = @current_piece
    @current_coords[i][0] = x
    @current_coords[i][1] = y
  end

  def add_board_piece()
    return execute_board_piece(lambda {|i, x, y| }) || execute_board_piece(lambda {|i, x, y| method(:active_placement).call(i, x, y)})
  end

  def move_tetromino(dx, dy)
    for i in 0..3
      x = @current_coords[i][0]
      y = @current_coords[i][1]
      @board[y][x] = 0
    end
    for i in 0..3
      x = @current_coords[i][0] += dx
      y = @current_coords[i][1] += dy
      @board[y][x] = @current_piece
    end
  end

  def set_coords(coords, piece)
    for i in 0..3
      @board[coords[i][1]][coords[i][0]] = piece
    end
  end

  def collision_detected(dx, dy)
    collision = false
    # Clear the board where the piece currently is to not detect self collision.
    set_coords(@current_coords, 0)
    for i in 0..3
      x = @current_coords[i][0]
      y = @current_coords[i][1]
      # Collision is hitting the left wall, right wall, bottom, or a non-black block.
      # Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if (x + dx) < 0 or (x + dx) >= @width or (y + dy) >= @height or @board[y+dy][x+dx] != 0 then
        collision = true
        break
      end
    end
    # Restore the current piece.
    set_coords(@current_coords, @current_piece)
    return collision
  end

  # Clear completed (filled) rows.
  # Start from the bottom of the board, moving all rows down to fill in a completed row, with
  # the completed row cleared and placed at the top.
  def clear_board
    rows_deleted = 0
    row = @height - 1
    while row >= rows_deleted
      has_hole = false
      x = 0
      while x < @width and !has_hole
        has_hole = @board[row][x] == 0
        x += 1
      end
      if !has_hole then
        deleted_row = @board[row]
        y = row
        while y > rows_deleted
          @board[y] = @board[y-1]
          y -= 1
        end
        @board[rows_deleted] = deleted_row
        @board[rows_deleted] = Array.new(@width){0}
        rows_deleted += 1
      else
        row -= 1
      end
    end
    @completed_lines += rows_deleted
  end

  def advance_ticks
    changed = false
    if @game_ticks >= @drop_ticks + [15 - @completed_lines / 3, 1].max then
      changed = true
      @drop_ticks = @game_ticks
      if not collision_detected(0, 1) then
        move_tetromino(0, 1)
      else
        clear_board
        @current_orientation = 0
        @current_piece = @next_piece
        @next_piece = rand(1..$NUM_TETROMINOS)
        if add_board_piece then
          @state = States::GAMEOVER
        end
      end
    end
    return changed
  end

  def update_ticks
    now_ms = SDL::get_ticks
    if (now_ms - @last_frame_ms) >= $MS_PER_FRAME then
      @game_ticks += 1
      @last_frame_ms = now_ms
    end
  end

  def rotate
    new_coords = Array.new(4){Array.new(2){0}}
    rotation = $rotations[@current_piece-1][@current_orientation]
    for i in 0..3
      new_coords[i][0] = @current_coords[i][0] + rotation[i][0]
      new_coords[i][1] = @current_coords[i][1] + rotation[i][1]
    end

    # Clear the board where the piece currently is to not detect self collision.
    set_coords(@current_coords, 0)
    for i in 0..3
      x = new_coords[i][0]
      y = new_coords[i][1]
      # Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if x < 0 or x >= @width or y < 0 or y >= @height or @board[y][x] != 0 then
        # Restore the current piece.
        set_coords(@current_coords, @current_piece)
        return false
      end
    end

    for i in 0..3
      @current_coords[i][0] = new_coords[i][0]
      @current_coords[i][1] = new_coords[i][1]
      @board[new_coords[i][1]][new_coords[i][0]] = @current_piece
    end
    @current_orientation = (@current_orientation + 1) % 4
    return true
  end

  def gameover
    play_music(4)
    # Clear a rectangle for the game-over message and write the message.
    @window.fill_rect(0, @height_px*0.4375, @width_px-1, @height_px*0.125, 0x000000)

    @font_small.draw_solid_utf8(@window, "The only winning move is not to play", @width_px*0.05, @height_px*0.47, 0xFF, 0x00, 0x00)
    @window.flip

    loop do
      while e = SDL::Event.poll
        case e
          when SDL::Event::Quit then exit
        end

        if SDL::Event::KeyDown === e then
          case e.sym
            when SDL::Key::Q then exit
            when SDL::Key::ESCAPE then exit
          end
        end
        SDL::delay(10)
      end
    end
  end
end

level = 0
if ARGV.length >= 1 then
  level = ARGV[0].to_i
end
ctx = GameContext.new(10, 20, 32, level)
ctx.add_board_piece

print "
TETЯIS: 

  usage: ", $0, " [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.\n\n"

ctx.draw_screen
while ctx.state != States::GAMEOVER
  while e = SDL::Event.poll
    case e
      when SDL::Event::Quit then exit
    end

    if SDL::Event::KeyDown === e then
      case e.sym
        when SDL::Key::Q then exit
        when SDL::Key::ESCAPE then exit
        when SDL::Key::F1 then ctx.play_music(1)
        when SDL::Key::F2 then ctx.play_music(2)
        when SDL::Key::F3 then ctx.play_music(3)
        when SDL::Key::P  then ctx.pause
      end
    end
    updated = false
    if ctx.state == States::PLAY && SDL::Event::KeyDown === e then
      case e.sym
        when SDL::Key::UP then
          updated = ctx.rotate
        when SDL::Key::LEFT then
          if !ctx.collision_detected(-1, 0) then
            ctx.move_tetromino(-1, 0)
            updated = true
          end
        when SDL::Key::RIGHT then
          if !ctx.collision_detected(1, 0) then
            ctx.move_tetromino(1, 0)
            updated = true
          end
        when SDL::Key::DOWN then
          if !ctx.collision_detected(0, 1) then
            ctx.move_tetromino(0, 1)
            updated = true
          end
        when SDL::Key::SPACE then
          while !ctx.collision_detected(0, 1) do
            ctx.move_tetromino(0, 1)
            updated = true
          end
      end
    end
  end

  if ctx.state == States::PLAY then
    if ctx.advance_ticks | updated then
      ctx.draw_screen
    end
  end
  ctx.update_ticks
  SDL::delay(1)
end

ctx.gameover
