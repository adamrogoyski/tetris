// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

import core.thread;
import core.runtime;
import std.algorithm;
import std.conv;
import std.format;
import std.math;
import std.random;
import std.stdio;
import std.string;
import std.typecons;
import bindbc.sdl;

immutable NUM_TETROMINOS = 7;
alias Coords = int[2][4];

// Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
immutable Coords[NUM_TETROMINOS] starting_positions = [
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
immutable Coords[4][NUM_TETROMINOS] rotations = [
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

class ExitException : Exception {
  int status;
  this(int _status=0, string file=__FILE__, size_t line=__LINE__) {
    super("Program exit", file, line);
    status = _status;
  }
}

void CHECK_SDLI(const(int) ret, const(string) msg, string function() GetError) {
  if (ret < 0) {
    stderr.writef("%s: %s\n", msg, GetError());
    throw new ExitException(1);
  }
}

void CHECK_SDLP(void* ret, const(string) msg, string function() GetError) {
  if (!ret) {
    stderr.writef("%s: %s\n", msg, GetError());
    throw new ExitException(1);
  }
}

string DSDL_GetError() {
  return to!string(SDL_GetError());
}

string DMix_GetError() {
  return to!string(Mix_GetError());
}

string DTTF_GetError() {
  return to!string(TTF_GetError());
}

enum GameState { PLAY, PAUSE, GAMEOVER };

struct GameContext {
  immutable int height;
  immutable int width;
  immutable int block_size;
  immutable int height_px;
  immutable int width_px;
  SDL_Window* window = null;
  SDL_Renderer* renderer = null;
  GameState status = GameState.PLAY;
  int[][] board;
  int current_piece;
  int next_piece;
  Coords current_coords;
  int current_orientation = 0;
  int completed_lines = 0;
  immutable int framerate = 60;

  SDL_Texture* block_black;
  SDL_Texture* block_blue;
  SDL_Texture* block_cyan;
  SDL_Texture* block_green;
  SDL_Texture* block_orange;
  SDL_Texture* block_purple;
  SDL_Texture* block_red;
  SDL_Texture* block_yellow;
  SDL_Texture*[8] blocks;
  SDL_Texture* logo;
  SDL_Texture* wall;

  Mix_Chunk* song_korobeiniki;
  Mix_Chunk* song_bwv814menuet;
  Mix_Chunk* song_russiansong;
  Mix_Chunk* gameover;

  TTF_Font* font;

  Random rng;

  this(const int height_, const int width_, const int block_size_, const int completed_lines_) {
    height = height_;
    width = width_;
    block_size = block_size_;
    height_px = height*block_size;
    width_px = width*block_size + 50 + 6*block_size;
    rng = Random(unpredictableSeed);
    board = new int[][height];
    for (auto i = 0; i < height; ++i) {
      board[i] = new int[width];
    }
    current_piece = uniform(1, 8, rng);
    next_piece = uniform(1, 8, rng);
    completed_lines = completed_lines_;
  }

  void load_graphics() {
    block_black = IMG_LoadTexture(renderer, "graphics/block_black.png");
    CHECK_SDLP(block_black,  "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_blue   = IMG_LoadTexture(renderer, "graphics/block_blue.png");
    CHECK_SDLP(block_blue,   "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_cyan   = IMG_LoadTexture(renderer, "graphics/block_cyan.png");
    CHECK_SDLP(block_cyan,   "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_green  = IMG_LoadTexture(renderer, "graphics/block_green.png");
    CHECK_SDLP(block_green,  "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_orange = IMG_LoadTexture(renderer, "graphics/block_orange.png");
    CHECK_SDLP(block_orange, "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_purple = IMG_LoadTexture(renderer, "graphics/block_purple.png");
    CHECK_SDLP(block_purple, "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_red    = IMG_LoadTexture(renderer, "graphics/block_red.png");
    CHECK_SDLP(block_red,    "IMG_LoadTexture", &DSDL_GetError);
    SDL_Texture* block_yellow = IMG_LoadTexture(renderer, "graphics/block_yellow.png");
    CHECK_SDLP(block_yellow, "IMG_LoadTexture", &DSDL_GetError);
    blocks = [block_black, block_blue, block_cyan, block_green, block_orange, block_purple, block_red, block_yellow];

    wall = IMG_LoadTexture(renderer, "graphics/wall.png");
    CHECK_SDLP(wall, "IMG_LoadTexture", &DSDL_GetError);
    logo = IMG_LoadTexture(renderer, "graphics/logo.png");
    CHECK_SDLP(logo, "IMG_LoadTexture", &DSDL_GetError);
  }

  void load_music() {
    CHECK_SDLP(song_korobeiniki  = Mix_LoadWAV("sound/korobeiniki.wav"),  "Mix_LoadWAV", &DMix_GetError);
    CHECK_SDLP(song_bwv814menuet = Mix_LoadWAV("sound/bwv814menuet.wav"), "Mix_LoadWAV", &DMix_GetError);
    CHECK_SDLP(song_russiansong  = Mix_LoadWAV("sound/russiansong.wav"),  "Mix_LoadWAV", &DMix_GetError);
    CHECK_SDLP(gameover          = Mix_LoadWAV("sound/gameover.wav"),     "Mix_LoadWAV", &DMix_GetError);
  }

  void load_fonts() {
    font = TTF_OpenFont("fonts/Montserrat-Regular.ttf", 48);
    CHECK_SDLP(font, "TTF_OpenFont", &DTTF_GetError);
  }

  bool execute_board_piece(void delegate(const int, const int, const int) execute) {
    immutable int center = width / 2;
    for (auto i = 0; i < 4; ++i) {
      immutable int x = center + starting_positions[current_piece-1][i][0];
      immutable int y = starting_positions[current_piece-1][i][1];
      if (board[y][x]) {
        return true;
      }
      execute(i, x, y);
    }
    return false;
  }

  void null_placement(const int i, const int x, const int y) { }

  void active_placement(const int i, const int x, const int y) {
    board[y][x] = current_piece;
    current_coords[i][0] = x;
    current_coords[i][1] = y;
  }

  // Returns the game over condition if adding a new piece collides. Checks game-over before adding piece to the board
  // so the final piece is not written to the screen with a collision.
  bool add_board_piece() {
    return execute_board_piece(&null_placement) || execute_board_piece(&active_placement);
  }


  void set_coords(int[][] board, const Coords coords, const int piece) {
    for (auto i = 0; i < 4; ++i) {
      board[coords[i][1]][coords[i][0]] = piece;
    }
  }

  bool collision_detected(const int dx, const int dy) {
    bool collision = false;
    // Clear the board where the piece currently is to not detect self collision.
    set_coords(board, current_coords, 0);
    for (auto i = 0; i < 4; ++i) {
      immutable int x = current_coords[i][0];
      immutable int y = current_coords[i][1];
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if ((x + dx) < 0 || (x + dx) >= width || (y + dy) >= height || board[y+dy][x+dx]) {
        collision = true;
        break;
      }
    }
    // Restore the current piece.
    set_coords(board, current_coords, current_piece);
    return collision;
  }

  void move_tetromino(const int dx, const int dy) {
    // Clear the board where the piece currently is.
    for (auto i = 0; i < 4; ++i) {
      immutable int x = current_coords[i][0];
      immutable int y = current_coords[i][1];
      board[y][x] = 0;
    }
    // Update the current piece's coordinates and fill the board in the new coordinates.
    for (auto i = 0; i < 4; ++i) {
      current_coords[i][0] += dx;
      current_coords[i][1] += dy;
      board[current_coords[i][1]][current_coords[i][0]] = current_piece;
    }
  }

  bool rotate() {
    Coords new_coords;
    immutable int[2][4] rotation = rotations[current_piece-1][current_orientation];
    for (auto i = 0; i < 4; ++i) {
      new_coords[i][0] = current_coords[i][0] + rotation[i][0];
      new_coords[i][1] = current_coords[i][1] + rotation[i][1];
    }

    // Clear the board where the piece currently is to not detect self collision.
    set_coords(board, current_coords, 0);
    for (auto i = 0; i < 4; ++i) {
      immutable int x = new_coords[i][0];
      immutable int y = new_coords[i][1];
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if (x < 0 || x >= width || y < 0 || y >= height || board[y][x]) {
        // Restore the current piece.
        set_coords(board, current_coords, current_piece);
        return false;
      }
    }

    for (auto i = 0; i < 4; ++i) {
      current_coords[i][0] = new_coords[i][0];
      current_coords[i][1] = new_coords[i][1];
      board[new_coords[i][1]][new_coords[i][0]] = current_piece;
    }
    current_orientation = (current_orientation + 1) % 4;
    return true;
  }

  // Clear completed (filled) rows.
  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  void clear_board() {
    int rows_deleted = 0;
    for (auto row = height - 1; row >= rows_deleted;) {
      bool has_hole = false;
      for (auto x = 0; x < width && !has_hole; ++x) {
        has_hole = !board[row][x];
      }
      if (!has_hole) {
        int[] deleted_row = board[row];
        for (auto y = row; y > rows_deleted; --y) {
          board[y] = board[y-1];
        }
        board[rows_deleted] = deleted_row;
        board[rows_deleted][] = 0;
        ++rows_deleted;
      } else {
        --row;
      }
    }
    completed_lines += rows_deleted;
  }

  void draw_text(const string s, const int x, const int y, const int w, const int h) {
    SDL_Color red = {r:255, g:0, b:0, a:255};
    SDL_Surface* stext = TTF_RenderText_Solid(font, toStringz(s), red);
    SDL_Texture* text = SDL_CreateTextureFromSurface(renderer, stext);
    CHECK_SDLP(text, "Render text", &DSDL_GetError);
    SDL_Rect dsttext = {x:x, y:y, w:w, h:h};
    SDL_RenderCopy(renderer, text, null, &dsttext);
    SDL_FreeSurface(stext);
    SDL_DestroyTexture(text);
  }

  void draw_status() {
    // Wall extends from top to bottom, separating the board from the status area.
    SDL_Rect dstwall = {x:width*block_size, y:0, w:50, h:height_px};
    SDL_RenderCopy(renderer, wall, null, &dstwall);

    // The logo sits at the top right of the screen right of the wall.
    immutable int left_border = width*block_size + 50 + cast(int) lrint(6*block_size*0.05);
    immutable int swidth_wmargin = cast(int) lrint(6*block_size*0.90);
    SDL_Rect dstlogo = {x:left_border, y:0, w:swidth_wmargin, h:cast(int) lrint(height_px*0.20)};
    SDL_RenderCopy(renderer, logo, null, &dstlogo);

    // Write the number of completed lines.
    auto text_lines = format!"Lines: %d"(completed_lines);
    draw_text(text_lines, left_border, cast(int) lrint(height_px*0.25), swidth_wmargin, cast(int) lrint(height_px*0.05));

    // Write the current game level.
    text_lines = format!"Level: %d"(cast(int) lrint(completed_lines / 3));
    draw_text(text_lines, left_border, cast(int) lrint(height_px*0.35), swidth_wmargin, cast(int) lrint(height_px*0.05));

    // Draw the next tetromino piece.
    for (auto i = 0; i < 4; ++i) {
      immutable int top_border = cast(int) lrint(height_px * 0.45);
      immutable int nleft_border = (width + 2)*block_size + 50 + cast(int) lrint(6*block_size*0.05);
      immutable int x = nleft_border + starting_positions[next_piece-1][i][0]*block_size;
      immutable int y = top_border + starting_positions[next_piece-1][i][1]*block_size;
      SDL_Rect dst = {x:x, y:y, w:block_size, h:block_size};
      SDL_RenderCopy(renderer, blocks[next_piece], null, &dst);
    }
  }

  void draw_board() {
    for (auto y = 0; y < height; ++y) {
      for (auto x = 0; x < width; ++x) {
        SDL_Rect dst = {x:x*block_size, y:y*block_size, w:block_size, h:block_size};
        SDL_RenderCopy(renderer, blocks[board[y][x]], null, &dst);
      }
    }
  }

  void draw_screen() {
    draw_board();
    draw_status();
    SDL_RenderPresent(renderer);
  }

  void game_loop() {
    draw_screen();
    ulong last_frame_ms = SDL_GetTicks();
    const ulong ms_per_frame = 1000 / framerate;
    ulong game_ticks = 0;
    ulong drop_ticks = 0;
    SDL_Event e;
    while (status != GameState.GAMEOVER) {
      bool changed = false;
      while (SDL_PollEvent(&e)) {
        switch(e.type) {
          case SDL_KEYDOWN:
            switch (e.key.keysym.sym) {
              case SDLK_ESCAPE:
              case SDLK_q:
                return;
              case SDLK_p:
                status = status == GameState.PLAY ? GameState.PAUSE : GameState.PLAY;
                break;
              case SDLK_F1:
                Mix_PlayChannel(0, song_korobeiniki, -1);
                break;
              case SDLK_F2:
                Mix_PlayChannel(0, song_bwv814menuet, -1);
                break;
              case SDLK_F3:
                Mix_PlayChannel(0, song_russiansong, -1);
                break;
              default:
                break;
            }
            break;
          case SDL_QUIT:
            return;
          default:
            break;
        }
        if (status == GameState.PLAY) {
          switch(e.type) {
            case SDL_KEYDOWN:
              switch (e.key.keysym.sym) {
                case SDLK_LEFT:
                  if (!collision_detected(-1, 0)) {
                    changed = true;
                    move_tetromino(-1, 0);
                  }
                  break;
                case SDLK_RIGHT:
                  if (!collision_detected(1, 0)) {
                    changed = true;
                    move_tetromino(1, 0);
                  }
                  break;
                case SDLK_DOWN:
                  if (!collision_detected(0, 1)) {
                    changed = true;
                    move_tetromino(0, 1);
                  }
                  break;
                case SDLK_SPACE:
                  while (!collision_detected(0, 1)) {
                    changed = true;
                    move_tetromino(0, 1);
                  }
                  break;
                case SDLK_UP:
                  changed = rotate();
                  break;
                default:
                  break;
              }
              break;
            default:
              break;
          }
        }
      }
      if (status == GameState.PLAY) {
        if (game_ticks >= drop_ticks + max(15 - completed_lines / 3, 1)) {
          changed = true;
          drop_ticks = game_ticks;
          if (!collision_detected(0, 1)) {
            move_tetromino(0, 1);
          } else {
            clear_board();
            current_orientation = 0;
            current_piece = next_piece;
            next_piece = uniform(1, 8, rng);
            if (add_board_piece()) {
              status = GameState.GAMEOVER;
            }
          }
        }
      }
      if (changed) {
        draw_screen();
        CHECK_SDLI(SDL_RenderClear(renderer), "SDL_Render_Clear", &DSDL_GetError);
      }
      ulong now_ms = SDL_GetTicks();
      if ((now_ms - last_frame_ms) >= ms_per_frame) {
        ++game_ticks;
        last_frame_ms = now_ms;
      }
      Thread.sleep(dur!("msecs")(1));
    }

    // Game over.
    Mix_PlayChannel(0, gameover, 0);
    draw_screen();
    // Clear a rectangle for the game-over message and write the message.
    SDL_Rect msgbox = {x:0, y:cast(int) lrint(height_px*0.4375), w:width_px, h:cast(int) lrint(height_px*0.125)};
    SDL_RenderCopy(renderer, block_black, null, &msgbox);
    immutable string msg = "The only winning move is not to play";
    draw_text(msg, cast(int) lrint(width_px*0.05), cast(int) lrint(height_px*0.4375), cast(int) lrint(width_px*0.90), cast(int) lrint(height_px*0.125));
    SDL_RenderPresent(renderer);
    while (true) {
      while (SDL_PollEvent(&e)) {
        switch(e.type) {
          case SDL_KEYDOWN:
            switch (e.key.keysym.sym) {
              case SDLK_ESCAPE:
              case SDLK_q:
                return;
              default:
                break;
            }
            break;
          case SDL_QUIT:
            return;
          default:
            break;
        }
      }
      Thread.sleep(dur!("msecs")(10));
    }
  }
}

int main(string[] args)
{
  int retval = 0;
  try {
    if (loadSDL() < sdlSupport) {
      stderr.writeln("loadSDL");
      return 1;
    }
    CHECK_SDLI(SDL_Init(SDL_INIT_AUDIO | SDL_INIT_EVENTS | SDL_INIT_TIMER | SDL_INIT_VIDEO), "SDL_Init", &DSDL_GetError);

    immutable int start_lines = args.length > 1 ? max(0, min(45, to!int(args[1])*3)) : 0;
    GameContext ctx = GameContext(20, 10, 64, start_lines);

    CHECK_SDLI(SDL_CreateWindowAndRenderer(ctx.width_px, ctx.height_px, SDL_WINDOW_SHOWN, &ctx.window, &ctx.renderer), "Window", &DSDL_GetError),
    SDL_SetWindowTitle(ctx.window, "TETRIS");

    loadSDLTTF();
    CHECK_SDLI(TTF_Init(), "TTF_Init", &DTTF_GetError);
    ctx.load_fonts();

    loadSDLImage();
    CHECK_SDLI(IMG_Init(IMG_INIT_PNG) == IMG_INIT_PNG ? 0 : -1, "IMG_Init", &DSDL_GetError);
    ctx.load_graphics();

    loadSDLMixer();
    CHECK_SDLI(Mix_OpenAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 4096), "Mix_OpenAudio", &DMix_GetError);
    ctx.load_music();
    CHECK_SDLI(Mix_PlayChannel(0, ctx.song_korobeiniki, -1), "Mix_PlayChannel", &DSDL_GetError);

    writeln("\n" ~
            "TETЯIS: \n\n" ~
            "  usage: ", args[0], " [level 1-15]\n\n" ~
            "  F1  - Korobeiniki (gameboy song A).\n" ~
            "  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).\n" ~
            "  F3  - Russion song (gameboy song C).\n" ~
            "  ESC - Quit.\n" ~
            "  p   - Pause.\n\n" ~
            "  Up - Rotate.\n" ~
            "  Down - Lower.\n" ~
            "  Space - Drop completely.\n");

    ctx.add_board_piece();
    ctx.game_loop();
  } catch(ExitException e) {
    retval = e.status;
  }
  SDL_Quit();
  return retval;
}
