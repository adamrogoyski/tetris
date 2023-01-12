// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

const sdl = require('@kmamal/sdl');
const canvas = require('canvas');
const sound = require('node-aplay');

const WIDTH = 10;
const HEIGHT = 20;
const BLOCK_SIZE = 32;
const STRIDE = WIDTH * BLOCK_SIZE * 4;
const WIDTH_PX = (WIDTH + 6) * BLOCK_SIZE + 50;
const HEIGHT_PX = HEIGHT * BLOCK_SIZE;
const FRAME_RATE_MS = 1000 / 60;
const IN_PLAY = 1;
const PAUSE = 2;
const GAMEOVER = 3;
const NUM_TETROMINOS = 7;

GameContext = {};
ctx = GameContext;

// Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
const starting_positions = [
  [[-1,0], [-1,1], [0,1], [1,1]],  // Leftward L piece.
  [[-1,1], [0,1],  [0,0], [1,0]],  // Rightward Z piece.
  [[-2,0], [-1,0], [0,0], [1,0]],  // Long straight piece.
  [[-1,1], [0,1],  [0,0], [1,1]],  // Bump in middle piece.
  [[-1,1], [0,1],  [1,1], [1,0]],  // L piece.
  [[-1,0], [0,0],  [0,1], [1,1]],  // Z piece.
  [[-1,0], [-1,1], [0,0], [0,1]],  // Square piece.
];

// Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
// Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
// For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
// The coordinate diffs map each block to its new location.
// Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
const rotations = [
  // Leftward L piece.
  [[[0,2],  [1,1],   [0,0], [-1,-1]],
   [[2,0],  [1,-1],  [0,0], [-1,1]],
   [[0,-2], [-1,-1], [0,0], [1,1]],
   [[-2,0], [-1,1],  [0,0], [1,-1]]],
  // Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
  [[[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]],
   [[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]]],
  // Long straight piece. Orientation symmetry: 0==2 and 1==3.
  [[[2,-2], [1,-1], [0,0], [-1,1]],
   [[-2,2], [-1,1], [0,0], [1,-1]],
   [[2,-2], [1,-1], [0,0], [-1,1]],
   [[-2,2], [-1,1], [0,0], [1,-1]]],
  // Bump in middle piece.
  [[[1,1],   [0,0], [-1,1],  [-1,-1]],
   [[1,-1],  [0,0], [1,1],   [-1,1]],
   [[-1,-1], [0,0], [1,-1],  [1,1]],
   [[-1,1],  [0,0], [-1,-1], [1,-1]]],
  // L Piece.
  [[[1,1],   [0,0], [-1,-1], [-2,0]],
   [[1,-1],  [0,0], [-1,1],  [0,2]],
   [[-1,-1], [0,0], [1,1],   [2,0]],
   [[-1,1],  [0,0], [1,-1],  [0,-2]]],
  // Z piece. Orientation symmetry: 0==2 and 1==3.
  [[[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]],
   [[1,0],  [0,1],  [-1,0], [-2,1]],
   [[-1,0], [0,-1], [1,0],  [2,-1]]],
  // Square piece. Orientation symmetry: 0==1==2==3.
  [[[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]],
   [[0,0], [0,0], [0,0], [0,0]]]
];

function AddBoardPiece() {
  const center = Math.floor(WIDTH / 2);
  for (i = 0; i < 4; ++i) {
    const x = center + starting_positions[ctx.current_piece-1][i][0];
    const y = starting_positions[ctx.current_piece-1][i][1];
    if (ctx.board[y][x]) {
      return true;
    }
  }
  for (i = 0; i < 4; ++i) {
    const x = center + starting_positions[ctx.current_piece-1][i][0];
    const y = starting_positions[ctx.current_piece-1][i][1];
    ctx.board[y][x] = ctx.current_piece;
    ctx.current_coords[i] = [x, y];
  }
  return false;
}

function Init() {
  ctx.block_black = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_black.src = 'graphics/block_black.png';
  ctx.block_blue = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_blue.src = 'graphics/block_blue.png';
  ctx.block_cyan = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_cyan.src = 'graphics/block_cyan.png';
  ctx.block_green = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_green.src = 'graphics/block_green.png';
  ctx.block_orange = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_orange.src = 'graphics/block_orange.png';
  ctx.block_purple = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_purple.src = 'graphics/block_purple.png';
  ctx.block_red = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_red.src = 'graphics/block_red.png';
  ctx.block_yellow = new canvas.Image(BLOCK_SIZE, BLOCK_SIZE);
  ctx.block_yellow.src = 'graphics/block_yellow.png';
  ctx.blocks = [ctx.block_black, ctx.block_blue, ctx.block_cyan, ctx.block_green,
                        ctx.block_orange, ctx.block_purple, ctx.block_red, ctx.block_yellow];
  ctx.logo = new canvas.Image(94, 44);
  ctx.logo.src = 'graphics/logo.png';
  ctx.wall = new canvas.Image(50, 640);
  ctx.wall.src = 'graphics/wall.png';

  ctx.music = new sound('sound/korobeiniki.wav');
  ctx.music.play();
  ctx.music_completion = function() {
    ctx.music.play();
  };
  ctx.music.on('complete', ctx.music_completion);

  ctx.board = Array(HEIGHT);
  for (y = 0; y < HEIGHT; y++) {
    ctx.board[y] = Array(WIDTH);
    for (x = 0; x < WIDTH; x++) {
      ctx.board[y][x] = 0;
    }
  }

  ctx.current_piece = Math.floor(Math.random() * NUM_TETROMINOS) + 1;
  ctx.next_piece = Math.floor(Math.random() * NUM_TETROMINOS) + 1;
  ctx.current_orientation = 0;
  ctx.current_coords = [[], [], [], []];
  ctx.game_ticks = 0;
  ctx.drop_ticks = 0;
  ctx.last_frame_ms = Date.now();
  ctx.status = IN_PLAY;
  ctx.completed_lines = 0
  if (process.argv.length >= 2) {
    level = parseInt(process.argv[process.argv.length-1]) * 3;
    if (!isNaN(level)) {
      ctx.completed_lines = Math.min(Math.max(0, level), 45);
    }
  }
}

function DrawStatus(sctx) {
  // Wall extends from top to bottom, separating the board from the status area.
  for (h = 0; h < HEIGHT_PX; h += Math.min(HEIGHT_PX - h, 640)) {
    sctx.drawImage(ctx.wall, WIDTH*BLOCK_SIZE, h);
  }

  // The logo sits at the top right of the screen right of the wall.
  const left_border = WIDTH*BLOCK_SIZE + 50 + 6*BLOCK_SIZE*0.05;
  sctx.drawImage(ctx.logo, left_border, 0);

  // Write the number of completed lines.
  sctx.font = "24px serif";
  sctx.fillStyle = 'red';
  sctx.fillText("Lines: " + ctx.completed_lines.toString(), left_border, HEIGHT_PX*0.25);

 // Write the current game level.
  sctx.fillText("Level: " + Math.floor(ctx.completed_lines / 3).toString(), left_border, HEIGHT_PX*0.35);

  // Draw the next tetromino piece.
  for (i = 0; i < 4; ++i) {
    const top_border = HEIGHT_PX * 0.45;
    const nb_left_border = (WIDTH + 2)*BLOCK_SIZE + 50 + Math.floor(6*BLOCK_SIZE*0.05);
    const x = nb_left_border + starting_positions[ctx.next_piece-1][i][0]*BLOCK_SIZE;
    const y = top_border + starting_positions[ctx.next_piece-1][i][1]*BLOCK_SIZE;
    sctx.drawImage(ctx.blocks[ctx.next_piece], x, y);
  }
}

function DrawScreen(screen_canvas, sctx, window) {
  // Clear the screen black.
  sctx.fillStyle = 'black';
  sctx.fillRect(0, 0, WIDTH_PX, HEIGHT_PX);

  // Draw the board blocks.
  for (y = 0; y < HEIGHT; y++) {
    for (x = 0; x < WIDTH; x++) {
      sctx.drawImage(ctx.blocks[ctx.board[y][x]], x*BLOCK_SIZE, y*BLOCK_SIZE);
    }
  }

  DrawStatus(sctx);
  window.render(WIDTH_PX, HEIGHT_PX, WIDTH_PX*4, 'bgra32', screen_canvas.toBuffer('raw'));
}

function MoveTetromino(dx, dy) {
  // Clear the board where the piece currently is.
  for (i = 0; i < 4; ++i) {
    const x = ctx.current_coords[i][0];
    const y = ctx.current_coords[i][1];
    ctx.board[y][x] = 0;
  }
  // Update the current piece's coordinates and fill the board in the new coordinates.
  for (i = 0; i < 4; ++i) {
    ctx.current_coords[i][0] += dx;
    ctx.current_coords[i][1] += dy;
    ctx.board[ctx.current_coords[i][1]][ctx.current_coords[i][0]] = ctx.current_piece;
  }
}

function SetCoords(board, coords, piece) {
  for (i = 0; i < 4; ++i) {
    board[coords[i][1]][coords[i][0]] = piece;
  }
}

function Rotate() {
  new_coords = [[], [], [], []];
  const rotation = rotations[ctx.current_piece-1][ctx.current_orientation];
  for (i = 0; i < 4; ++i) {
    new_coords[i][0] = ctx.current_coords[i][0] + rotation[i][0];
    new_coords[i][1] = ctx.current_coords[i][1] + rotation[i][1];
  }

  // Clear the board where the piece currently is to not detect self collision.
  SetCoords(ctx.board, ctx.current_coords, 0);
  for (i = 0; i < 4; ++i) {
    const x = new_coords[i][0];
    const y = new_coords[i][1];
    // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
    if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT || ctx.board[y][x]) {
      // Restore the current piece.
      SetCoords(ctx.board, ctx.current_coords, ctx.current_piece);
      return false;
    }
  }

  for (i = 0; i < 4; ++i) {
    ctx.current_coords[i][0] = new_coords[i][0];
    ctx.current_coords[i][1] = new_coords[i][1];
    ctx.board[new_coords[i][1]][new_coords[i][0]] = ctx.current_piece;
  }
  ctx.current_orientation = (ctx.current_orientation + 1) % 4;
  return true;
}

function CollisionDetected(dx, dy) {
  var collision = false;
  // Clear the board where the piece currently is to not detect self collision.
  SetCoords(ctx.board, ctx.current_coords, 0);
  for (i = 0; i < 4; ++i) {
    const x = ctx.current_coords[i][0];
    const y = ctx.current_coords[i][1];
    // Collision is hitting the left wall, right wall, bottom, or a non-black block.
    // Since this collision detection is only for movement, check the top (y < 0) is not needed.
    if ((x + dx) < 0 || (x + dx) >= WIDTH || (y + dy) >= HEIGHT || ctx.board[y+dy][x+dx]) {
      collision = true;
      break;
    }
  }
  // Restore the current piece.
  SetCoords(ctx.board, ctx.current_coords, ctx.current_piece);
  return collision;
}

// Clear completed (filled) rows.
// Start from the bottom of the board, moving all rows down to fill in a completed row, with
// the completed row cleared and placed at the top.
function ClearBoard() {
  var rows_deleted = 0;
  for (row = HEIGHT - 1; row >= rows_deleted;) {
    var has_hole = false;
    for (x = 0; x < WIDTH && !has_hole; ++x) {
      has_hole = !ctx.board[row][x];
    }
    if (!has_hole) {
      var deleted_row = ctx.board[row];
      for (y = row; y > rows_deleted; --y) {
        ctx.board[y] = ctx.board[y-1];
      }
      ctx.board[rows_deleted] = deleted_row;
      for (i = 0; i < WIDTH; ++i) {
        ctx.board[rows_deleted][i] = 0;
      }
      ++rows_deleted;
    } else {
      --row;
    }
  }
  ctx.completed_lines += rows_deleted;
}

function GameTick() {
  if (ctx.status == GAMEOVER) {
    // Clear a rectangle for the game-over message and write the message.
    ctx.sctx.fillStyle = 'black';
    ctx.sctx.fillRect(0, Math.floor(HEIGHT_PX*0.4375), WIDTH_PX, Math.floor(HEIGHT_PX*0.125));
    ctx.sctx.fillStyle = 'red';
    ctx.sctx.font = "48px serif";
    ctx.sctx.fillText('The only winning move is not to play', WIDTH_PX*0.05, Math.floor(HEIGHT_PX*0.51), WIDTH_PX*0.90);
    ctx.window.render(WIDTH_PX, HEIGHT_PX, WIDTH_PX*4, 'bgra32', ctx.screen_canvas.toBuffer('raw'));

    ctx.window.removeListener('keyDown', ctx.keyhandler);
    ctx.music.removeListener('complete', ctx.music_completion);
    ctx.music.stop();
    ctx.music = new sound('sound/gameover.wav');
    ctx.music.play();
    ctx.window.on('keyDown', e => {
      switch(e.key) {
        case 'q':
        case 'escape':
          ctx.music.stop();
          process.exit(0);
      }
    });
    return;
  }

  changed = false;
  if (ctx.status == IN_PLAY) {
    if (ctx.game_ticks >= ctx.drop_ticks + Math.max(15 - ctx.completed_lines / 3, 1)) {
      changed = true;
      ctx.drop_ticks = ctx.game_ticks;
      if (!CollisionDetected(0, 1)) {
        MoveTetromino(0, 1);
      } else {
        ClearBoard(ctx);
        ctx.current_orientation = 0;
        ctx.current_piece = ctx.next_piece;
        ctx.next_piece = Math.floor(Math.random() * NUM_TETROMINOS) + 1;
        if (AddBoardPiece()) {
          ctx.status = GAMEOVER;
        }
      }
    }
  }
  if (changed) {
    DrawScreen(ctx.screen_canvas, ctx.sctx, ctx.window);
  }

  const now_ms = Date.now();
  if ((now_ms - ctx.last_frame_ms) >= FRAME_RATE_MS) {
    ctx.game_ticks++;
    ctx.last_frame_ms = now_ms;
  }

  setTimeout(GameTick, FRAME_RATE_MS);
}


function Game() {
  Init();
  ctx.screen_canvas = canvas.createCanvas(WIDTH_PX, HEIGHT_PX);
  ctx.sctx = ctx.screen_canvas.getContext('2d');
  ctx.window = sdl.video.createWindow({title:"Tetris", width:WIDTH_PX, height:HEIGHT_PX });

  AddBoardPiece();
  DrawScreen(ctx.screen_canvas, ctx.sctx, ctx.window);
  ctx.keyhandler = function(e) {
    switch(e.key) {
      case 'q':
      case 'escape':
        ctx.music.stop();
        process.exit(0);
      case 'p':
        if (ctx.status == IN_PLAY) { ctx.status = PAUSE; } else {ctx.status = IN_PLAY; }
        break;
      case 'f1':
        ctx.music.removeListener('complete', ctx.music_completion);
        ctx.music.stop();
        ctx.music = new sound('sound/korobeiniki.wav');
        ctx.music.on('complete', ctx.music_completion);
        ctx.music.play();
        break;
      case 'f2':
        ctx.music.removeListener('complete', ctx.music_completion);
        ctx.music.stop();
        ctx.music = new sound('sound/bwv814menuet.wav');
        ctx.music.on('complete', ctx.music_completion);
        ctx.music.play();
        break;
      case 'f3':
        ctx.music.removeListener('complete', ctx.music_completion);
        ctx.music.stop();
        ctx.music = new sound('sound/russiansong.wav');
        ctx.music.on('complete', ctx.music_completion);
        ctx.music.play();
        break;
    }
    if (ctx.status == IN_PLAY) {
      var changed = false;
      switch(e.key) {
        case 'left':
          if (!CollisionDetected(-1, 0)) {
            changed = true;
            MoveTetromino(-1, 0);
          }
          break;
        case 'right':
          if (!CollisionDetected(1, 0)) {
            changed = true;
            MoveTetromino(1, 0);
          }
          break;
        case 'down':
          if (!CollisionDetected(0, 1)) {
            changed = true;
            MoveTetromino(0, 1);
          }
          break;
        case 'space':
          while (!CollisionDetected(0, 1)) {
            changed = true;
            MoveTetromino(0, 1);
          }
          break;
        case 'up':
          changed = Rotate();
          break;
      }
      if (changed) {
        DrawScreen(ctx.screen_canvas, ctx.sctx, ctx.window);
      }
    }
  };
  ctx.window.on('keyDown', ctx.keyhandler);
  setTimeout(GameTick, FRAME_RATE_MS);
}


console.log(`
TETЯIS:

  usage: ` + process.argv.join(' ') + ` [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.

`);

Game();
