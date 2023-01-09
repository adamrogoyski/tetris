(* Author: Adam Rogoyski (adam@rogoyski.com).
   Public domain software.

   A tetris game. *)
program Tetris(input, output);

uses
  math,
  SDL2,
  SDL2_Image,
  SDL2_Mixer,
  SDL2_TTF,
  sysutils;

const
  width = 10;
  height = 20;
  block_size = 96;
  width_px = (width + 6) * block_size + 50;
  height_px = height * block_size;
  frame_rate_ms = 1000 div 60;

type
  status = (IN_PLAY, PAUSE, GAMEOVER);
  STARTPOS_t = array [0..6] of array [0..3] of array [0..1] of integer;
  ROTATIONS_t = array [0..6] of array [0..3] of array [0..3] of array [0..1] of integer;
  ROW_t = array[0..width-1] of integer;
  BOARD_t = array[0..height-1] of ROW_t;
  COORDS_t = array [0..3] of array [0..1] of integer;
  GameContext = record
    current_piece: integer;
    current_orientation: integer;
    current_coords: COORDS_t;
    next_piece: integer;
    state: status;
    board: BOARD_t;
    completed_lines: integer;
  end;

const
  (* Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates. *)
  starting_positions: STARTPOS_t = (
    ((-1,0), (-1,1), (0,1), (1,1)),  (* Leftward L piece. *)
    ((-1,1), (0,1),  (0,0), (1,0)),  (* Rightward Z piece. *)
    ((-2,0), (-1,0), (0,0), (1,0)),  (* Long straight piece. *)
    ((-1,1), (0,1),  (0,0), (1,1)),  (* Bump in middle piece. *)
    ((-1,1), (0,1),  (1,1), (1,0)),  (* L piece. *)
    ((-1,0), (0,0),  (0,1), (1,1)),  (* Z piece. *)
    ((-1,0), (-1,1), (0,0), (0,1))   (* Square piece. *)
  );
  (* Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
     Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
     For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
     The coordinate diffs map each block to its new location.
     Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation. *)
  rotations: ROTATIONS_t = (
    (* Leftward L piece. *)
    (((0,2),  (1,1),   (0,0), (-1,-1)),
     ((2,0),  (1,-1),  (0,0), (-1,1)),
     ((0,-2), (-1,-1), (0,0), (1,1)),
     ((-2,0), (-1,1),  (0,0), (1,-1))),
    (* Rightward Z piece. Orientation symmetry: 0==2 and 1==3. *)
    (((1,0),  (0,1),  (-1,0), (-2,1)),
     ((-1,0), (0,-1), (1,0),  (2,-1)),
     ((1,0),  (0,1),  (-1,0), (-2,1)),
     ((-1,0), (0,-1), (1,0),  (2,-1))),
    (* Long straight piece. Orientation symmetry: 0==2 and 1==3. *)
    (((2,-2), (1,-1), (0,0), (-1,1)),
     ((-2,2), (-1,1), (0,0), (1,-1)),
     ((2,-2), (1,-1), (0,0), (-1,1)),
     ((-2,2), (-1,1), (0,0), (1,-1))),
    (* Bump in middle piece. *)
    (((1,1),   (0,0), (-1,1),  (-1,-1)),
     ((1,-1),  (0,0), (1,1),   (-1,1)),
     ((-1,-1), (0,0), (1,-1),  (1,1)),
     ((-1,1),  (0,0), (-1,-1), (1,-1))),
    (* L Piece. *)
    (((1,1),   (0,0), (-1,-1), (-2,0)),
     ((1,-1),  (0,0), (-1,1),  (0,2)),
     ((-1,-1), (0,0), (1,1),   (2,0)),
     ((-1,1),  (0,0), (1,-1),  (0,-2))),
    (* Z piece. Orientation symmetry: 0==2 and 1==3. *)
    (((1,0),  (0,1),  (-1,0), (-2,1)),
     ((-1,0), (0,-1), (1,0),  (2,-1)),
     ((1,0),  (0,1),  (-1,0), (-2,1)),
     ((-1,0), (0,-1), (1,0),  (2,-1))),
    (* Square piece. Orientation symmetry: 0==1==2==3. *)
    (((0,0), (0,0), (0,0), (0,0)),
     ((0,0), (0,0), (0,0), (0,0)),
     ((0,0), (0,0), (0,0), (0,0)),
     ((0,0), (0,0), (0,0), (0,0)))
  );

var
  window: PSDL_Window;
  renderer: PSDL_Renderer;

  block_black: PSDL_Texture;
  block_blue: PSDL_Texture;
  block_cyan: PSDL_Texture;
  block_green: PSDL_Texture;
  block_orange: PSDL_Texture;
  block_purple: PSDL_Texture;
  block_red: PSDL_Texture;
  block_yellow: PSDL_Texture;
  blocks: array [0..7] of PSDL_Texture;
  logo: PSDL_Texture;
  wall: PSDL_Texture;

  font : PTTF_Font;
  red: TSDL_Color;

  song_bwv814menuet: PMix_Chunk;
  song_korobeiniki:  PMix_Chunk;
  song_russiansong:  PMix_Chunk;
  sound_gameover:    PMix_Chunk;
  ctx: GameContext;

Procedure DrawText(x, y, w, h: integer; s: AnsiString);
var
  stext: PSDL_Surface;
  text: PSDL_Texture;
  dst: TSDL_Rect;
begin
  stext := TTF_RenderText_Solid(font, PChar(s), red);
  text := SDL_CreateTextureFromSurface(renderer, stext);
  if text = nil then begin Writeln(SDL_GetError); Halt; end;
  dst.x := x;  dst.y := y;  dst.w := w;  dst.h := h;
  SDL_RenderCopy(renderer, text, nil, @dst);
  SDL_FreeSurface(stext);
  SDL_DestroyTexture(text);
end;

procedure DrawStatus();
var
  dst: TSDL_Rect;
  i, x, y: integer;
  left_border, status_width, top_border: SmallInt;
begin
  (* Wall extends from top to bottom, separating the board from the status area. *)
  dst.x := width * block_size; dst.y := 0; dst.w := 50; dst.h := height*block_size;
  SDL_RenderCopy(renderer, wall, nil, @dst);

  (* The logo sits at the top right of the screen right of the wall. *)
  left_border := width * block_size + 50 + round(6*block_size*0.05);
  status_width := round(6 * block_size * 0.90);
  dst.x := left_border; dst.y := 0; dst.w := status_width; dst.h := round(height_px*0.20);
  SDL_RenderCopy(renderer, logo, nil, @dst);

  (* Write the number of completed lines. *)
  DrawText(left_border, round(height_px*0.25), status_width, round(height_px*0.05), Concat('Lines: ', IntToStr(ctx.completed_lines)));

  (* Write the current game level. *)
  DrawText(left_border, round(height_px*0.35), status_width, round(height_px*0.05), Concat('Level: ', IntToStr(ctx.completed_lines div 3)));

  (* Draw the next tetromino piece. *)
  for i := 0 to 3 do
  begin
    top_border := round(height_px * 0.45);
    left_border := (width+2)*block_size + 50 + round(6*block_size*0.05);
    x := left_border + starting_positions[ctx.next_piece-1][i][0]*block_size;
    y := top_border + starting_positions[ctx.next_piece-1][i][1]*block_size;
    dst.x := x; dst.y := y; dst.w := block_size; dst.h := block_size;
    SDL_RenderCopy(renderer, blocks[ctx.next_piece], nil, @dst);
  end;
end;

procedure DrawBoard();
var
  x, y: integer;
  dst: TSDL_Rect;
begin
  for y := 0 to height-1 do
    for x := 0 to width-1 do
    begin
      dst.x := x * block_size; dst.y := y * block_size; dst.w := block_size; dst.h := block_size;
      SDL_RenderCopy(renderer, blocks[ctx.board[y][x]], nil, @dst);
    end;
end;

procedure DrawScreen();
begin
  DrawBoard;
  DrawStatus;
  SDL_RenderPresent(renderer);
end;

procedure PlayMusic(song: PMix_Chunk; loop: boolean);
var
  do_loop: integer;
begin
  do_loop := 0;
  if loop then
    do_loop := -1;
  if Mix_PlayChannel(0, song, do_loop) < 0 then begin Writeln(SDL_GetError); Halt; end;
end;

procedure Init();
var
  x, y, level_adjust: integer;
begin
  if SDL_Init(SDL_INIT_AUDIO or SDL_INIT_EVENTS or SDL_INIT_TIMER or SDL_INIT_VIDEO) < 0 then Halt;
  if SDL_CreateWindowAndRenderer(width_px, height_px, SDL_WINDOW_SHOWN, @window, @renderer) <> 0 then Halt;
  SDL_Delay(10);
  RandSeed := SDL_GetTicks;

  block_black  := IMG_LoadTexture(renderer, 'graphics/block_black.png');  if block_black  = nil then Halt;
  block_blue   := IMG_LoadTexture(renderer, 'graphics/block_blue.png');   if block_blue   = nil then Halt;
  block_cyan   := IMG_LoadTexture(renderer, 'graphics/block_cyan.png');   if block_cyan   = nil then Halt;
  block_green  := IMG_LoadTexture(renderer, 'graphics/block_green.png');  if block_green  = nil then Halt;
  block_orange := IMG_LoadTexture(renderer, 'graphics/block_orange.png'); if block_orange = nil then Halt;
  block_purple := IMG_LoadTexture(renderer, 'graphics/block_purple.png'); if block_purple = nil then Halt;
  block_red    := IMG_LoadTexture(renderer, 'graphics/block_red.png');    if block_red    = nil then Halt;
  block_yellow := IMG_LoadTexture(renderer, 'graphics/block_yellow.png'); if block_yellow = nil then Halt;
  blocks[0] := block_black;
  blocks[1] := block_blue;
  blocks[2] := block_cyan;
  blocks[3] := block_green;
  blocks[4] := block_orange;
  blocks[5] := block_purple;
  blocks[6] := block_red;
  blocks[7] := block_yellow;
  wall := IMG_LoadTexture(renderer, 'graphics/wall.png'); if wall = nil then Halt;
  logo := IMG_LoadTexture(renderer, 'graphics/logo.png'); if wall = nil then Halt;

  if Mix_OpenAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 4096) < 0 then Halt;
  song_bwv814menuet := Mix_LoadWAV('sound/bwv814menuet.wav'); if song_bwv814menuet = nil then begin Writeln(SDL_GetError); Halt; end;
  song_korobeiniki  := Mix_LoadWAV('sound/korobeiniki.wav');  if song_korobeiniki  = nil then begin Writeln(SDL_GetError); Halt; end;
  song_russiansong  := Mix_LoadWAV('sound/russiansong.wav');  if song_russiansong  = nil then begin Writeln(SDL_GetError); Halt; end;
  sound_gameover    := Mix_LoadWAV('sound/gameover.wav');     if sound_gameover    = nil then begin Writeln(SDL_GetError); Halt; end;
  PlayMusic(song_korobeiniki, true);

  if TTF_Init = -1 then HALT;
  font := TTF_OpenFont('fonts/Montserrat-Regular.ttf', 48);
  if font = nil then begin Writeln(SDL_GetError); HALT; end;
  red.r := 255; red.g := 0; red.b := 0;

  ctx.state := IN_PLAY;
  ctx.current_piece := Random(7) + 1;
  ctx.next_piece := Random(7) + 1;
  ctx.current_orientation := 0;
  ctx.completed_lines := 0;
  if argc > 1 then
    ctx.completed_lines := StrToInt(argv[1])*3;
  for y := 0 to height-1 do
    for x := 0 to width-1 do
      ctx.board[y][x] := 0
end;


function AddBoardPiece(): boolean;
const
  center: integer = width div 2;
var
  i, x, y: integer;
begin
  for i := 0 to 3 do
  begin
    x := center + starting_positions[ctx.current_piece-1][i][0];
    y := starting_positions[ctx.current_piece-1][i][1];
    if ctx.board[y][x] <> 0 then
      Exit(true);
  end;
  for i := 0 to 3 do
  begin
    x := center + starting_positions[ctx.current_piece-1][i][0];
    y := starting_positions[ctx.current_piece-1][i][1];
    ctx.board[y][x] := ctx.current_piece;
    ctx.current_coords[i][0] := x;
    ctx.current_coords[i][1] := y;
  end;
  AddBoardPiece := false;
end;

procedure MoveTetromino(dx, dy: integer);
var
  i, x, y: integer;
begin
  (* Clear the board where the piece currently is. *)
  for i := 0 to 3 do
  begin
    x := ctx.current_coords[i][0];
    y := ctx.current_coords[i][1];
    ctx.board[y][x] := 0;
  end;
  (* Update the current piece's coordinates and fill the board in the new coordinates. *)
  for i := 0 to 3 do
  begin
    ctx.current_coords[i][0] := ctx.current_coords[i][0] + dx;
    ctx.current_coords[i][1] := ctx.current_coords[i][1] + dy;
    ctx.board[ctx.current_coords[i][1]][ctx.current_coords[i][0]] := ctx.current_piece;
  end
end;

procedure SetCoords(coords: COORDS_t; piece: integer);
var
  i: integer;
begin
  for i := 0 to 3 do
    ctx.board[coords[i][1]][coords[i][0]] := piece;
end;


function CollisionDetected(dx, dy: integer): boolean;
var
  i, x, y: integer;
begin
  CollisionDetected := false;
  (* Clear the board where the piece currently is to not detect self collision. *)
  SetCoords(ctx.current_coords, 0);
  for i := 0 to 3 do
  begin
    x := ctx.current_coords[i][0];
    y := ctx.current_coords[i][1];
    (* Collision is hitting the left wall, right wall, bottom, or a non-black block.
       Since this collision detection is only for movement, check the top (y < 0) is not needed. *)
    if ((x + dx) < 0) or ((x + dx) >= width) or ((y + dy) >= height) or (ctx.board[y+dy][x+dx] <> 0) then
    begin
      CollisionDetected := true;
      break;
    end;
  end;
  (* Restore the current piece. *)
  SetCoords(ctx.current_coords, ctx.current_piece);
end;

function Rotate(): boolean;
type
  ROTATION_t = array [0..3] of array [0..1] of integer;
var
  rotation: ^ROTATION_t;
  new_coords: COORDS_t;
  i, x, y: integer;
begin
  rotation := @rotations[ctx.current_piece-1][ctx.current_orientation];
  for i := 0 to 3 do
  begin
    new_coords[i][0] := ctx.current_coords[i][0] + rotation^[i][0];
    new_coords[i][1] := ctx.current_coords[i][1] + rotation^[i][1];
  end;

  (* Clear the board where the piece currently is to not detect self collision. *)
  SetCoords(ctx.current_coords, 0);
  for i := 0 to 3 do
  begin;
    x := new_coords[i][0];
    y := new_coords[i][1];
    (* Collision is hitting the left wall, right wall, top, bottom, or a non-black block. *)
    if (x < 0) or (x >= width) or (y < 0) or (y >= height) or (ctx.board[y][x] <> 0) then
    begin
      (* Restore the current piece. *)
      SetCoords(ctx.current_coords, ctx.current_piece);
      Exit(false);
    end;
  end;

  for i := 0 to 3 do
  begin
    ctx.current_coords[i][0] := new_coords[i][0];
    ctx.current_coords[i][1] := new_coords[i][1];
    ctx.board[new_coords[i][1]][new_coords[i][0]] := ctx.current_piece;
  end;
  ctx.current_orientation := (ctx.current_orientation + 1) mod 4;
  Rotate := true;
end;

(* Clear completed (filled) rows.
   Start from the bottom of the board, moving all rows down to fill in a completed row, with
   the completed row cleared and placed at the top. *)
procedure ClearBoard();
var
  row, rows_deleted, x, y: integer;
  has_hole: boolean;
  deleted_row: ^ROW_t;
begin
  rows_deleted := 0;
  row := height - 1;
  while row >= rows_deleted do
  begin
    has_hole := false;
    x := 0;
    while (x < width) and (not has_hole) do
    begin
      has_hole := ctx.board[row][x] = 0;
      x := x + 1;
    end;
    if not has_hole then
    begin
      deleted_row := @ctx.board[row];
      y := row;
      while y > rows_deleted do
      begin
        ctx.board[y] := ctx.board[y-1];
        y := y - 1;
      end;
      ctx.board[rows_deleted] := deleted_row^;
      for y := 0 to width -1 do
        ctx.board[rows_deleted][y] := 0;
      rows_deleted := rows_deleted + 1;
    end else
      row := row - 1;
  end;
  ctx.completed_lines := ctx.completed_lines + rows_deleted;
end;

procedure GameLoop();
var
  e: PSDL_Event;
  last_frame_ms: longint;
  now_ms: longint;
  game_ticks, drop_ticks: longint;
  changed: boolean;
  dst: TSDL_Rect;
begin
  new(e);
  game_ticks := 0;
  drop_ticks := 0;
  last_frame_ms := 0;
  repeat
    changed := false;
    while SDL_PollEvent(e) = 1 do
    begin
      case (e^.type_) of
        SDL_KEYDOWN:
          case e^.key.keysym.sym of
            SDLK_ESCAPE, SDLK_q: Halt;
            SDLK_p: if ctx.state = IN_PLAY then ctx.state := PAUSE else ctx.state := IN_PLAY;
            SDLK_F1: PlayMusic(song_bwv814menuet, true);
            SDLK_F2: PlayMusic(song_korobeiniki, true);
            SDLK_F3: PlayMusic(song_russiansong, true);
          end;
      end;
      if ctx.state = IN_PLAY then
        case (e^.type_) of
          SDL_KEYDOWN:
          begin
            case e^.key.keysym.sym of
              SDLK_LEFT:
                begin
                  if not CollisionDetected(-1, 0) then
                  begin
                    changed := true;
                    MoveTetromino(-1, 0);
                  end;
                end;
              SDLK_RIGHT:
                begin
                  if not CollisionDetected(1, 0) then
                  begin
                    changed := true;
                    MoveTetromino(1, 0);
                  end;
                end;
              SDLK_DOWN:
                begin
                  if not CollisionDetected(0, 1) then
                  begin
                    changed := true;
                    MoveTetromino(0, 1);
                  end;
                end;
              SDLK_SPACE:
                while not CollisionDetected(0, 1) do
                begin
                  changed := true;
                  MoveTetromino(0, 1);
                end;
              SDLK_UP:
                begin
                  changed := true;
                  Rotate;
                end;
            end;
          end;
        end;
    end;
    if ctx.state = IN_PLAY then
    begin
      if game_ticks >= drop_ticks + Max(15 - (ctx.completed_lines div 3), 1) then
      begin
        drop_ticks := game_ticks;
        changed := true;
        if not CollisionDetected(0, 1) then
        begin
          MoveTetromino(0, 1);
        end else
        begin
          ClearBoard;
          ctx.current_orientation := 0;
          ctx.current_piece := ctx.next_piece;
          ctx.next_piece := Random(7) + 1;
          if AddBoardPiece then
            ctx.state := GAMEOVER;
        end;
      end;
    end;
    now_ms := SDL_GetTicks;
    if now_ms - last_frame_ms > frame_rate_ms then
    begin
      last_frame_ms := now_ms;
      game_ticks := game_ticks + 1;
    end;
    if changed then
    begin
      DrawScreen;
      SDL_RenderClear(renderer);
    end;
    SDL_Delay(10);
  until ctx.state = GAMEOVER;

  (* Game over. *)
  PlayMusic(sound_gameover, false);
  DrawScreen;
  (* Clear a rectangle for the game-over message and write the message. *)
  dst.x := 0;
  dst.y := round(height_px*0.4375);
  dst.w := width_px;
  dst.h := round(height_px*0.125);
  SDL_RenderCopy(renderer, block_black, nil, @dst);
  DrawText(round(width_px*0.05), round(height_px*0.4375), round(width_px*0.9), round(height_px*0.125), 'The only winning move is not to play');
  SDL_RenderPresent(renderer);
  while true do
  begin
    while SDL_PollEvent(e) = 1 do
    begin
      case (e^.type_) of
        SDL_KEYDOWN:
          case e^.key.keysym.sym of
            SDLK_ESCAPE, SDLK_q: Halt;
          end;
      end;
    end;
  end;
end;

procedure EndGame();
begin
  SDL_DestroyTexture(block_black);
  SDL_DestroyTexture(block_blue);
  SDL_DestroyTexture(block_cyan);
  SDL_DestroyTexture(block_green);
  SDL_DestroyTexture(block_orange);
  SDL_DestroyTexture(block_purple);
  SDL_DestroyTexture(block_red);
  SDL_DestroyTexture(block_yellow);
  TTF_CloseFont(font);
  TTF_Quit;
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit;
end;

begin
  Init;
  Writeln('');
  Writeln('TETЯIS:');
  Writeln;
  Writeln('  usage: ', argv[0], ' [level 1-15]');
  Writeln;
  Writeln('  F1  - Korobeiniki (gameboy song A).');
  Writeln('  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).');
  Writeln('  F3  - Russion song (gameboy song C).');
  Writeln('  ESC - Quit.');
  Writeln('  p   - Pause.');
  Writeln;
  Writeln('  Up - Rotate.');
  Writeln('  Down - Lower.');
  Writeln('  Space - Drop completely.');
  Writeln;
  AddBoardPiece;
  DrawScreen;
  GameLoop;
  EndGame;
end.
