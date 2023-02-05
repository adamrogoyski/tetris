#!/usr/bin/env -S php -c .
<?php
// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

SDL_Init(SDL_INIT_EVERYTHING);
if (\Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0) {
  throw new RuntimeException("Cannot open audio device");
}
if (TTF_Init() < 0) {
  throw new RuntimeException("Cannot initialize TTF");
}

enum Status {
  case PLAY;
  case PAUSE;
  case GAMEOVER;
}

enum Sound {
  case BWV814MENUET;
  case KOROBEINIKI;
  case RUSSIANSONG;
  case GAMEOVER;
}

class GameContext {
  private int $NUM_TETROMINOS = 7;
  private int $width = 0;
  private int $height = 0;
  private int $block_size = 0;
  private int $width_px = 0;
  private int $height_px = 0;
  private int $completed_lines = 0;
  private int $current_piece = 0;
  private int $next_piece = 0;
  private int $current_orientation = 0;
  private Status $state = Status::PLAY;
  private array $current_coords;
  private array $board;
  private array $starting_positions;
  private SDL_Window $screen;
  private $renderer;
  private $block_black;
  private $block_blue;
  private $block_cyan;
  private $block_green;
  private $block_orange;
  private $block_purple;
  private $block_red;
  private $block_yellow;
  private $block_wall;
  private $blocks;
  private $wall;
  private $logo;
  private ?Mix_Chunk $bwv814menuet;
  private ?Mix_Chunk $korobeiniki;
  private ?Mix_Chunk $russiansong;
  private ?Mix_Chunk $gameover;
  private SDL_Rect $brect;
  private SDL_Rect $wrect;
  private SDL_Rect $lorect;
  private SDL_Rect $lnrect;
  private SDL_Rect $lvrect;
  private SDL_Rect $nprect;
  private SDL_Color $red;
  private TTF_Font $font;

  public function __construct(int $width, int $height, int $block_size, int $level) {
    $this->width = $width;
    $this->height = $height;
    $this->block_size = $block_size;
    $this->width_px = $width*$block_size + 50 + 6*$block_size;
    $this->height_px = $height*$block_size;
    $this->completed_lines = 3 * $level;
    $this->current_piece = rand(1, $this->NUM_TETROMINOS);
    $this->next_piece = rand(1, $this->NUM_TETROMINOS);
    $this->current_coords = array_fill(0, 4, array_fill(0, 2, 0));
    $this->board = array_fill(0, $height, array_fill(0, $width, 0));

    // Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
    $this->starting_positions = [
      [[-1,0], [-1,1], [0,1], [1,1]],  // Leftward L piece.
      [[-1,1], [0,1],  [0,0], [1,0]],  // Rightward Z piece.
      [[-2,0], [-1,0], [0,0], [1,0]],  // Long straight piece.
      [[-1,1], [0,1],  [0,0], [1,1]],  // Bump in middle piece.
      [[-1,1], [0,1],  [1,1], [1,0]],  // L piece.
      [[-1,0], [0,0],  [0,1], [1,1]],  // Z piece.
      [[-1,0], [-1,1], [0,0], [0,1]],  // Square piece.
    ];

    $this->add_board_piece();

    // Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
    // Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
    // For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
    // The coordinate diffs map each block to its new location.
    // Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
    $this->rotations = [
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

    $this->screen = SDL_CreateWindow("Tetris", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, $this->width_px, $this->height_px, SDL_WINDOW_SHOWN);
    SDL_SetWindowTitle($this->screen, "Tetris");
    $this->renderer = SDL_CreateRenderer($this->screen, 0, SDL_RENDERER_ACCELERATED);

    $this->block_black  = IMG_LoadTexture($this->renderer, "graphics/block_black.png");
    if ($this->block_black == null) { $this->exit_game(SDL_GetError()); }
    $this->block_blue   = IMG_LoadTexture($this->renderer, "graphics/block_blue.png");
    if ($this->block_blue == null) { $this->exit_game(SDL_GetError()); }
    $this->block_cyan   = IMG_LoadTexture($this->renderer, "graphics/block_cyan.png");
    if ($this->block_cyan == null) { $this->exit_game(SDL_GetError()); }
    $this->block_green  = IMG_LoadTexture($this->renderer, "graphics/block_green.png");
    if ($this->block_green == null) { $this->exit_game(SDL_GetError()); }
    $this->block_orange = IMG_LoadTexture($this->renderer, "graphics/block_orange.png");
    if ($this->block_orange == null) { $this->exit_game(SDL_GetError()); }
    $this->block_purple = IMG_LoadTexture($this->renderer, "graphics/block_purple.png");
    if ($this->block_purple == null) { $this->exit_game(SDL_GetError()); }
    $this->block_red    = IMG_LoadTexture($this->renderer, "graphics/block_red.png");
    if ($this->block_red == null) { $this->exit_game(SDL_GetError()); }
    $this->block_yellow = IMG_LoadTexture($this->renderer, "graphics/block_yellow.png");
    if ($this->block_yellow == null) { $this->exit_game(SDL_GetError()); }
    $this->blocks = [&$this->block_black, &$this->block_blue, &$this->block_cyan, &$this->block_green, &$this->block_orange, &$this->block_purple, &$this->block_red, &$this->block_yellow];

    $this->wall = IMG_LoadTexture($this->renderer, "graphics/wall.png");
    if ($this->wall == null) { $this->exit_game(SDL_GetError()); }

    $this->logo = IMG_LoadTexture($this->renderer, "graphics/logo.png");
    if ($this->logo == null) { $this->exit_game(SDL_GetError()); }

    $this->brect = new SDL_Rect(0, 0, $this->block_size, $this->block_size);
    $this->wrect = new SDL_Rect($this->width*$block_size, 0, 50, $this->height_px);
    $this->lorect = new SDL_Rect($this->width*$this->block_size + 50 + 6*$this->block_size*0.05, 0, 6*$this->block_size*0.90, $this->height_px*0.20);
    $this->lnrect = new SDL_Rect($this->width*$this->block_size + 50 + 6*$this->block_size*0.05, $this->height_px*0.25, 6*$this->block_size*0.90, $this->height_px*0.05);
    $this->lvrect = new SDL_Rect($this->width*$this->block_size + 50 + 6*$this->block_size*0.05, $this->height_px*0.35, 6*$this->block_size*0.90, $this->height_px*0.05);
    $this->nprect = new SDL_Rect(0, 0, $this->block_size, $this->block_size);

    $this->font = TTF_OpenFont("fonts/Montserrat-Regular.ttf", 28);
    $this->red = new SDL_Color(255, 0, 0, 255);

    $this->bwv814menuet = Mix_LoadWAV("sound/bwv814menuet.wav");
    if ($this->bwv814menuet == null) { $this->exit_game(SDL_GetError()); }
    $this->korobeiniki  = Mix_LoadWAV("sound/korobeiniki.wav");
    if ($this->korobeiniki == null) { $this->exit_game(SDL_GetError()); }
    $this->russiansong  = Mix_LoadWAV("sound/russiansong.wav");
    if ($this->russiansong == null) { $this->exit_game(SDL_GetError()); }
    $this->gameover  = Mix_LoadWAV("sound/gameover.wav");
    if ($this->gameover == null) { $this->exit_game(SDL_GetError()); }
    $this->play_music(Sound::KOROBEINIKI);
  }

  private function exit_game(?string $msg) {
    TTF_Quit();
    SDL_DestroyRenderer($this->renderer);
    SDL_DestroyWindow($this->screen);
    SDL_Quit();
    if ($msg != null) {
      $msg .= "\n";
    }
    exit($msg);
  }

  private function play_music(Sound $song) {
    switch ($song) {
      case Sound::BWV814MENUET: Mix_PlayChannel(0, $this->bwv814menuet, -1); break;
      case Sound::KOROBEINIKI:  Mix_PlayChannel(0, $this->korobeiniki, -1); break;
      case Sound::RUSSIANSONG:  Mix_PlayChannel(0, $this->russiansong, -1); break;
      case Sound::GAMEOVER:     Mix_PlayChannel(0, $this->gameover, 0); break;
    }
  }

  private function draw_screen() {
    SDL_RenderClear($this->renderer);
    for ($x = 0; $x < $this->width; $x++) {
      for ($y = 0; $y < $this->height; $y++) {
        $this->brect->x = $x*$this->block_size;
        $this->brect->y = $y*$this->block_size;
        SDL_RenderCopy($this->renderer, $this->blocks[$this->board[$y][$x]], null, $this->brect);
      }
    }

    // Wall extends from top to bottom, separating the board from the status area.
    SDL_RenderCopy($this->renderer, $this->wall, null, $this->wrect);

    // The logo sits at the top right of the screen right of the wall.
    SDL_RenderCopy($this->renderer, $this->logo, null, $this->lorect);

    // Write the number of completed lines.
    $this->draw_text("Lines: " . intval($this->completed_lines), $this->lnrect);

    // Write the current game level.
    $this->draw_text("Level: " . intval($this->completed_lines / 3), $this->lvrect);

    // Draw the next tetromino piece.
    for ($i = 0; $i < 4; ++$i) {
      $top_border = $this->height_px * 0.45;
      $left_border = ($this->width + 2)*$this->block_size + 50 + 6*$this->block_size*0.05;
      $this->nprect->x = $left_border + $this->starting_positions[$this->next_piece-1][$i][0]*$this->block_size;
      $this->nprect->y = $top_border  + $this->starting_positions[$this->next_piece-1][$i][1]*$this->block_size;
      SDL_RenderCopy($this->renderer, $this->blocks[$this->next_piece], null, $this->nprect);
    }
  }

  private function draw_text(string $s, SDL_Rect $rect) {
    $stext = TTF_RenderText_Solid($this->font, $s, $this->red);
    $text = SDL_CreateTextureFromSurface($this->renderer, $stext);
    SDL_RenderCopy($this->renderer, $text, null, $rect);
    SDL_FreeSurface($stext);
    SDL_DestroyTexture($text);
  }

  private function execute_board_piece(callable $execute): bool {
    $center = $this->width / 2;
    for ($i = 0; $i < 4; ++$i) {
      $x = $center + $this->starting_positions[$this->current_piece-1][$i][0];
      $y = $this->starting_positions[$this->current_piece-1][$i][1];
      if ($this->board[$y][$x]) {
        return true;
      }
      $execute($i, $x, $y);
    }
    return false;
  }

  private function active_placement(int $i, int $x, int $y) {
    $this->board[$y][$x] = $this->current_piece;
    $this->current_coords[$i][0] = $x;
    $this->current_coords[$i][1] = $y;
  }

  private function add_board_piece(): bool {
    return $this->execute_board_piece(function($i, $x, $y){}) || $this->execute_board_piece([$this, "active_placement"]);
  }

  private function move_tetromino(int $dx, int $dy) {
    // Clear the board where the piece currently is.
    for ($i = 0; $i < 4; ++$i) {
      $x = $this->current_coords[$i][0];
      $y = $this->current_coords[$i][1];
      $this->board[$y][$x] = 0;
    }
    // Update the current piece's coordinates and fill the board in the new coordinates.
    for ($i = 0; $i < 4; ++$i) {
      $this->current_coords[$i][0] += $dx;
      $this->current_coords[$i][1] += $dy;
      $this->board[$this->current_coords[$i][1]][$this->current_coords[$i][0]] = $this->current_piece;
    }
  }

  private function set_coords(array $coords, int $piece) {
    for ($i = 0; $i < 4; ++$i) {
      $this->board[$coords[$i][1]][$coords[$i][0]] = $piece;
    }
  }

  private function collision_detected(int $dx, int $dy): bool {
    $collision = false;
    // Clear the board where the piece currently is to not detect self collision.
    $this->set_coords($this->current_coords, 0);
    for ($i = 0; $i < 4; ++$i) {
      $x = $this->current_coords[$i][0];
      $y = $this->current_coords[$i][1];
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if (($x + $dx) < 0 || ($x + $dx) >= $this->width || ($y + $dy) >= $this->height || $this->board[$y+$dy][$x+$dx]) {
        $collision = true;
        break;
      }
    }
    // Restore the current piece.
    $this->set_coords($this->current_coords, $this->current_piece);
    return $collision;
  }

  private function rotate() {
    $new_coords = array_fill(0, 4, array_fill(0, 2, 0));
    $rotation = $this->rotations[$this->current_piece-1][$this->current_orientation];
    for ($i = 0; $i < 4; ++$i) {
      $new_coords[$i][0] = $this->current_coords[$i][0] + $rotation[$i][0];
      $new_coords[$i][1] = $this->current_coords[$i][1] + $rotation[$i][1];
    }

    // Clear the board where the piece currently is to not detect self collision.
    $this->set_coords($this->current_coords, 0);
    for ($i = 0; $i < 4; ++$i) {
      $x = $new_coords[$i][0];
      $y = $new_coords[$i][1];
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if ($x < 0 || $x >= $this->width || $y < 0 || $y >= $this->height || $this->board[$y][$x]) {
        // Restore the current piece.
        $this->set_coords($this->current_coords, $this->current_piece);
        return false;
      }
    }

    for ($i = 0; $i < 4; ++$i) {
      $this->current_coords[$i][0] = $new_coords[$i][0];
      $this->current_coords[$i][1] = $new_coords[$i][1];
      $this->board[$new_coords[$i][1]][$new_coords[$i][0]] = $this->current_piece;
    }
    $this->current_orientation = ($this->current_orientation + 1) % 4;
    return true;
  }

  // Clear completed (filled) rows.
  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  private function clear_board() {
    $rows_deleted = 0;
    for ($row = $this->height - 1; $row >= $rows_deleted;) {
      $has_hole = false;
      for ($x = 0; $x < $this->width && !$has_hole; ++$x) {
        $has_hole = !$this->board[$row][$x];
      }
      if (!$has_hole) {
        $deleted_row = $this->board[$row];
        for ($y = $row; $y > $rows_deleted; --$y) {
          $this->board[$y] = $this->board[$y-1];
        }
        $this->board[$rows_deleted] = $deleted_row;
        $this->board[$rows_deleted] = array_fill(0, $this->width, 0);
        ++$rows_deleted;
      } else {
        --$row;
      }
    }
    $this->completed_lines += $rows_deleted;
  }

  public function game_loop() {
    $this->draw_screen();
    SDL_RenderPresent($this->renderer);
    $game_ticks = $drop_ticks = 0;
    $last_frame_ms = intval(microtime(true) * 1000);
    $ms_per_frame = 1000 / 60;
    $e = new SDL_Event;
    while ($this->state != Status::GAMEOVER) {
      while (SDL_PollEvent($e)) {
        switch ($e->type) {
          case SDL_QUIT:
            $this->exit_game(null);
          case SDL_KEYDOWN:
            switch ($e->key->keysym->sym) {
              case SDLK_ESCAPE:
              case SDLK_q:
                $this->exit_game(null);
              case SDLK_p:
                $this->state = $this->state == Status::PLAY ? Status::PAUSE : Status::PLAY;
                break;
              case SDLK_F1: $this->play_music(Sound::BWV814MENUET); break;
              case SDLK_F2: $this->play_music(Sound::KOROBEINIKI); break;
              case SDLK_F3: $this->play_music(Sound::RUSSIANSONG); break;
            }
        }
        if ($this->state == Status::PLAY) {
          $changed = false;
          switch ($e->type) {
            case SDL_KEYDOWN:
              switch ($e->key->keysym->sym) {
                case SDLK_UP:
                  $changed = $this->rotate();
                  break;
                case SDLK_LEFT:
                  if (!$this->collision_detected(-1, 0)) {
                    $this->move_tetromino(-1, 0);
                    $changed = true;
                  }
                  break;
                case SDLK_RIGHT:
                  if (!$this->collision_detected(1, 0)) {
                    $this->move_tetromino(1, 0);
                    $changed = true;
                  }
                  break;
                case SDLK_DOWN:
                  if (!$this->collision_detected(0, 1)) {
                    $this->move_tetromino(0, 1);
                    $changed = true;
                  }
                  break;
                case SDLK_SPACE:
                  while (!$this->collision_detected(0, 1)) {
                    $this->move_tetromino(0, 1);
                    $changed = true;
                  }
                  break;
            }
          }
        }
      }

      if ($this->state == Status::PLAY) {
        if ($game_ticks >= $drop_ticks + max(15 - $this->completed_lines / 3, 1)) {
          $changed = true;
          $drop_ticks = $game_ticks;
          if (!$this->collision_detected(0, 1)) {
            $this->move_tetromino(0, 1);
          } else {
            $this->clear_board();
            $this->current_orientation = 0;
            $this->current_piece = $this->next_piece;
            $this->next_piece = rand(1, $this->NUM_TETROMINOS);
            if ($this->add_board_piece()) {
              $this->state = Status::GAMEOVER;
            }
          }
        }
      }

      if ($changed) {
        $this->draw_screen();
        SDL_RenderPresent($this->renderer);
      }

      $now_ms = intval(microtime(true) * 1000);
      if (($now_ms - $last_frame_ms) >= $ms_per_frame) {
        ++$game_ticks;
        $last_frame_ms = $now_ms;
      }
      SDL_Delay(1);
    }
  }

  public function game_over() {
    $this->play_music(Sound::GAMEOVER);
    $this->draw_screen();

     // Clear a rectangle for the game-over message and write the message.
    $rect = new SDL_Rect(0, $this->height_px*0.4375, $this->width_px, $this->height_px*0.125);
    SDL_RenderCopy($this->renderer, $this->block_black, null, $rect);
    $this->draw_text("The only winning move is not to play", $rect);
    SDL_RenderPresent($this->renderer);

    $e = new SDL_Event;
    while (true) {
      while (SDL_PollEvent($e)) {
        switch ($e->type) {
          case SDL_QUIT:
            $this->exit_game(null);
          case SDL_KEYDOWN:
            switch ($e->key->keysym->sym) {
              case SDLK_ESCAPE:
              case SDLK_q:
                $this->exit_game(null);
            }
        }
      }
    }
  }
}

$level = 0;
if ($argc >= 2) {
  $level = max(0, min(15, intval($argv[1])));
}
$ctx = new GameContext(10, 20, 96, $level);

echo "
TETЯIS:

  usage: $argv[0] [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.

";

$ctx->game_loop();
$ctx->game_over();
