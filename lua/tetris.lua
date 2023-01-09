#!/usr/bin/env lua
-- Author: Adam Rogoyski (adam@rogoyski.com).
-- Public domain software.
--
-- A tetris game.

local SDL = require("SDL")
local image = require("SDL.image")
local ttf = require("SDL.ttf")
local mixer = require("SDL.mixer")
math.randomseed(os.time())

local NUM_TETROMINOS = 7

local ctx = {
  width = 10,
  height = 20,
  block_size = 96,
  frame_rate_ms = 1000 / 60,
  current_piece = math.random(2, NUM_TETROMINOS+1),
  current_orientation = 1,
  next_piece = math.random(2, NUM_TETROMINOS+1),
  completed_lines = 0,
  status = "PLAY",
  board = {},
  current_coords = {{}, {}, {}, {}},
}
ctx.width_px = ctx.width*ctx.block_size + 50 + 6*ctx.block_size
ctx.height_px = ctx.height*ctx.block_size

-- Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
local starting_positions = {
  {{-1,0}, {-1,1}, {0,1}, {1,1}},  -- Leftward L piece.
  {{-1,1}, {0,1},  {0,0}, {1,0}},  -- Rightward Z piece.
  {{-2,0}, {-1,0}, {0,0}, {1,0}},  -- Long straight piece.
  {{-1,1}, {0,1},  {0,0}, {1,1}},  -- Bump in middle piece.
  {{-1,1}, {0,1},  {1,1}, {1,0}},  -- L piece.
  {{-1,0}, {0,0},  {0,1}, {1,1}},  -- Z piece.
  {{-1,0}, {-1,1}, {0,0}, {0,1}},  -- Square piece.
}

-- Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
-- Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
-- For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
-- The coordinate diffs map each block to its new location.
-- Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
local rotations = {
  -- Leftward L piece.
  {{{0,2},  {1,1},   {0,0}, {-1,-1}},
   {{2,0},  {1,-1},  {0,0}, {-1,1}},
   {{0,-2}, {-1,-1}, {0,0}, {1,1}},
   {{-2,0}, {-1,1},  {0,0}, {1,-1}}},
  -- Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
  {{{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}},
   {{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}}},
  -- Long straight piece. Orientation symmetry: 0==2 and 1==3.
  {{{2,-2}, {1,-1}, {0,0}, {-1,1}},
   {{-2,2}, {-1,1}, {0,0}, {1,-1}},
   {{2,-2}, {1,-1}, {0,0}, {-1,1}},
   {{-2,2}, {-1,1}, {0,0}, {1,-1}}},
  -- Bump in middle piece.
  {{{1,1},   {0,0}, {-1,1},  {-1,-1}},
   {{1,-1},  {0,0}, {1,1},   {-1,1}},
   {{-1,-1}, {0,0}, {1,-1},  {1,1}},
   {{-1,1},  {0,0}, {-1,-1}, {1,-1}}},
  -- L Piece.
  {{{1,1},   {0,0}, {-1,-1}, {-2,0}},
   {{1,-1},  {0,0}, {-1,1},  {0,2}},
   {{-1,-1}, {0,0}, {1,1},   {2,0}},
   {{-1,1},  {0,0}, {1,-1},  {0,-2}}},
  -- Z piece. Orientation symmetry: 0==2 and 1==3.
  {{{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}},
   {{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}}},
  -- Square piece. Orientation symmetry: 0==1==2==3.
  {{{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}}}
}


assert(SDL.init{
    SDL.flags.Video,
    SDL.flags.Audio,
})
assert(ttf.init())

ctx.window = assert(SDL.createWindow{
    title   = "TETЯIS",
    width   = ctx.width_px,
    height  = ctx.height_px,
})
ctx.renderer = assert(SDL.createRenderer(ctx.window, 0, 0))

assert(mixer.openAudio(44100, SDL.audioFormat.S16, 2, 1024))
ctx.music_korobeiniki  = assert(mixer.loadWAV("sound/korobeiniki.wav"))
ctx.music_bwv814menuet = assert(mixer.loadWAV("sound/bwv814menuet.wav"))
ctx.music_russiansong  = assert(mixer.loadWAV("sound/russiansong.wav"))
ctx.music_gameover     = assert(mixer.loadWAV("sound/gameover.wav"))

local formats, ret, err = image.init{ image.flags.PNG }
if not formats[image.flags.PNG] then
    error(err)
end
ctx.graphics = {
  wall         = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/wall.png"))),
  logo         = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/logo.png"))),
  block_black  = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_black.png"))),
  block_blue   = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_blue.png"))),
  block_cyan   = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_cyan.png"))),
  block_green  = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_green.png"))),
  block_orange = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_orange.png"))),
  block_purple = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_purple.png"))),
  block_red    = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_red.png"))),
  block_yellow = assert(ctx.renderer:createTextureFromSurface(image.load("graphics/block_yellow.png"))),
}
ctx.graphics.blocks = {ctx.graphics.block_black, ctx.graphics.block_blue, ctx.graphics.block_cyan, ctx.graphics.block_green, ctx.graphics.block_orange, ctx.graphics.block_purple, ctx.graphics.block_red, ctx.graphics.block_yellow}

ctx.font = assert(ttf.open("fonts/Montserrat-Regular.ttf", 48))

function initializeBoard(ctx)
  for y=1,ctx.height do
    ctx.board[y] = {}
    for x=1,ctx.width do
      ctx.board[y][x] = 1
    end
  end
end

function addBoardPiece(ctx)
  coords = starting_positions[ctx.current_piece-1]
  local center = math.floor(ctx.width / 2)
  for i, coord in ipairs(coords) do
    local x = center + coord[1] + 1
    local y = coord[2] + 1
    if ctx.board[y][x] ~= 1 then
      return true
    end
  end
  for i, coord in ipairs(coords) do
    local x = center + coord[1] + 1
    local y = coord[2] + 1
    ctx.board[y][x] = ctx.current_piece
    ctx.current_coords[i][1] = x
    ctx.current_coords[i][2] = y
  end
end

function drawBoard(ctx)
  for y=1,ctx.height do
    for x=1,ctx.width do
      ctx.renderer:copy(ctx.graphics.blocks[ctx.board[y][x]], nil, {w=ctx.block_size, h=ctx.block_size, x=(x-1)*ctx.block_size, y=(y-1)*ctx.block_size})
    end
  end
end

function drawStatus(ctx)
  -- The status area width is the length of the wall and 6 blocks.
  -- Wall extends from top to bottom, separating the board from the status area.
  ctx.renderer:copy(ctx.graphics.wall, nil, {w=50, h=ctx.height_px, x=ctx.width*ctx.block_size, y=0})

  -- The logo sits at the top right of the screen right of the wall. It is 20% of the status height.
  local height = math.floor(ctx.height_px * 0.20)
  local width = math.floor(6*ctx.block_size * 0.90)
  local left_border = ctx.width*ctx.block_size + 50 + math.floor(6*ctx.block_size * 0.05)
  ctx.renderer:copy(ctx.graphics.logo, nil, {w=width, h=height, x=left_border, y=0})

  -- Write the number of completed lines.
  local height = math.floor(ctx.height_px * 0.05)
  local top_border = math.floor(ctx.height_px * 0.25)
  text = assert(ctx.renderer:createTextureFromSurface(ctx.font:renderUtf8("Lines: " .. ctx.completed_lines, "solid", 0xFF0000)))
  ctx.renderer:copy(text, nil, {w=width, h=height, x=left_border, y=top_border})

  -- Write the current game level.
  local top_border = math.floor(ctx.height_px * 0.35)
  text = assert(ctx.renderer:createTextureFromSurface(ctx.font:renderUtf8("Level: " .. math.floor(ctx.completed_lines / 3), "solid", 0xFF0000)))
  ctx.renderer:copy(text, nil, {w=width, h=height, x=left_border, y=top_border})

  -- Draw the next tetromino piece.
  for i=1,4 do
    top_border = math.floor(ctx.height_px * 0.45)
    left_border = (ctx.width + 2)*ctx.block_size + 50 + math.floor(6*ctx.block_size * 0.05)
    local x = left_border + (starting_positions[ctx.next_piece-1][i][1]*ctx.block_size)
    local y = top_border  + (starting_positions[ctx.next_piece-1][i][2]*ctx.block_size)
    ctx.renderer:copy(ctx.graphics.blocks[ctx.next_piece], nil, {w=ctx.block_size, h=ctx.block_size, x=x, y=y})
  end
end

function drawScreen(ctx)
  drawBoard(ctx)
  drawStatus(ctx)
end

function drawGameOver(ctx)
  -- Create a black box with margins for the gameover message.
  local box_height = math.floor(ctx.height_px * 0.30)
  local box_top_border = math.floor(ctx.height_px * 0.35)
  local rect_surface = assert(SDL.createRGBSurface(ctx.width_px, box_height, 24))
  assert(rect_surface.fillRect(rect_surface, {w=ctx.width_px, h=box_height, x=0, y=0}, color))
  local rect_texture = assert(ctx.renderer:createTextureFromSurface(rect_surface, 0xFF0000))
  ctx.renderer:copy(rect_texture, nil, {w=ctx.width_px, h=box_height, x=0, y=box_top_border})

  local msg_height = math.floor(ctx.height_px * 0.20)
  local msg_width = math.floor(ctx.width_px * 0.95)
  local msg_top_border = math.floor(ctx.height_px * 0.40)
  local msg_left_border = math.floor(ctx.width_px * 0.025)
  local rect_surface = assert(SDL.createRGBSurface(msg_width, msg_height, 24))
  text = assert(ctx.renderer:createTextureFromSurface(ctx.font:renderUtf8("The only winning move is not to play", "solid", 0xFF0000)))
  ctx.renderer:copy(text, nil, {w=msg_width, h=msg_height, x=msg_left_border, y=msg_top_border})
  ctx.renderer:present()
end

function moveTetromino(ctx, dx, dy)
  -- Clear the board where the piece currently is.
  for i=1,4 do
    local x = ctx.current_coords[i][1]
    local y = ctx.current_coords[i][2]
    ctx.board[y][x] = 1
  end
  -- Update the current piece's coordinates and fill the board in the new coordinates.
  for i=1,4 do
    ctx.current_coords[i][1] = ctx.current_coords[i][1] + dx
    ctx.current_coords[i][2] = ctx.current_coords[i][2] + dy
    ctx.board[ctx.current_coords[i][2]][ctx.current_coords[i][1]] = ctx.current_piece
  end
end

function setCoords(board, coords, piece)
  for i=1,4 do
    board[coords[i][2]][coords[i][1]] = piece
  end
end

function collisionDetected(ctx, dx, dy)
  local collision = false
  -- Clear the board where the piece currently is to not detect self collision.
  setCoords(ctx.board, ctx.current_coords, 1)
  for i=1,4 do
    local x = ctx.current_coords[i][1]
    local y = ctx.current_coords[i][2]
    -- Collision is hitting the left wall, right wall, bottom, or a non-black block.
    -- Since this collision detection is only for movement, check the top (y < 0) is not needed.
    if (x + dx) < 1 or (x + dx) > ctx.width or (y + dy) > ctx.height or ctx.board[y+dy][x+dx] ~= 1 then
      collision = true
      break
    end
  end
  -- Restore the current piece.
  setCoords(ctx.board, ctx.current_coords, ctx.current_piece)
  return collision
end

function rotate(ctx)
  local new_coords = {{}, {}, {}, {}}
  local rotation = rotations[ctx.current_piece-1][ctx.current_orientation]
  for i=1,4 do
    new_coords[i][1] = ctx.current_coords[i][1] + rotation[i][1]
    new_coords[i][2] = ctx.current_coords[i][2] + rotation[i][2]
  end

  -- Clear the board where the piece currently is to not detect self collision.
  setCoords(ctx.board, ctx.current_coords, 1)
  for i=1,4 do
    local x = new_coords[i][1]
    local y = new_coords[i][2]
    -- Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
    if x < 1 or x > ctx.width or y < 1 or y > ctx.height or ctx.board[y][x] ~= 1 then
      -- Restore the current piece.
      setCoords(ctx.board, ctx.current_coords, ctx.current_piece)
      return false
    end
  end

  for i=1,4 do
    ctx.current_coords[i][1] = new_coords[i][1]
    ctx.current_coords[i][2] = new_coords[i][2]
    ctx.board[new_coords[i][2]][new_coords[i][1]] = ctx.current_piece
  end
  if ctx.current_orientation == 4 then
    ctx.current_orientation = 1
  else
    ctx.current_orientation = ctx.current_orientation + 1
  end
  return true
end

-- Clear completed (filled) rows.
-- Start from the bottom of the board, moving all rows down to fill in a completed row, with
-- the completed row cleared and placed at the top.
function clearBoard(ctx)
  local rows_deleted = 0
  local row = ctx.height
  while row > rows_deleted do
    local has_hole = false
    local x = 1
    while x <= ctx.width and not has_hole do
      has_hole = ctx.board[row][x] == 1
      x = x + 1
    end
    if not has_hole then
      local deleted_row = ctx.board[row]
      local y = row
      while y > rows_deleted do
        ctx.board[y] = ctx.board[y-1]
        y = y - 1
      end
      ctx.board[rows_deleted+1] = deleted_row
      for i=1,ctx.width do
        ctx.board[rows_deleted+1][i] = 1
      end
      rows_deleted = rows_deleted + 1
    else
      row = row - 1
    end
  end
  ctx.completed_lines = ctx.completed_lines + rows_deleted
end

function exitGame()
  SDL.quit()
  os.exit()
end

print([[
TETЯIS:

  usage: ]] .. arg[0] .. [[ [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.
]])

if #arg == 1 then
  local level = tonumber(arg[1])
  ctx.completed_lines = level ~= nil and math.max(math.min(math.floor(level * 3), 45), 0) or 0
end

initializeBoard(ctx)
ctx.renderer:clear()
addBoardPiece(ctx)
drawScreen(ctx)
ctx.renderer:present()
ctx.music_korobeiniki:playChannel(1)

local last_frame_ms = SDL.getTicks()
local game_ticks = 0
local drop_ticks = 0
while ctx.status ~= "GAMEOVER" do 
  for e in SDL.pollEvent() do
    if e.type == SDL.event.Quit then
      exitGame()
    elseif e.type == SDL.event.KeyDown then
      if SDL.getKeyName(e.keysym.sym) == "Escape" or SDL.getKeyName(e.keysym.sym) == "Q" then
        exitGame()
      elseif SDL.getKeyName(e.keysym.sym) == "P" then
        ctx.status = ctx.status == "PLAY" and "PAUSE" or "PLAY"
      elseif SDL.getKeyName(e.keysym.sym) == "F1" then
        ctx.music_korobeiniki:playChannel(1)
      elseif SDL.getKeyName(e.keysym.sym) == "F2" then
        ctx.music_bwv814menuet:playChannel(1)
      elseif SDL.getKeyName(e.keysym.sym) == "F3" then
        ctx.music_russiansong:playChannel(1)
      end
    end

    local changed = false
    if ctx.status == "PLAY" then
      if e.type == SDL.event.KeyDown then
        if SDL.getKeyName(e.keysym.sym) == "Up" then
          changed = rotate(ctx)
        elseif SDL.getKeyName(e.keysym.sym) == "Left" and not collisionDetected(ctx, -1, 0) then
          changed = true
          moveTetromino(ctx, -1, 0)
        elseif SDL.getKeyName(e.keysym.sym) == "Right" and not collisionDetected(ctx, 1, 0) then
          changed = true
          moveTetromino(ctx, 1, 0)
        elseif SDL.getKeyName(e.keysym.sym) == "Down" and not collisionDetected(ctx, 0, 1) then
          changed = true
          moveTetromino(ctx, 0, 1)
        else
          while SDL.getKeyName(e.keysym.sym) == "Space" and not collisionDetected(ctx, 0, 1) do
            changed = true
            moveTetromino(ctx, 0, 1)
          end
        end
      end
    end
  end

  if ctx.status == "PLAY" then
    if game_ticks >= drop_ticks + math.max(15 - math.floor(ctx.completed_lines / 3), 1) then
      changed = true
      drop_ticks = game_ticks
      if not collisionDetected(ctx, 0, 1) then
        moveTetromino(ctx, 0, 1)
      else
        clearBoard(ctx)
        ctx.current_orientation = 1
        ctx.current_piece = ctx.next_piece
        ctx.next_piece = math.random(2, NUM_TETROMINOS + 1)
        if addBoardPiece(ctx) then
          ctx.status = "GAMEOVER"
        end
      end
    end
  end

  if changed then
    ctx.renderer:clear()
    drawScreen(ctx)
    ctx.renderer:present()
  end

  now_ms = SDL.getTicks()
  if now_ms - last_frame_ms > ctx.frame_rate_ms then
    last_frame_ms = now_ms
    game_ticks = game_ticks + 1
  end
  SDL.delay(1)
end

ctx.music_gameover:playChannel(1, 0)
drawGameOver(ctx)
while true do
  for e in SDL.pollEvent() do
    if e.type == SDL.event.Quit then
      exitGame()
    elseif e.type == SDL.event.KeyDown then
      if SDL.getKeyName(e.keysym.sym) == "Escape" or SDL.getKeyName(e.keysym.sym) == "Q"then
        exitGame()
      end
    end
  end
end
