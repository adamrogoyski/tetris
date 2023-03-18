// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.

extern crate sdl2;
use std::time::Instant;
use rand::thread_rng;
use rand::rngs::ThreadRng;
use rand::Rng;
use rand::distributions::Uniform;
use sdl2::Sdl;
use sdl2::event::Event;
use sdl2::keyboard::Keycode;
use sdl2::image::{InitFlag, LoadTexture};
use sdl2::pixels::Color;
use sdl2::rect::Rect;
use sdl2::render::{TextureCreator, Canvas};
use sdl2::ttf::Font;
use sdl2::video::Window;
use sdl2::video::WindowContext;
use std::time::Duration;
use std::error::Error;

const NUM_TETROMINOS : usize = 7;
const FRAME_RATE_MS : u128 = 1000 / 60;
type Coords = [[i8; 2]; 4];

#[derive(PartialEq)]
pub enum State { PLAY, PAUSE, GAMEOVER }

pub struct Graphics<'a> {
  blocks: Vec<sdl2::render::Texture<'a>>,
  logo: sdl2::render::Texture<'a>,
  wall: sdl2::render::Texture<'a>,
}

impl Graphics<'_> {
  pub fn new<'a>(tc : &'a TextureCreator<WindowContext>) -> Graphics<'a> {
    Graphics {
      blocks: vec![tc.load_texture("graphics/block_black.png").unwrap(),
                   tc.load_texture("graphics/block_blue.png").unwrap(),
                   tc.load_texture("graphics/block_cyan.png").unwrap(),
                   tc.load_texture("graphics/block_green.png").unwrap(),
                   tc.load_texture("graphics/block_orange.png").unwrap(),
                   tc.load_texture("graphics/block_purple.png").unwrap(),
                   tc.load_texture("graphics/block_red.png").unwrap(),
                   tc.load_texture("graphics/block_yellow.png").unwrap()],
      logo: tc.load_texture("graphics/logo.png").unwrap(),
      wall: tc.load_texture("graphics/wall.png").unwrap(),
    }
  }
}

pub struct GameContext<'a> {
  width: u32,
  height: u32,
  block_size: u32,
  width_px: u32,
  height_px: u32,
  completed_lines: u32,
  state: State,
  current_orientation: u8,
  current_coords: Coords,
  current_piece: u8,
  next_piece: u8,
  board: Vec<Vec<u8>>,
  sound_bwv814menuet: sdl2::mixer::Music<'a>,
  sound_korobeiniki: sdl2::mixer::Music<'a>,
  sound_russiansong: sdl2::mixer::Music<'a>,
  sound_gameover: sdl2::mixer::Music<'a>,
  sdl_ctx: Sdl,
  canvas: Canvas<Window>,
  rng: ThreadRng,
}

impl GameContext<'_> {
  pub fn new<'a>(width : u32, height: u32, block_size: u32, completed_lines: u32) -> Result<GameContext<'a>, Box<dyn std::error::Error>> {
    let sdl_ctx = sdl2::init()?;
    let video_subsystem: sdl2::VideoSubsystem;
    video_subsystem = sdl_ctx.video()?;
    let _image_ctx = sdl2::image::init(InitFlag::PNG)?;
    sdl2::mixer::open_audio(44_100, sdl2::mixer::AUDIO_S16LSB, sdl2::mixer::DEFAULT_CHANNELS, 1_024)?;
    sdl2::mixer::init(sdl2::mixer::InitFlag::MP3)?;

    let width_px = width * block_size + 50 + 6*block_size;
    let height_px = height * block_size;
    let window = video_subsystem.window("TETЯIS", width_px, height_px)
        .position_centered()
        .build()?;

    Ok(GameContext {
          width,
          height,
          block_size,
          height_px,
          width_px,
          completed_lines,
          state: State::PLAY,
          board: vec![vec![0; width as usize]; height as usize],
          current_orientation: 0,
          current_coords: [[0; 2]; 4],
          current_piece: thread_rng().sample(Uniform::new(0, NUM_TETROMINOS as u8)),
          next_piece: thread_rng().sample(Uniform::new(0, NUM_TETROMINOS as u8)),
          sound_bwv814menuet: sdl2::mixer::Music::from_file("sound/bwv814menuet.wav").unwrap(),
          sound_korobeiniki:  sdl2::mixer::Music::from_file("sound/korobeiniki.wav").unwrap(),
          sound_russiansong:  sdl2::mixer::Music::from_file("sound/russiansong.wav").unwrap(),
          sound_gameover:     sdl2::mixer::Music::from_file("sound/gameover.wav").unwrap(),
          sdl_ctx: sdl_ctx,
          canvas: window.into_canvas().build()?,
          rng: thread_rng(),
    })
  }

  pub fn add_board_piece(&mut self) -> bool {
    let coords = &STARTING_POSITIONS[self.current_piece as usize];
    let center = (self.width / 2) as i8;
    for i in 0..4 {
      let x = center + coords[i as usize][0 as usize];
      let y = coords[i as usize][1 as usize];
      if self.board[y as usize][x as usize] != 0 {
        return true;
      }
    }
    for i in 0..4 {
      let x = center + coords[i as usize][0 as usize];
      let y = coords[i as usize][1 as usize];
      self.board[y as usize][x as usize] = self.current_piece + 1;
      self.current_coords[i][0] = x;
      self.current_coords[i][1] = y;
    }
    return false;
  }

  fn set_coords(&mut self, piece : u8) {
    for i in 0..4 {
      self.board[self.current_coords[i][1] as usize][self.current_coords[i][0] as usize] = piece;
    }
  }

  pub fn collision_detected(&mut self, dx : i8, dy : i8) -> bool {
    let mut collision = false;
    // Clear the board where the piece currently is to not detect self collision.
    self.set_coords(0);
    for i in 0..4 {
      let x = self.current_coords[i][0];
      let y = self.current_coords[i][1];
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if (x + dx) < 0 || (x + dx) >= self.width as i8 || (y + dy) >= self.height as i8 || self.board[(y+dy) as usize][(x+dx) as usize] != 0 {
        collision = true;
        break;
      }
    }
    // Restore the current piece.
    self.set_coords(self.current_piece + 1);
    collision
  }

  pub fn move_tetromino(&mut self, dx : i8, dy : i8) {
    // Clear the board where the piece currently is.
    for i in 0..4 {
      let x = self.current_coords[i][0] as usize;
      let y = self.current_coords[i][1] as usize;
      self.board[y][x] = 0;
    }
      // Update the current piece's coordinates and fill the board in the new coordinates.
    for i in 0..4 {
      self.current_coords[i][0] += dx as i8;
      self.current_coords[i][1] += dy as i8;
      self.board[self.current_coords[i][1] as usize][self.current_coords[i][0] as usize] = self.current_piece + 1;
    }
  }

  pub fn rotate(&mut self) -> bool {
    let mut new_coords : Coords = [[0; 2]; 4];
    let rotation = &ROTATIONS[self.current_piece as usize][self.current_orientation as usize];
    for i in 0..4 {
      new_coords[i][0] = self.current_coords[i][0] + rotation[i][0];
      new_coords[i][1] = self.current_coords[i][1] + rotation[i][1];
    }

    // Clear the board where the piece currently is to not detect self collision.
    self.set_coords(0);
    for i in 0..4 {
      let x = new_coords[i][0];
      let y = new_coords[i][1];
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if x < 0 || x >= self.width as i8 || y < 0 || y >= self.height as i8 || self.board[y as usize][x as usize] != 0 {
        // Restore the current piece.
        self.set_coords(self.current_piece + 1);
        return false;
      }
    }

    for i in 0..4 {
      self.current_coords[i][0] = new_coords[i][0];
      self.current_coords[i][1] = new_coords[i][1];
      self.board[new_coords[i][1] as usize][new_coords[i][0] as usize] = self.current_piece + 1;
    }
    self.current_orientation = (self.current_orientation + 1) % 4;
    return true;
  }

  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  pub fn clear_board(&mut self) {
    let mut rows_deleted = 0;
    let mut row : i32 = (self.height - 1) as i32;
    while row >= rows_deleted {
      let mut has_hole = false;
      let mut x = 0;
      while x < self.width && !has_hole {
        has_hole = self.board[row as usize][x as usize] == 0;
        x += 1;
      }
      if !has_hole {
        let deleted_row = self.board[row as usize].to_owned();
        let mut y = row;
        while y > rows_deleted {
          self.board[y as usize] = self.board[y as usize -1].to_owned();
          y -= 1;
        }
        self.board[rows_deleted as usize] = deleted_row.to_vec();
        self.board[rows_deleted as usize] = vec![0; self.width as usize];
        rows_deleted += 1;
      } else {
        row -= 1;
      }
    }
    self.completed_lines += rows_deleted as u32;
  }

  pub fn draw_screen(&mut self, gfx : &Graphics, font: &Font) {
    self.canvas.clear();
    self.canvas.set_draw_color(Color::RGB(0, 0, 0));

    // Wall extends from top to bottom, separating the board from the status area.
    self.canvas.copy(&gfx.wall, None, Some(Rect::new((self.width*self.block_size) as i32, 0, 50, self.height_px))).ok();

    // The logo sits at the top right of the screen right of the wall.
    let left_border = ((self.width*self.block_size + 50) + (((6*self.block_size) as f32) * 0.05) as u32) as i32;
    let width = ((6*self.block_size) as f32 * 0.90) as u32;
    let wall_height = (self.height_px as f32 * 0.20) as u32;
    self.canvas.copy(&gfx.logo, None, Some(Rect::new(left_border, 0, width, wall_height))).ok();

    // Write the number of completed lines.
    let texture_creator = self.canvas.texture_creator();
    let mut text_surface = font.render(format!("Lines: {:2}", self.completed_lines).as_str()).blended(Color::RGBA(255, 0, 0, 255)).ok();
    let mut text_texture = texture_creator.create_texture_from_surface(&text_surface.as_ref().unwrap()).ok();
    let mut text_ypos = (self.height_px as f32 * 0.25) as i32;
    let text_height = (self.height_px as f32 * 0.05) as u32;
    self.canvas.copy(&text_texture.as_ref().unwrap(), None, Some(Rect::new(left_border, text_ypos, width, text_height))).ok();

    // Write the current game level.
    text_surface = font.render(format!("Level: {:2}", self.completed_lines / 3).as_str()).blended(Color::RGBA(255, 0, 0, 255)).ok();
    text_texture = texture_creator.create_texture_from_surface(&text_surface.as_ref().unwrap()).ok();
    text_ypos = (self.height_px as f32 * 0.35) as i32;
    self.canvas.copy(&text_texture.as_ref().unwrap(), None, Some(Rect::new(left_border, text_ypos, width, text_height))).ok();

    // Draw the next tetromino piece.
    for i in 0..4 as usize {
      let top_border = (self.height_px as f32 * 0.45) as i32;
      let left_border = ((self.width + 2)*self.block_size + 50) as i32 + ((6*self.block_size) as f32 * 0.05) as i32;
      let x = left_border + STARTING_POSITIONS[(self.next_piece) as usize][i][0] as i32 * self.block_size as i32;
      let y = top_border + STARTING_POSITIONS[(self.next_piece) as usize][i][1] as i32 * self.block_size as i32;
      self.canvas.copy(&gfx.blocks[(self.next_piece + 1) as usize], None, Some(Rect::new(x, y, self.block_size, self.block_size))).ok();
    }

    for x in 0..self.width {
      for y in 0..self.height {
        let block = self.board[y as usize][x as usize] as usize;
        self.canvas.copy(&gfx.blocks[block], None, Some(Rect::new((x*self.block_size) as i32, (y*self.block_size) as i32, self.block_size, self.block_size))).ok();
      }
    }
    self.canvas.present();
  }
}

// Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
const STARTING_POSITIONS : [[[i8; 2]; 4]; NUM_TETROMINOS] = [
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
const ROTATIONS : [[[[i8; 2]; 4]; 4]; NUM_TETROMINOS] = [
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
   [[0,0], [0,0], [0,0], [0,0]]],
];

pub fn main() -> Result<(), Box<dyn Error>> {
  let mut level = 0;
  if std::env::args().len() > 1 {
    level = std::env::args().collect::<Vec<String>>()[1].parse::<u32>().unwrap();
    level = std::cmp::min(15, std::cmp::max(0, level));
  }
  let mut ctx = GameContext::new(10, 20, 64, level*3)?;
  let texture_creator = ctx.canvas.texture_creator();
  ctx.sound_korobeiniki.play(-1)?;
  let ttf_ctx = sdl2::ttf::init()?;
  let font = ttf_ctx.load_font("fonts/Montserrat-Regular.ttf", 28)?;
  let graphics = Graphics::new(&texture_creator);

  ctx.add_board_piece();
  ctx.draw_screen(&graphics, &font);

  print!("\n
TETЯIS: \n
  usage: {} [level 1-15]\n
  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.\n
  Up - Rotate.
  Down - Lower.
  Space - Drop completely.\n", std::env::args().into_iter().next().unwrap());

  let mut game_ticks = 0;
  let mut drop_ticks = 0;
  let mut last_frame_ms = Instant::now();
  let mut event_pump = ctx.sdl_ctx.event_pump()?;
  while ctx.state != State::GAMEOVER {
    let mut changed = false;
    for event in event_pump.poll_iter() {
      match event {
        Event::Quit {..} => std::process::exit(0),
        Event::KeyDown { keycode: Some(keycode), .. } => {
          match keycode {
            Keycode::Escape | Keycode::Q => std::process::exit(0),
            Keycode::P  => { ctx.state = if ctx.state == State::PLAY { State::PAUSE } else { State::PLAY }; },
            Keycode::F1 => { ctx.sound_bwv814menuet.play(-1)?; },
            Keycode::F2 => { ctx.sound_korobeiniki.play(-1)?; },
            Keycode::F3 => { ctx.sound_russiansong.play(-1)?; },
            _ => {}
          }
        },
        _ => {}
      }

      if ctx.state == State::PLAY {
        match event {
          Event::KeyDown { keycode: Some(keycode), .. } => {
            match keycode {
              Keycode::Up => { changed = ctx.rotate(); },
              Keycode::Left => {
                if !ctx.collision_detected(-1, 0) {
                  ctx.move_tetromino(-1, 0);
                  changed = true;
                }
              },
              Keycode::Right => {
                if !ctx.collision_detected(1, 0) {
                  ctx.move_tetromino(1, 0);
                  changed = true;
                }
              },
              Keycode::Down => {
                if !ctx.collision_detected(0, 1) {
                  ctx.move_tetromino(0, 1);
                  changed = true;
                }
              },
              Keycode::Space => {
                while !ctx.collision_detected(0, 1) {
                  ctx.move_tetromino(0, 1);
                  changed = true;
                }
              },
              _ => {}
            }
          },
          _ => {}
        }
      }
    }

    if ctx.state == State::PLAY {
      if game_ticks >= drop_ticks + std::cmp::max(15 - ctx.completed_lines / 3, 1) {
        changed = true;
        drop_ticks = game_ticks;
        if !ctx.collision_detected(0, 1) {
          ctx.move_tetromino( 0, 1);
        } else {
          ctx.clear_board();
          ctx.current_orientation = 0;
          ctx.current_piece = ctx.next_piece;
          ctx.next_piece = ctx.rng.sample(Uniform::new(0, NUM_TETROMINOS as u8));
          if ctx.add_board_piece() {
            ctx.state = State::GAMEOVER;
          }
        }
      }
    }

    if changed {
      ctx.draw_screen(&graphics, &font);
    }

    let now = Instant::now();
    if now.duration_since(last_frame_ms).as_millis() > FRAME_RATE_MS {
      game_ticks += 1;
      last_frame_ms = now;
    }

    ::std::thread::sleep(Duration::from_millis(1));
  }

  // Game over.
  ctx.sound_gameover.play(0)?;
  ctx.draw_screen(&graphics, &font);

  // Clear a rectangle for the game-over message and write the message.
  let texture_creator = ctx.canvas.texture_creator();
  let text_surface = font.render("The only winning move is not to play").blended(Color::RGBA(255, 0, 0, 255)).ok();
  let text_texture = texture_creator.create_texture_from_surface(&text_surface.as_ref().unwrap()).ok();
  let text_ypos = (ctx.height_px as f32 * 0.4375) as i32;
  let text_height = (ctx.height_px as f32 * 0.125) as u32;
  ctx.canvas.set_draw_color(Color::RGB(0, 0, 0));
  ctx.canvas.fill_rect(Rect::new(0, text_ypos, ctx.width_px, text_height)).ok();

  ctx.canvas.copy(&text_texture.as_ref().unwrap(), None, Some(Rect::new((ctx.width_px as f32 * 0.05) as i32, text_ypos, (ctx.width_px as f32 * 0.90) as u32, (ctx.height_px as f32 * 0.125) as u32))).ok();
  ctx.canvas.present();

  'gameover: loop {
    for event in event_pump.poll_iter() {
      match event {
        Event::Quit {..} => break 'gameover,
        Event::KeyDown { keycode: Some(keycode), .. } => {
          match keycode {
            Keycode::Escape | Keycode::Q => break 'gameover,
            _ => {}
          }
        },
        _ => {}
      }
    }
    ::std::thread::sleep(Duration::from_millis(10));
  }
  Ok(())
}
