// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

package main

import "fmt"
import "math/rand"
import "os"
import "time"
import "github.com/veandco/go-sdl2/img"
import "github.com/veandco/go-sdl2/mix"
import "github.com/veandco/go-sdl2/sdl"
import "github.com/veandco/go-sdl2/ttf"

const NUM_TETROMINOS = 7
const framerate = 60

func CHECK(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(1)
	}
}

var starting_positions [NUM_TETROMINOS][4][2]int = [NUM_TETROMINOS][4][2]int{
	{{-1, 0}, {-1, 1}, {0, 1}, {1, 1}}, // Leftward L piece.
	{{-1, 1}, {0, 1}, {0, 0}, {1, 0}},  // Rightward Z piece.
	{{-2, 0}, {-1, 0}, {0, 0}, {1, 0}}, // Long straight piece.
	{{-1, 1}, {0, 1}, {0, 0}, {1, 1}},  // Bump in middle piece.
	{{-1, 1}, {0, 1}, {1, 1}, {1, 0}},  // L piece.
	{{-1, 0}, {0, 0}, {0, 1}, {1, 1}},  // Z piece.
	{{-1, 0}, {-1, 1}, {0, 0}, {0, 1}}, // Square piece.
}

// Slice of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
// Each rotation is an slice of 4 rotations -- one for each orientation of a tetromino.
// For each rotation, there is a slice of 4 (int x, int y) coordinate diffs for each block of the tetromino.
// The coordinate diffs map each block to its new location.
// Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
var rotations [NUM_TETROMINOS][4][4][2]int = [NUM_TETROMINOS][4][4][2]int{
	// Leftward L piece.
	{{{0, 2}, {1, 1}, {0, 0}, {-1, -1}},
		{{2, 0}, {1, -1}, {0, 0}, {-1, 1}},
		{{0, -2}, {-1, -1}, {0, 0}, {1, 1}},
		{{-2, 0}, {-1, 1}, {0, 0}, {1, -1}}},
	// Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
	{{{1, 0}, {0, 1}, {-1, 0}, {-2, 1}},
		{{-1, 0}, {0, -1}, {1, 0}, {2, -1}},
		{{1, 0}, {0, 1}, {-1, 0}, {-2, 1}},
		{{-1, 0}, {0, -1}, {1, 0}, {2, -1}}},
	// Long straight piece. Orientation symmetry: 0==2 and 1==3.
	{{{2, -2}, {1, -1}, {0, 0}, {-1, 1}},
		{{-2, 2}, {-1, 1}, {0, 0}, {1, -1}},
		{{2, -2}, {1, -1}, {0, 0}, {-1, 1}},
		{{-2, 2}, {-1, 1}, {0, 0}, {1, -1}}},
	// Bump in middle piece.
	{{{1, 1}, {0, 0}, {-1, 1}, {-1, -1}},
		{{1, -1}, {0, 0}, {1, 1}, {-1, 1}},
		{{-1, -1}, {0, 0}, {1, -1}, {1, 1}},
		{{-1, 1}, {0, 0}, {-1, -1}, {1, -1}}},
	// L Piece.
	{{{1, 1}, {0, 0}, {-1, -1}, {-2, 0}},
		{{1, -1}, {0, 0}, {-1, 1}, {0, 2}},
		{{-1, -1}, {0, 0}, {1, 1}, {2, 0}},
		{{-1, 1}, {0, 0}, {1, -1}, {0, -2}}},
	// Z piece. Orientation symmetry: 0==2 and 1==3.
	{{{1, 0}, {0, 1}, {-1, 0}, {-2, 1}},
		{{-1, 0}, {0, -1}, {1, 0}, {2, -1}},
		{{1, 0}, {0, 1}, {-1, 0}, {-2, 1}},
		{{-1, 0}, {0, -1}, {1, 0}, {2, -1}}},
	// Square piece. Orientation symmetry: 0==1==2==3.
	{{{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		{{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		{{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		{{0, 0}, {0, 0}, {0, 0}, {0, 0}}},
}

type Coords [4][2]int

type Status int

const (
	PLAY Status = iota
	PAUSE
	GAMEOVER
)

type GameContext struct {
	width, height, block_size                      int
	current_orientation, current_piece, next_piece int
	current_coords                                 Coords
	completed_lines                                int
	game_ticks, drop_ticks                         int
	window                                         *sdl.Window
	renderer                                       *sdl.Renderer
	state                                          Status
	graphics                                       struct {
		block_black  *sdl.Texture
		block_blue   *sdl.Texture
		block_cyan   *sdl.Texture
		block_green  *sdl.Texture
		block_orange *sdl.Texture
		block_purple *sdl.Texture
		block_red    *sdl.Texture
		block_yellow *sdl.Texture
		blocks       [8]*sdl.Texture
		gameover     *sdl.Texture
		logo         *sdl.Texture
		wall         *sdl.Texture
	}
	music struct {
		song_korobeiniki  *mix.Chunk
		song_bwv814menuet *mix.Chunk
		song_russiansong  *mix.Chunk
		gameover          *mix.Chunk
	}
	font  *ttf.Font
	board [][]int
}

func (ctx *GameContext) WidthPx() int32  { return int32((ctx.width+6)*ctx.block_size + 50) }
func (ctx *GameContext) HeightPx() int32 { return int32(ctx.height * ctx.block_size) }

func (ctx *GameContext) Init() {
	var err error
	CHECK(sdl.Init(sdl.INIT_AUDIO | sdl.INIT_EVENTS | sdl.INIT_TIMER | sdl.INIT_VIDEO))
	ctx.window, ctx.renderer, err = sdl.CreateWindowAndRenderer(ctx.WidthPx(), ctx.HeightPx(), sdl.WINDOW_SHOWN)
	CHECK(err)
	ctx.window.SetTitle("TETЯIS")

	CHECK(img.Init(img.INIT_PNG))
	ctx.graphics.block_black, err = img.LoadTexture(ctx.renderer, "graphics/block_black.png")
	CHECK(err)
	ctx.graphics.block_blue, err = img.LoadTexture(ctx.renderer, "graphics/block_blue.png")
	CHECK(err)
	ctx.graphics.block_cyan, err = img.LoadTexture(ctx.renderer, "graphics/block_cyan.png")
	CHECK(err)
	ctx.graphics.block_green, err = img.LoadTexture(ctx.renderer, "graphics/block_green.png")
	CHECK(err)
	ctx.graphics.block_orange, err = img.LoadTexture(ctx.renderer, "graphics/block_orange.png")
	CHECK(err)
	ctx.graphics.block_purple, err = img.LoadTexture(ctx.renderer, "graphics/block_purple.png")
	CHECK(err)
	ctx.graphics.block_red, err = img.LoadTexture(ctx.renderer, "graphics/block_red.png")
	CHECK(err)
	ctx.graphics.block_yellow, err = img.LoadTexture(ctx.renderer, "graphics/block_yellow.png")
	CHECK(err)
	ctx.graphics.blocks[0] = ctx.graphics.block_black
	ctx.graphics.blocks[1] = ctx.graphics.block_blue
	ctx.graphics.blocks[2] = ctx.graphics.block_cyan
	ctx.graphics.blocks[3] = ctx.graphics.block_green
	ctx.graphics.blocks[4] = ctx.graphics.block_orange
	ctx.graphics.blocks[5] = ctx.graphics.block_purple
	ctx.graphics.blocks[6] = ctx.graphics.block_red
	ctx.graphics.blocks[7] = ctx.graphics.block_yellow
	ctx.graphics.logo, err = img.LoadTexture(ctx.renderer, "graphics/logo.png")
	CHECK(err)
	ctx.graphics.wall, err = img.LoadTexture(ctx.renderer, "graphics/wall.png")
	CHECK(err)

	mix.OpenAudio(mix.DEFAULT_FREQUENCY, mix.DEFAULT_FORMAT, mix.DEFAULT_CHANNELS, 4096)
	ctx.music.song_korobeiniki, err = mix.LoadWAV("sound/korobeiniki.wav")
	CHECK(err)
	ctx.music.song_bwv814menuet, err = mix.LoadWAV("sound/bwv814menuet.wav")
	CHECK(err)
	ctx.music.song_russiansong, err = mix.LoadWAV("sound/russiansong.wav")
	CHECK(err)
	ctx.music.gameover, err = mix.LoadWAV("sound/gameover.wav")
	CHECK(err)
	_, err = ctx.music.song_bwv814menuet.Play(0, -1)
	CHECK(err)

	CHECK(ttf.Init())
	ctx.font, err = ttf.OpenFont("fonts/Montserrat-Regular.ttf", 48)
	CHECK(err)

	ctx.next_piece = 1 + (rand.Intn(NUM_TETROMINOS) % NUM_TETROMINOS)

	ctx.board = make([][]int, ctx.height)
	for i := range ctx.board {
		ctx.board[i] = make([]int, ctx.width)
	}
	ctx.state = PLAY
}

func (ctx *GameContext) End() {
	ctx.renderer.Destroy()
	ctx.window.Destroy()
	sdl.Quit()
}

func (ctx *GameContext) AddBoardPiece() {
	ctx.current_orientation = 0
	ctx.current_piece = ctx.next_piece
	ctx.next_piece = 1 + (rand.Intn(NUM_TETROMINOS) % NUM_TETROMINOS)
	var update [4]struct {
		X, Y int
	}

	center := ctx.width / 2
	for i := 0; i < 4; i++ {
		x := center + starting_positions[ctx.current_piece-1][i][0]
		y := starting_positions[ctx.current_piece-1][i][1]
		if ctx.board[y][x] != 0 {
			ctx.state = GAMEOVER
			return
		}
		update[i].X = x
		update[i].Y = y
	}
	for i := 0; i < 4; i++ {
		ctx.board[update[i].Y][update[i].X] = ctx.current_piece
		ctx.current_coords[i][0] = update[i].X
		ctx.current_coords[i][1] = update[i].Y
	}
}

func (ctx *GameContext) MoveTetromino(dx, dy int) {
	// Clear the board where the piece currently is.
	for i := 0; i < 4; i++ {
		x := ctx.current_coords[i][0]
		y := ctx.current_coords[i][1]
		ctx.board[y][x] = 0
	}
	// Update the current piece's coordinates and fill the board in the new coordinates.
	for i := 0; i < 4; i++ {
		ctx.current_coords[i][0] += dx
		ctx.current_coords[i][1] += dy
		ctx.board[ctx.current_coords[i][1]][ctx.current_coords[i][0]] = ctx.current_piece
	}
}

func (ctx *GameContext) SetCoords(coords *Coords, piece int) {
	for i := 0; i < 4; i++ {
		ctx.board[coords[i][1]][coords[i][0]] = piece
	}
}

func (ctx *GameContext) CollisionDetected(dx, dy int) bool {
	collision := false
	// Clear the board where the piece currently is to not detect self collision.
	ctx.SetCoords(&ctx.current_coords, 0)
	for i := 0; i < 4; i++ {
		x := ctx.current_coords[i][0]
		y := ctx.current_coords[i][1]
		// Collision is hitting the left wall, right wall, bottom, or a non-black block.
		// Since this collision detection is only for movement, check the top (y < 0) is not needed.
		if (x+dx) < 0 || (x+dx) >= ctx.width || (y+dy) >= ctx.height || ctx.board[y+dy][x+dx] != 0 {
			collision = true
			break
		}
	}
	// Restore the current piece.
	ctx.SetCoords(&ctx.current_coords, ctx.current_piece)
	return collision
}

func (ctx *GameContext) Rotate() bool {
	var new_coords Coords
	rotation := rotations[ctx.current_piece-1][ctx.current_orientation]
	for i := 0; i < 4; i++ {
		new_coords[i][0] = ctx.current_coords[i][0] + rotation[i][0]
		new_coords[i][1] = ctx.current_coords[i][1] + rotation[i][1]
	}

	// Clear the board where the piece currently is to not detect self collision.
	ctx.SetCoords(&ctx.current_coords, 0)
	for i := 0; i < 4; i++ {
		x := new_coords[i][0]
		y := new_coords[i][1]
		// Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
		if x < 0 || x >= ctx.width || y < 0 || y >= ctx.height || ctx.board[y][x] != 0 {
			// Restore the current piece.
			ctx.SetCoords(&ctx.current_coords, ctx.current_piece)
			return false
		}
	}

	for i := 0; i < 4; i++ {
		ctx.current_coords[i][0] = new_coords[i][0]
		ctx.current_coords[i][1] = new_coords[i][1]
		ctx.board[new_coords[i][1]][new_coords[i][0]] = ctx.current_piece
	}
	ctx.current_orientation = (ctx.current_orientation + 1) % 4
	return true
}

// Clear completed (filled) rows.
// Start from the bottom of the board, moving all rows down to fill in a completed row, with
// the completed row cleared and placed at the top.
func (ctx *GameContext) ClearBoard() {
	rows_deleted := 0
	for row := ctx.height - 1; row >= rows_deleted; {
		has_hole := false
		for x := 0; x < ctx.width && !has_hole; x++ {
			has_hole = ctx.board[row][x] == 0
		}
		if !has_hole {
			var deleted_row []int = ctx.board[row]
			for y := row; y > rows_deleted; y-- {
				ctx.board[y] = ctx.board[y-1]
			}
			ctx.board[rows_deleted] = deleted_row
			for r := 0; r < ctx.width; r++ {
				ctx.board[rows_deleted][r] = 0
			}
			rows_deleted++
		} else {
			row--
		}
	}
	ctx.completed_lines += rows_deleted
}

func (ctx *GameContext) DrawBoard() {
	for y := 0; y < ctx.height; y++ {
		for x := 0; x < ctx.width; x++ {
			dst := sdl.Rect{X: int32(x * ctx.block_size), Y: int32(y * ctx.block_size), W: int32(ctx.block_size), H: int32(ctx.block_size)}
			ctx.renderer.Copy(ctx.graphics.blocks[ctx.board[y][x]], nil, &dst)
		}
	}
}

func (ctx *GameContext) DrawText(s string, x, y, w, h int32) {
	red := sdl.Color{R: 255, G: 0, B: 0, A: 255}
	stext, err := ctx.font.RenderUTF8Solid(s, red)
	CHECK(err)
	text, err := ctx.renderer.CreateTextureFromSurface(stext)
	CHECK(err)
	dsttext := sdl.Rect{X: x, Y: y, W: w, H: h}
	ctx.renderer.Copy(text, nil, &dsttext)
	stext.Free()
	text.Destroy()
}

func (ctx *GameContext) DrawStatus() {
	// Wall extends from top to bottom, separating the board from the status area.
	dstwall := sdl.Rect{X: int32(ctx.width * ctx.block_size), Y: 0, W: 50, H: ctx.HeightPx()}
	ctx.renderer.Copy(ctx.graphics.wall, nil, &dstwall)

	// The logo sits at the top right of the screen right of the wall.
	dstlogo := sdl.Rect{X: int32(ctx.width*ctx.block_size + 60), Y: 20, W: 99, H: 44}
	ctx.renderer.Copy(ctx.graphics.logo, nil, &dstlogo)

	// Write the number of completed lines.
	ctx.DrawText(fmt.Sprintf("Lines: %d", ctx.completed_lines), int32(ctx.width*ctx.block_size+60), 100, 100, 50)

	// Write the current game level.
	ctx.DrawText(fmt.Sprintf("Level: %d", ctx.completed_lines/3), int32(ctx.width*ctx.block_size+60), 180, 100, 50)

	// Draw the next tetromino piece.
	for i := 0; i < 4; i++ {
		x := (starting_positions[ctx.next_piece-1][i][0])*ctx.block_size + ctx.width*ctx.block_size + 4*ctx.block_size
		y := starting_positions[ctx.next_piece-1][i][1]*ctx.block_size + Max(4, ctx.height/2-1)*ctx.block_size
		dst := sdl.Rect{X: int32(x), Y: int32(y), W: int32(ctx.block_size), H: int32(ctx.block_size)}
		ctx.renderer.Copy(ctx.graphics.blocks[ctx.next_piece], nil, &dst)
	}

}

func (ctx *GameContext) DrawScreen() {
	ctx.DrawBoard()
	ctx.DrawStatus()
	if ctx.state == GAMEOVER {
		// Clear a rectangle for the game-over message and write the message.
		msgbox := sdl.Rect{X: 0, Y: int32(float32(ctx.HeightPx()) * 0.4375), W: ctx.WidthPx(), H: int32(float32(ctx.HeightPx()) * 0.125)}
		ctx.renderer.Copy(ctx.graphics.block_black, nil, &msgbox)
		ctx.DrawText("The only winning move is not to play", int32(float32(ctx.WidthPx())*0.05), int32(float32(ctx.HeightPx())*0.4375), int32(float32(ctx.WidthPx())*0.9), int32(float32(ctx.HeightPx())*0.125))
	}
	ctx.renderer.Present()
	CHECK(ctx.renderer.Clear())
}

func (ctx *GameContext) GameOver() bool {
	return ctx.state == GAMEOVER
}

func (ctx *GameContext) IsInPlay() bool {
	return ctx.state == PLAY
}

func (ctx *GameContext) Pause() {
	if ctx.state == PLAY {
		ctx.state = PAUSE
	} else {
		ctx.state = PLAY
	}
}

func Max(x, y int) int {
	if x > y {
		return x
	}
	return y
}

func (ctx *GameContext) DropCheck() bool {
	if ctx.game_ticks >= ctx.drop_ticks+Max(15-ctx.completed_lines/3, 1) {
		ctx.drop_ticks = ctx.game_ticks
		return true
	}
	return false
}

func (ctx *GameContext) TimeKeep(now_ms uint32, last_frame_ms uint32) uint32 {
	var ms_per_frame uint32 = 1000 / framerate
	if (now_ms - last_frame_ms) >= ms_per_frame {
		ctx.game_ticks++
		return now_ms
	}
	return last_frame_ms
}

func GameLoop(ctx *GameContext) {
	var last_frame_ms uint32
	for !ctx.GameOver() {
		changed := false
		for e := sdl.PollEvent(); e != nil; e = sdl.PollEvent() {
			switch t := e.(type) {
			case *sdl.KeyboardEvent:
				if e.GetType() == sdl.KEYDOWN {
					switch t.Keysym.Sym {
					case sdl.K_ESCAPE:
						return
					case sdl.K_q:
						return
					case sdl.K_p:
						ctx.Pause()
					case sdl.K_F1:
						_, err := ctx.music.song_korobeiniki.Play(0, -1)
						CHECK(err)
					case sdl.K_F2:
						_, err := ctx.music.song_bwv814menuet.Play(0, -1)
						CHECK(err)
					case sdl.K_F3:
						_, err := ctx.music.song_russiansong.Play(0, -1)
						CHECK(err)
					}
				}
			case *sdl.QuitEvent:
				return
			}
			if ctx.IsInPlay() {
				switch t := e.(type) {
				case *sdl.KeyboardEvent:
					if e.GetType() == sdl.KEYDOWN {
						switch t.Keysym.Sym {
						case sdl.K_LEFT:
							if !ctx.CollisionDetected(-1, 0) {
								ctx.MoveTetromino(-1, 0)
								changed = true
							}
						case sdl.K_RIGHT:
							if !ctx.CollisionDetected(1, 0) {
								ctx.MoveTetromino(1, 0)
								changed = true
							}
						case sdl.K_DOWN:
							if !ctx.CollisionDetected(0, 1) {
								ctx.MoveTetromino(0, 1)
								changed = true
							}
						case sdl.K_SPACE:
							for !ctx.CollisionDetected(0, 1) {
								ctx.MoveTetromino(0, 1)
								changed = true
							}
						case sdl.K_UP:
							changed = ctx.Rotate()
						}
					}
				}
			}
		}
		if ctx.IsInPlay() {
			if ctx.DropCheck() {
				changed = true
				if !ctx.CollisionDetected(0, 1) {
					ctx.MoveTetromino(0, 1)
				} else {
					ctx.ClearBoard()
					ctx.AddBoardPiece()
				}
			}
		}
		if changed {
			ctx.DrawScreen()
		}
		last_frame_ms = ctx.TimeKeep(sdl.GetTicks(), last_frame_ms)
		sdl.Delay(1)
	}

	// Game over.
	_, err := ctx.music.gameover.Play(0, 0)
	CHECK(err)
	ctx.DrawScreen()
	for {
		for e := sdl.PollEvent(); e != nil; e = sdl.PollEvent() {
			switch t := e.(type) {
			case *sdl.KeyboardEvent:
				if e.GetType() == sdl.KEYDOWN {
					switch t.Keysym.Sym {
					case sdl.K_ESCAPE:
						return
					case sdl.K_q:
						return
					}
				}
			case *sdl.QuitEvent:
				return
			}
			sdl.Delay(10)
		}
	}
}

func main() {
	rand.Seed(time.Now().UnixNano())
	fmt.Printf(`
TETЯIS:

  usage: %s [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.`+"\n", os.Args[0])

	ctx := GameContext{width: 10, height: 20, block_size: 96}
	ctx.Init()
	ctx.AddBoardPiece()
	ctx.DrawScreen()
	GameLoop(&ctx)
	ctx.End()
}
