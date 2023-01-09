// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

#include <algorithm>
#include <cerrno>
#include <functional>
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <unistd.h>
#include <sys/param.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_mixer.h>
#include <SDL2/SDL_ttf.h>

const int NUM_TETROMINOS = 7;

typedef int Coords[4][2];
typedef int (*CoordsPtr)[2];

void CHECK_SDLI(int ret, const char* const msg, const char* (* const GetError)()) {
  if (ret < 0) {
    std::cerr << msg << ": " << GetError() << std::endl;
    exit(EXIT_FAILURE);
  }
}

void CHECK_SDLP(void* ret, const char* const msg, const char* (* const GetError)()) {
  if (!ret) {
    std::cerr << msg << ": " << GetError() << std::endl;
    exit(EXIT_FAILURE);
  }
}

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

void SetCoords(int** board, const CoordsPtr coords, const int piece) {
  for (int i = 0; i < 4; ++i) {
    board[coords[i][1]][coords[i][0]] = piece;
  }
}

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

class GameContext {
 public:
  GameContext(const int level=0, const int width=10, const int height=20, const int block_size=96, const int framerate=60)
   : width_(width),
     height_(height),
     width_px_(width*block_size + 50 + 6*block_size),
     height_px_(height*block_size),
     block_size_(block_size),
     framerate_(framerate),
     board_(new int*[height_]()),
     completed_lines_(std::min(45, level * 3)),
     status_(Status::PLAY),
     game_ticks_(0),
     drop_ticks_(0) {
    for (int i = 0; i < height_; ++i) {
      board_[i] = new int[width_]();
    }
    current_orientation_ = 0;
    current_piece_ = 1 + (random() % NUM_TETROMINOS);
    next_piece_ = 1 + (random() % NUM_TETROMINOS);

    CHECK_SDLI(SDL_Init(SDL_INIT_AUDIO | SDL_INIT_EVENTS | SDL_INIT_TIMER | SDL_INIT_VIDEO), "SDL_Init", SDL_GetError);
    CHECK_SDLI(SDL_CreateWindowAndRenderer(width_px_, height_px_, SDL_WINDOW_SHOWN, &window_, &renderer_), "Window", SDL_GetError);
    SDL_SetWindowTitle(window_, "TETRIS");

    CHECK_SDLI((IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG) == IMG_INIT_PNG ? 0 : -1, "IMG_Init", SDL_GetError);
    CHECK_SDLP(graphics_.block_black  = IMG_LoadTexture(renderer_, "graphics/block_black.png"),  "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_blue   = IMG_LoadTexture(renderer_, "graphics/block_blue.png"),   "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_cyan   = IMG_LoadTexture(renderer_, "graphics/block_cyan.png"),   "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_green  = IMG_LoadTexture(renderer_, "graphics/block_green.png"),  "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_orange = IMG_LoadTexture(renderer_, "graphics/block_orange.png"), "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_purple = IMG_LoadTexture(renderer_, "graphics/block_purple.png"), "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_red    = IMG_LoadTexture(renderer_, "graphics/block_red.png"),    "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.block_yellow = IMG_LoadTexture(renderer_, "graphics/block_yellow.png"), "IMG_LoadTexture", SDL_GetError);
    graphics_.blocks[0] = graphics_.block_black;
    graphics_.blocks[1] = graphics_.block_blue;
    graphics_.blocks[2] = graphics_.block_cyan;
    graphics_.blocks[3] = graphics_.block_green;
    graphics_.blocks[4] = graphics_.block_orange;
    graphics_.blocks[5] = graphics_.block_purple;
    graphics_.blocks[6] = graphics_.block_red;
    graphics_.blocks[7] = graphics_.block_yellow;
    CHECK_SDLP(graphics_.logo         = IMG_LoadTexture(renderer_, "graphics/logo.png"),         "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLP(graphics_.wall         = IMG_LoadTexture(renderer_, "graphics/wall.png"),         "IMG_LoadTexture", SDL_GetError);
    CHECK_SDLI(Mix_OpenAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 4096), "Mix_OpenAudio", Mix_GetError);
    CHECK_SDLP(music_.song_korobeiniki  = Mix_LoadWAV("sound/korobeiniki.wav"),  "Mix_LoadWAV", Mix_GetError);
    CHECK_SDLP(music_.song_bwv814menuet = Mix_LoadWAV("sound/bwv814menuet.wav"), "Mix_LoadWAV", Mix_GetError);
    CHECK_SDLP(music_.song_russiansong  = Mix_LoadWAV("sound/russiansong.wav"),  "Mix_LoadWAV", Mix_GetError);
    CHECK_SDLP(music_.gameover          = Mix_LoadWAV("sound/gameover.wav"),     "Mix_LoadWAV", Mix_GetError);
    music_.songs[0] = music_.song_korobeiniki;
    music_.songs[1] = music_.song_bwv814menuet;
    music_.songs[2] = music_.song_russiansong;
    music_.songs[3] = music_.gameover;
    CHECK_SDLI(Mix_PlayChannel(0, music_.song_korobeiniki, -1), "Mix_PlayChannel", SDL_GetError);

    CHECK_SDLI(TTF_Init(),"TTF_Init", TTF_GetError);
    CHECK_SDLP(font_ = TTF_OpenFont("fonts/Montserrat-Regular.ttf", 48), "TTF_OpenFont", TTF_GetError);
  }

  ~GameContext() {
    SDL_DestroyRenderer(renderer_);
    SDL_DestroyWindow(window_);
    SDL_Quit();
  }

  bool ExecuteBoardPiece(void (GameContext::*execute)(int, int, int)) {
    const int center = width_ / 2;
    for (int i = 0; i < 4; ++i) {
      const int x = center + starting_positions[current_piece_-1][i][0];
      const int y = starting_positions[current_piece_-1][i][1];
      if (board_[y][x]) {
        return true;
      }
      std::invoke(execute, this, i, x, y);
    }
    return false;
  }

  void NullPlacement(int i, int x, int y) { }

  void ActivePlacement(const int i, const int x, const int y) {
    board_[y][x] = current_piece_;
    current_coords_[i][0] = x;
    current_coords_[i][1] = y;
  }

  // Sets the game over condition if adding a new piece collides. Checks game-over before adding piece to the board
  // so the final piece is not written to the screen with a collision.
  void AddBoardPiece() {
    current_orientation_ = 0;
    current_piece_ = next_piece_;
    next_piece_ = 1 + (random() % NUM_TETROMINOS);
    if (ExecuteBoardPiece(&GameContext::NullPlacement)) {
      status_ = Status::GAMEOVER;
    } else {
      ExecuteBoardPiece(&GameContext::ActivePlacement);
    }
  }

  void TimeKeep(Uint64 now_ms, Uint64* last_frame_ms) {
    Uint64 ms_per_frame = 1000 / framerate_;
    if ((now_ms - *last_frame_ms) >= ms_per_frame) {
      ++game_ticks_;
      *last_frame_ms = now_ms;
    }
  }

  bool IsGameOver() const { return status_ == Status::GAMEOVER; }

  bool IsInPlay() const { return status_ == Status::PLAY; }

  void PlayMusic(int choice, bool loop) const {
    choice = std::max(std::min(choice, 3), 0);
    Mix_PlayChannel(0, music_.songs[choice], loop);
  }

  enum Songs {KOROBEINIKI, BWV814MENUET, RUSSIANSONG, GAMEOVERSONG};

  void DrawScreen() {
    DrawBoard();
    DrawStatus();
    if (status_ == Status::GAMEOVER) {
      // Clear a rectangle for the game-over message and write the message.
      SDL_Rect msgbox = {.x=0, .y=static_cast<int>(height_px_*0.4375), .w=width_px_, .h=static_cast<int>(height_px_*0.125)};
      SDL_RenderCopy(renderer_, graphics_.block_black, nullptr, &msgbox);
      const char msg[37] = "The only winning move is not to play";
      DrawText(msg, width_px_*0.05, height_px_*0.4375, width_px_*0.9, height_px_*0.125);
    }
    SDL_RenderPresent(renderer_);
    CHECK_SDLI(SDL_RenderClear(renderer_), "SDL_Render_Clear", SDL_GetError);
  }

  void Pause() {
    switch (status_) {
      case PLAY:
        status_ = PAUSE;
        break;
      case PAUSE:
        status_ = PLAY;
        break;
      default:
        break;
    }
  }

  bool DropCheck() {
    if (game_ticks_ >= drop_ticks_ + std::max(15 - completed_lines_ / 3, 1)) {
      drop_ticks_ = game_ticks_;
      return true;
    }
    return false;
  }

  bool CollisionDetected(const int dx, const int dy) {
    bool collision = false;
    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(board_, current_coords_, 0);
    for (int i = 0; i < 4; ++i) {
      const int x = current_coords_[i][0];
      const int y = current_coords_[i][1];
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if ((x + dx) < 0 || (x + dx) >= width_ || (y + dy) >= height_ || board_[y+dy][x+dx]) {
        collision = true;
        break;
      }
    }
    // Restore the current piece.
    SetCoords(board_, current_coords_, current_piece_);
    return collision;
  }

  void MoveTetromino(const int dx, const int dy) {
    // Clear the board where the piece currently is.
    for (int i = 0; i < 4; ++i) {
      const int x = current_coords_[i][0];
      const int y = current_coords_[i][1];
      board_[y][x] = 0;
    }
    // Update the current piece's coordinates and fill the board in the new coordinates.
    for (int i = 0; i < 4; ++i) {
      current_coords_[i][0] += dx;
      current_coords_[i][1] += dy;
      board_[current_coords_[i][1]][current_coords_[i][0]] = current_piece_;
    }
  }

  // Clear completed (filled) rows.
  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  void ClearBoard() {
    int rows_deleted = 0;
    for (int row = height_ - 1; row >= rows_deleted;) {
      bool has_hole = false;
      for (int x = 0; x < width_ && !has_hole; ++x) {
        has_hole = !board_[row][x];
      }
      if (!has_hole) {
        int* deleted_row = board_[row];
        for (int y = row; y > rows_deleted; --y) {
          board_[y] = board_[y-1];
        }
        board_[rows_deleted] = deleted_row;
        memset(board_[rows_deleted], 0, width_ * sizeof(int));
        ++rows_deleted;
      } else {
        --row;
      }
    }
    completed_lines_ += rows_deleted;
  }

  bool Rotate() {
    Coords new_coords;
    const int (* const rotation)[2] = rotations[current_piece_-1][current_orientation_];
    for (int i = 0; i < 4; ++i) {
      new_coords[i][0] = current_coords_[i][0] + rotation[i][0];
      new_coords[i][1] = current_coords_[i][1] + rotation[i][1];
    }

    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(board_, current_coords_, 0);
    for (int i = 0; i < 4; ++i) {
      const int x = new_coords[i][0];
      const int y = new_coords[i][1];
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if (x < 0 || x >= width_ || y < 0 || y >= height_ || board_[y][x]) {
        // Restore the current piece.
        SetCoords(board_, current_coords_, current_piece_);
        return false;
      }
    }

    for (int i = 0; i < 4; ++i) {
      current_coords_[i][0] = new_coords[i][0];
      current_coords_[i][1] = new_coords[i][1];
      board_[new_coords[i][1]][new_coords[i][0]] = current_piece_;
    }
    current_orientation_ = (current_orientation_ + 1) % 4;
    return true;
  }

 private:
  void DrawBoard() {
    for (int y = 0; y < height_; ++y) {
      for (int x = 0; x < width_; ++x) {
        SDL_Rect dst = {.x=x*block_size_, .y=y*block_size_, .w=block_size_, .h=block_size_};
        SDL_RenderCopy(renderer_, graphics_.blocks[board_[y][x]], nullptr, &dst);
      }
    }
  }

  void DrawText(const char* const s, const int x, const int y, const int w, const int h) {
    SDL_Color red = {.r=255, .g=0, .b=0, .a=255};
    SDL_Surface* stext = TTF_RenderText_Solid(font_, s, red);
    SDL_Texture* text;
    CHECK_SDLP(text = SDL_CreateTextureFromSurface(renderer_, stext), "Render text", SDL_GetError);
    SDL_Rect dsttext = {.x=x, .y=y, .w=w, .h=h};
    SDL_RenderCopy(renderer_, text, nullptr, &dsttext);
    SDL_FreeSurface(stext);
    SDL_DestroyTexture(text);
  }

  void DrawStatus() {
    // Wall extends from top to bottom, separating the board from the status area.
    SDL_Rect dstwall = {.x=width_*block_size_, .y=0, .w=50, .h=height_*block_size_};
    SDL_RenderCopy(renderer_, graphics_.wall, NULL, &dstwall);

    // The logo sits at the top right of the screen right of the wall.
    const int left_border = width_*block_size_ + 50 + 6*block_size_*0.05;
    const int width = 6*block_size_*0.90;
    SDL_Rect dstlogo = {.x=left_border, .y=0, .w=width, .h=static_cast<int>(height_px_*0.20)};
    SDL_RenderCopy(renderer_, graphics_.logo, NULL, &dstlogo);

    // Write the number of completed lines.
    char text_lines[12];
    snprintf(text_lines, sizeof(text_lines), "Lines: %d", completed_lines_);
    DrawText(text_lines, left_border, height_px_*0.25, width, height_px_*0.05);

    // Write the current game level.
    snprintf(text_lines, sizeof(text_lines), "Level: %d", completed_lines_ / 3);
    DrawText(text_lines, left_border, height_px_*0.35, width, height_px_*0.05);

    // Draw the next tetromino piece.
    for (int i = 0; i < 4; ++i) {
      const int top_border = height_px_ * 0.45;
      const int left_border = (width_ + 2)*block_size_ + 50 + 6*block_size_*0.05;
      const int x = left_border + starting_positions[next_piece_-1][i][0]*block_size_;
      const int y = top_border + starting_positions[next_piece_-1][i][1]*block_size_;
      SDL_Rect dst = {.x=x, .y=y, .w=block_size_, .h=block_size_};
      SDL_RenderCopy(renderer_, graphics_.blocks[next_piece_], NULL, &dst);
    }
  }

  // Width and height are of the playing board, whereas width_px and height_px are for the whole screen, which includes status.
  const int width_;
  const int height_;
  const int width_px_;
  const int height_px_;
  const int block_size_;
  const int framerate_;
  int **board_;
  int current_piece_;
  int current_orientation_;
  Coords current_coords_;
  int next_piece_;
  int completed_lines_;
  enum Status {PLAY, PAUSE, GAMEOVER} status_;
  Uint64 game_ticks_;
  Uint64 drop_ticks_;
  struct {
    Mix_Chunk* song_korobeiniki;
    Mix_Chunk* song_bwv814menuet;
    Mix_Chunk* song_russiansong;
    Mix_Chunk* gameover;
    Mix_Chunk* songs[4];
  } music_;
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
  } graphics_;
  SDL_Window* window_;
  SDL_Renderer* renderer_;
  TTF_Font* font_;
};

void GameLoop(GameContext* ctx) {
  SDL_Event e;
  Uint64 last_frame_ms = SDL_GetTicks();
  while (!ctx->IsGameOver()) {
    bool changed = false;
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
        case SDL_KEYDOWN:
          switch (e.key.keysym.sym) {
            case SDLK_ESCAPE:
            case SDLK_q:
              return;
            case SDLK_p:
              ctx->Pause();
              break;
            case SDLK_F1:
              ctx->PlayMusic(GameContext::Songs::KOROBEINIKI, -1);
              break;
            case SDLK_F2:
              ctx->PlayMusic(GameContext::Songs::BWV814MENUET, -1);
              break;
            case SDLK_F3:
              ctx->PlayMusic(GameContext::Songs::RUSSIANSONG, -1);
              break;
          }
          break;
        case SDL_QUIT:
          return;
      }
      if (ctx->IsInPlay()) {
        switch(e.type) {
          case SDL_KEYDOWN:
            switch (e.key.keysym.sym) {
              case SDLK_LEFT:
                if (!ctx->CollisionDetected(-1, 0)) {
                  changed = true;
                  ctx->MoveTetromino(-1, 0);
                }
                break;
              case SDLK_RIGHT:
                if (!ctx->CollisionDetected(1, 0)) {
                  changed = true;
                  ctx->MoveTetromino(1, 0);
                }
                break;
              case SDLK_DOWN:
                if (!ctx->CollisionDetected(0, 1)) {
                  changed = true;
                  ctx->MoveTetromino(0, 1);
                }
                break;
              case SDLK_SPACE:
                while (!ctx->CollisionDetected(0, 1)) {
                  changed = true;
                  ctx->MoveTetromino(0, 1);
                }
                break;
              case SDLK_UP:
                changed = ctx->Rotate();
                break;
              default:
                break;
            }
        }
      }
    }
    if (ctx->IsInPlay()) {
      if (ctx->DropCheck()) {
        changed = true;
        if (!ctx->CollisionDetected(0, 1)) {
          ctx->MoveTetromino(0, 1);
        } else {
          ctx->ClearBoard();
          ctx->AddBoardPiece();
        }
      }
    }
    if (changed) {
      ctx->DrawScreen();
    }
    ctx->TimeKeep(SDL_GetTicks(), &last_frame_ms);
    SDL_Delay(1);
  }

  // Game over.
  ctx->PlayMusic(GameContext::Songs::GAMEOVERSONG, 0);
  ctx->DrawScreen();
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
  unsigned long level = 0;
  if (argc > 1) {
    level = strtoul(argv[1], nullptr, 0);
  }
  srandom(time(nullptr));

  std::cout << "\n"
"TETЯIS: \n\n"
"  usage: " << *argv << " [level 1-15]\n\n"
"  F1  - Korobeiniki (gameboy song A).\n"
"  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).\n"
"  F3  - Russion song (gameboy song C).\n"
"  ESC - Quit.\n"
"  p   - Pause.\n\n"
"  Up - Rotate.\n"
"  Down - Lower.\n"
"  Space - Drop completely.\n\n";

  GameContext ctx(level);
  ctx.AddBoardPiece();
  ctx.DrawScreen();
  GameLoop(&ctx);
  return EXIT_SUCCESS;
}
