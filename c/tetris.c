// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <time.h>
#include <unistd.h>
#include <sys/param.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_mixer.h>
#include <SDL2/SDL_ttf.h>

#define NUM_TETROMINOS 7

typedef int Coords[4][2];
typedef int (*CoordsPtr)[2];

typedef struct {
  // Width and height are of the playing board, whereas width_px and height_px are for the whole screen, which includes status.
  const int width;
  const int height;
  int width_px;
  int height_px;
  const int block_size;
  const int framerate;
  int **board;
  int current_piece;
  int current_orientation;
  Coords current_coords;
  int next_piece;
  int completed_lines;
  enum {PLAY, PAUSE, GAMEOVER} status;
  struct {
    Mix_Chunk* song_korobeiniki;
    Mix_Chunk* song_bwv814menuet;
    Mix_Chunk* song_russiansong;
    Mix_Chunk* gameover;
  } music;
  struct {
    SDL_Texture* block_black;
    SDL_Texture* block_blue;
    SDL_Texture* block_cyan;
    SDL_Texture* block_green;
    SDL_Texture* block_orange;
    SDL_Texture* block_purple;
    SDL_Texture* block_red;
    SDL_Texture* block_yellow;
    SDL_Texture* blocks[8];
    SDL_Texture* gameover;
    SDL_Texture* logo;
    SDL_Texture* wall;
  } graphics;
  TTF_Font* font;
} GameContext;

// Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
const int starting_positions[NUM_TETROMINOS][4][2] = {
  {{-1,0}, {-1,1}, {0,1}, {1,1}},  // Leftward L piece.
  {{-1,1}, {0,1},  {0,0}, {1,0}},  // Rightward Z piece.
  {{-2,0}, {-1,0}, {0,0}, {1,0}},  // Long straight piece.
  {{-1,1}, {0,1},  {0,0}, {1,1}},  // Bump in middle piece.
  {{-1,1}, {0,1},  {1,1}, {1,0}},  // L piece.
  {{-1,0}, {0,0},  {0,1}, {1,1}},  // Z piece.
  {{-1,0}, {-1,1}, {0,0}, {0,1}},  // Square piece.
};

// Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
// Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
// For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
// The coordinate diffs map each block to its new location.
// Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
const int rotations[NUM_TETROMINOS][4][4][2] = {
  // Leftward L piece.
  {{{0,2},  {1,1},   {0,0}, {-1,-1}},
   {{2,0},  {1,-1},  {0,0}, {-1,1}},
   {{0,-2}, {-1,-1}, {0,0}, {1,1}},
   {{-2,0}, {-1,1},  {0,0}, {1,-1}}},
  // Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
  {{{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}},
   {{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}}},
  // Long straight piece. Orientation symmetry: 0==2 and 1==3.
  {{{2,-2}, {1,-1}, {0,0}, {-1,1}},
   {{-2,2}, {-1,1}, {0,0}, {1,-1}},
   {{2,-2}, {1,-1}, {0,0}, {-1,1}},
   {{-2,2}, {-1,1}, {0,0}, {1,-1}}},
  // Bump in middle piece.
  {{{1,1},   {0,0}, {-1,1},  {-1,-1}},
   {{1,-1},  {0,0}, {1,1},   {-1,1}},
   {{-1,-1}, {0,0}, {1,-1},  {1,1}},
   {{-1,1},  {0,0}, {-1,-1}, {1,-1}}},
  // L Piece.
  {{{1,1},   {0,0}, {-1,-1}, {-2,0}},
   {{1,-1},  {0,0}, {-1,1},  {0,2}},
   {{-1,-1}, {0,0}, {1,1},   {2,0}},
   {{-1,1},  {0,0}, {1,-1},  {0,-2}}},
  // Z piece. Orientation symmetry: 0==2 and 1==3.
  {{{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}},
   {{1,0},  {0,1},  {-1,0}, {-2,1}},
   {{-1,0}, {0,-1}, {1,0},  {2,-1}}},
  // Square piece. Orientation symmetry: 0==1==2==3.
  {{{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}},
   {{0,0}, {0,0}, {0,0}, {0,0}}}
};

const char* tstrerror(void) { return strerror(errno); }

void CHECK_SDLI(int ret, const char* const msg, const char* (* const GetError)()) {
  if (ret < 0) {
    fprintf(stderr, "%s: %s\n", msg, GetError());
    exit(EXIT_FAILURE);
  }
}

void CHECK_SDLP(void* ret, const char* const msg, const char* (* const GetError)()) {
  if (!ret) {
    fprintf(stderr, "%s: %s\n", msg, GetError());
    exit(EXIT_FAILURE);
  }
}

bool ExecuteBoardPiece(GameContext* ctx, void (*execute)(GameContext*, int, int, int)) {
  const int center = ctx->width / 2;
  for (int i = 0; i < 4; ++i) {
    const int x = center + starting_positions[ctx->current_piece-1][i][0];
    const int y = starting_positions[ctx->current_piece-1][i][1];
    if (ctx->board[y][x]) {
      return true;
    }
    execute(ctx, i, x, y);
  }
  return false;
}

void NullPlacement(GameContext* ctx, int i, int x, int y) { }

void ActivePlacement(GameContext* ctx, const int i, const int x, const int y) {
  ctx->board[y][x] = ctx->current_piece;
  ctx->current_coords[i][0] = x;
  ctx->current_coords[i][1] = y;
}

// Returns the game over condition if adding a new piece collides. Checks game-over before adding piece to the board
// so the final piece is not written to the screen with a collision.
bool AddBoardPiece(GameContext* ctx) {
  return ExecuteBoardPiece(ctx, NullPlacement) || ExecuteBoardPiece(ctx, ActivePlacement);
}

void MoveTetromino(GameContext* ctx, const int dx, const int dy) {
  // Clear the board where the piece currently is.
  for (int i = 0; i < 4; ++i) {
    const int x = ctx->current_coords[i][0];
    const int y = ctx->current_coords[i][1];
    ctx->board[y][x] = 0;
  }
  // Update the current piece's coordinates and fill the board in the new coordinates.
  for (int i = 0; i < 4; ++i) {
    ctx->current_coords[i][0] += dx;
    ctx->current_coords[i][1] += dy;
    ctx->board[ctx->current_coords[i][1]][ctx->current_coords[i][0]] = ctx->current_piece;
  }
}

void SetCoords(int** board, const CoordsPtr coords, const int piece) {
  for (int i = 0; i < 4; ++i) {
    board[coords[i][1]][coords[i][0]] = piece;
  }
}

bool CollisionDetected(GameContext* ctx, const int dx, const int dy) {
  bool collision = false;
  // Clear the board where the piece currently is to not detect self collision.
  SetCoords(ctx->board, ctx->current_coords, 0);
  for (int i = 0; i < 4; ++i) {
    const int x = ctx->current_coords[i][0];
    const int y = ctx->current_coords[i][1];
    // Collision is hitting the left wall, right wall, bottom, or a non-black block.
    // Since this collision detection is only for movement, check the top (y < 0) is not needed.
    if ((x + dx) < 0 || (x + dx) >= ctx->width || (y + dy) >= ctx->height || ctx->board[y+dy][x+dx]) {
      collision = true;
      break;
    }
  }
  // Restore the current piece.
  SetCoords(ctx->board, ctx->current_coords, ctx->current_piece);
  return collision;
}

bool Rotate(GameContext* ctx) {
  Coords new_coords;
  const int (* const rotation)[2] = rotations[ctx->current_piece-1][ctx->current_orientation];
  for (int i = 0; i < 4; ++i) {
    new_coords[i][0] = ctx->current_coords[i][0] + rotation[i][0];
    new_coords[i][1] = ctx->current_coords[i][1] + rotation[i][1];
  }

  // Clear the board where the piece currently is to not detect self collision.
  SetCoords(ctx->board, ctx->current_coords, 0);
  for (int i = 0; i < 4; ++i) {
    const int x = new_coords[i][0];
    const int y = new_coords[i][1];
    // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
    if (x < 0 || x >= ctx->width || y < 0 || y >= ctx->height || ctx->board[y][x]) {
      // Restore the current piece.
      SetCoords(ctx->board, ctx->current_coords, ctx->current_piece);
      return false;
    }
  }

  for (int i = 0; i < 4; ++i) {
    ctx->current_coords[i][0] = new_coords[i][0];
    ctx->current_coords[i][1] = new_coords[i][1];
    ctx->board[new_coords[i][1]][new_coords[i][0]] = ctx->current_piece;
  }
  ctx->current_orientation = (ctx->current_orientation + 1) % 4;
  return true;
}

// Clear completed (filled) rows.
// Start from the bottom of the board, moving all rows down to fill in a completed row, with
// the completed row cleared and placed at the top.
void ClearBoard(GameContext* ctx) {
  int rows_deleted = 0;
  for (int row = ctx->height - 1; row >= rows_deleted;) {
    bool has_hole = false;
    for (int x = 0; x < ctx->width && !has_hole; ++x) {
      has_hole = !ctx->board[row][x];
    }
    if (!has_hole) {
      int* deleted_row = ctx->board[row];
      for (int y = row; y > rows_deleted; --y) {
        ctx->board[y] = ctx->board[y-1];
      }
      ctx->board[rows_deleted] = deleted_row;
      memset(ctx->board[rows_deleted], 0, ctx->width * sizeof(int));
      ++rows_deleted;
    } else {
      --row;
    }
  }
  ctx->completed_lines += rows_deleted;
}

void DrawBoard(SDL_Renderer* renderer, GameContext* const ctx) {
  for (int y = 0; y < ctx->height; ++y) {
    for (int x = 0; x < ctx->width; ++x) {
      SDL_Rect dst = {.x=x*ctx->block_size, .y=y*ctx->block_size, .w=ctx->block_size, .h=ctx->block_size};
      SDL_RenderCopy(renderer, ctx->graphics.blocks[ctx->board[y][x]], NULL, &dst);
    }
  }
}

void DrawText(SDL_Renderer* renderer, GameContext* ctx, const char* const s, const int x, const int y, const int w, const int h) {
  SDL_Color red = {.r=255, .g=0, .b=0, .a=255};
  SDL_Surface* stext = TTF_RenderText_Solid(ctx->font, s, red);
  SDL_Texture* text;
  CHECK_SDLP(text = SDL_CreateTextureFromSurface(renderer, stext), "Render text", SDL_GetError);
  SDL_Rect dsttext = {.x=x, .y=y, .w=w, .h=h};
  SDL_RenderCopy(renderer, text, NULL, &dsttext);
  SDL_FreeSurface(stext);
  SDL_DestroyTexture(text);
}

void DrawStatus(SDL_Renderer* renderer, GameContext* const ctx) {
  // Wall extends from top to bottom, separating the board from the status area.
  SDL_Rect dstwall = {.x=ctx->width*ctx->block_size, .y=0, .w=50, .h=ctx->height*ctx->block_size};
  SDL_RenderCopy(renderer, ctx->graphics.wall, NULL, &dstwall);

  // The logo sits at the top right of the screen right of the wall.
  SDL_Rect dstlogo = {.x=ctx->width*ctx->block_size + 60, .y=20, .w=99, .h=44};
  SDL_RenderCopy(renderer, ctx->graphics.logo, NULL, &dstlogo);

  // Write the number of completed lines.
  char text_lines[12];
  snprintf(text_lines, sizeof(text_lines), "Lines: %d", ctx->completed_lines);
  DrawText(renderer, ctx, text_lines, ctx->width*ctx->block_size+60, 100, 100, 50);

  // Write the current game level.
  snprintf(text_lines, sizeof(text_lines), "Level: %d", ctx->completed_lines / 3);
  DrawText(renderer, ctx, text_lines, ctx->width*ctx->block_size+60, 180, 100, 50);

  // Draw the next tetromino piece.
  for (int i = 0; i < 4; ++i) {
    const int x = (starting_positions[ctx->next_piece-1][i][0])*ctx->block_size + ctx->width*ctx->block_size + 4*ctx->block_size;
    const int y = starting_positions[ctx->next_piece-1][i][1]*ctx->block_size + MAX(4, ctx->height/2 -1)*ctx->block_size;
    SDL_Rect dst = {.x=x, .y=y, .w=ctx->block_size, .h=ctx->block_size};
    SDL_RenderCopy(renderer, ctx->graphics.blocks[ctx->next_piece], NULL, &dst);
  }
}

void GameLoop(SDL_Window* window, SDL_Renderer* renderer, GameContext* ctx) {
  SDL_Event e;
  Uint64 last_frame_ms = SDL_GetTicks();
  const Uint64 ms_per_frame = 1000 / ctx->framerate;
  Uint64 game_ticks = 0;
  Uint64 drop_ticks = 0;
  while (ctx->status != GAMEOVER) {
    bool changed = false;
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
        case SDL_KEYDOWN:
          switch (e.key.keysym.sym) {
            case SDLK_ESCAPE:
            case SDLK_q:
              return;
            case SDLK_p:
              switch (ctx->status) {
                case PLAY:
                  ctx->status = PAUSE;
                  break;
                case PAUSE:
                  ctx->status = PLAY;
                  break;
                default:
                  break;
              }
              break;
            case SDLK_F1:
              Mix_PlayChannel(0, ctx->music.song_korobeiniki, -1);
              break;
            case SDLK_F2:
              Mix_PlayChannel(0, ctx->music.song_bwv814menuet, -1);
              break;
            case SDLK_F3:
              Mix_PlayChannel(0, ctx->music.song_russiansong, -1);
              break;
          }
          break;
        case SDL_QUIT:
          return;
      }
      if (ctx->status == PLAY) {
        switch(e.type) {
          case SDL_KEYDOWN:
            switch (e.key.keysym.sym) {
              case SDLK_LEFT:
                if (!CollisionDetected(ctx, -1, 0)) {
                  changed = true;
                  MoveTetromino(ctx, -1, 0);
                }
                break;
              case SDLK_RIGHT:
                if (!CollisionDetected(ctx, 1, 0)) {
                  changed = true;
                  MoveTetromino(ctx, 1, 0);
                }
                break;
              case SDLK_DOWN:
                if (!CollisionDetected(ctx, 0, 1)) {
                  changed = true;
                  MoveTetromino(ctx, 0, 1);
                }
                break;
              case SDLK_SPACE:
                while (!CollisionDetected(ctx, 0, 1)) {
                  changed = true;
                  MoveTetromino(ctx, 0, 1);
                }
                break;
              case SDLK_UP:
                changed = Rotate(ctx);
                break;
              default:
                break;
            }
        }
      }
    }
    if (ctx->status == PLAY) {
      if (game_ticks >= drop_ticks + MAX(15 - ctx->completed_lines / 3, 1)) {
        changed = true;
        drop_ticks = game_ticks;
        if (!CollisionDetected(ctx, 0, 1)) {
          MoveTetromino(ctx, 0, 1);
        } else {
          ClearBoard(ctx);
          ctx->current_orientation = 0;
          ctx->current_piece = ctx->next_piece;
          ctx->next_piece = 1 + (random() % NUM_TETROMINOS);
          if (AddBoardPiece(ctx)) {
            ctx->status = GAMEOVER;
          }
        }
      }
    }
    if (changed) {
      DrawBoard(renderer, ctx);
      DrawStatus(renderer, ctx);
      SDL_RenderPresent(renderer);
      CHECK_SDLI(SDL_RenderClear(renderer), "SDL_Render_Clear", SDL_GetError);
    }
    Uint64 now_ms = SDL_GetTicks();
    if ((now_ms - last_frame_ms) >= ms_per_frame) {
      ++game_ticks;
      last_frame_ms = now_ms;
    }
    SDL_Delay(1);
  }

  // Game over.
  Mix_PlayChannel(0, ctx->music.gameover, 0);
  DrawBoard(renderer, ctx);
  DrawStatus(renderer, ctx);
  // Clear a rectangle for the game-over message and write the message.
  SDL_Rect msgbox = {.x=0, .y=ctx->height_px*0.4375, .w=ctx->width_px, .h=ctx->height_px*0.125};
  SDL_RenderCopy(renderer, ctx->graphics.block_black, NULL, &msgbox);
  const char msg[37] = "The only winning move is not to play";
  DrawText(renderer, ctx, msg, ctx->width_px*0.05, ctx->height_px*0.4375, ctx->width_px*0.9, ctx->height_px*0.125);
  SDL_RenderPresent(renderer);
  while (true) {
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
        case SDL_KEYDOWN:
          switch (e.key.keysym.sym) {
            case SDLK_ESCAPE:
            case SDLK_q:
              return;
          }
          break;
        case SDL_QUIT:
          return;
      }
    }
    SDL_Delay(10);
  }
}

int main(int argc, char** argv) {
  unsigned int level = 0;
  if (argc > 1) {
    level = strtoul(argv[1], NULL, 10);
  }
  GameContext ctx = {.width=10, .height=20, .block_size=96, .framerate=60, .status=PLAY, .completed_lines=MIN(45, level * 3)};
  ctx.width_px = ctx.width*ctx.block_size + 50 + 6*ctx.block_size;
  ctx.height_px = ctx.height*ctx.block_size;
  CHECK_SDLP(ctx.board = calloc(ctx.height, sizeof(int*)), "calloc", tstrerror);
  for (int i = 0; i < ctx.height; ++i) {
    CHECK_SDLP(ctx.board[i] = calloc(ctx.width, sizeof(int*)), "calloc", tstrerror);
  }
  CHECK_SDLI(SDL_Init(SDL_INIT_AUDIO | SDL_INIT_EVENTS | SDL_INIT_TIMER | SDL_INIT_VIDEO), "SDL_Init", SDL_GetError);
  SDL_Window* window = NULL;
  SDL_Renderer* renderer = NULL;
  CHECK_SDLI(SDL_CreateWindowAndRenderer(ctx.width_px, ctx.height_px, SDL_WINDOW_SHOWN, &window, &renderer), "Window", SDL_GetError);
  SDL_SetWindowTitle(window, "TETRIS");

  CHECK_SDLI((IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG) == IMG_INIT_PNG ? 0 : -1, "IMG_Init", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_black  = IMG_LoadTexture(renderer, "graphics/block_black.png"),  "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_blue   = IMG_LoadTexture(renderer, "graphics/block_blue.png"),   "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_cyan   = IMG_LoadTexture(renderer, "graphics/block_cyan.png"),   "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_green  = IMG_LoadTexture(renderer, "graphics/block_green.png"),  "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_orange = IMG_LoadTexture(renderer, "graphics/block_orange.png"), "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_purple = IMG_LoadTexture(renderer, "graphics/block_purple.png"), "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_red    = IMG_LoadTexture(renderer, "graphics/block_red.png"),    "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.block_yellow = IMG_LoadTexture(renderer, "graphics/block_yellow.png"), "IMG_LoadTexture", SDL_GetError);
  ctx.graphics.blocks[0] = ctx.graphics.block_black;
  ctx.graphics.blocks[1] = ctx.graphics.block_blue;
  ctx.graphics.blocks[2] = ctx.graphics.block_cyan;
  ctx.graphics.blocks[3] = ctx.graphics.block_green;
  ctx.graphics.blocks[4] = ctx.graphics.block_orange;
  ctx.graphics.blocks[5] = ctx.graphics.block_purple;
  ctx.graphics.blocks[6] = ctx.graphics.block_red;
  ctx.graphics.blocks[7] = ctx.graphics.block_yellow;
  CHECK_SDLP(ctx.graphics.gameover     = IMG_LoadTexture(renderer, "graphics/gameover.png"),     "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.logo         = IMG_LoadTexture(renderer, "graphics/logo.png"),         "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLP(ctx.graphics.wall         = IMG_LoadTexture(renderer, "graphics/wall.png"),         "IMG_LoadTexture", SDL_GetError);
  CHECK_SDLI(Mix_OpenAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 4096), "Mix_OpenAudio", Mix_GetError);
  CHECK_SDLP(ctx.music.song_korobeiniki  = Mix_LoadWAV("sound/korobeiniki.wav"),  "Mix_LoadWAV", Mix_GetError);
  CHECK_SDLP(ctx.music.song_bwv814menuet = Mix_LoadWAV("sound/bwv814menuet.wav"), "Mix_LoadWAV", Mix_GetError);
  CHECK_SDLP(ctx.music.song_russiansong  = Mix_LoadWAV("sound/russiansong.wav"),  "Mix_LoadWAV", Mix_GetError);
  CHECK_SDLP(ctx.music.gameover          = Mix_LoadWAV("sound/gameover.wav"),     "Mix_LoadWAV", Mix_GetError);
  CHECK_SDLI(Mix_PlayChannel(0, ctx.music.song_bwv814menuet, -1), "Mix_PlayChannel", SDL_GetError);

  CHECK_SDLI(TTF_Init(),"TTF_Init", TTF_GetError);
  CHECK_SDLP(ctx.font = TTF_OpenFont("fonts/Montserrat-Regular.ttf", 48), "TTF_OpenFont", TTF_GetError);

  printf("\n"
"TETЯIS: \n\n"
"  usage: %s [level 1-15]\n\n"
"  F1  - Korobeiniki (gameboy song A).\n"
"  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).\n"
"  F3  - Russion song (gameboy song C).\n"
"  ESC - Quit.\n"
"  p   - Pause.\n\n"
"  Up - Rotate.\n"
"  Down - Lower.\n"
"  Space - Drop completely.\n\n", *argv);

  srandom(time(NULL));
  ctx.current_orientation = 0;
  ctx.current_piece = 1 + (random() % NUM_TETROMINOS);
  ctx.next_piece = 1 + (random() % NUM_TETROMINOS);
  AddBoardPiece(&ctx);
  GameLoop(window, renderer, &ctx);

  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  return EXIT_SUCCESS;
}
