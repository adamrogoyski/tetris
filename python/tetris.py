#!/usr/bin/python3
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.

import copy
import math
import random
#import pygame_sdl2 as pygame  # type: ignore
import pygame  # type: ignore
import os
import sys
from typing import List, Tuple


def GetPath(path: str) -> str:
  # Obtain the path of graphics/ and sound/ relative to where the executable script is.
  # Realpath will resolve extra components like ./. Two dirnames get to the project parent directory.
  return os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), path)


class GameContext(object):
  def __init__(self, width: int, height: int, level_adjust: int):
    self.width = width
    self.height = height
    # The usual board is a 20x10 rectangle game board -- twice as tall as wide.
    # The board is a list of rows (y,x) rather than a list of columns (x,y) to
    # simplify line clearing. Thus coordinates for pieces on the board throughout
    # will be board[y][x].
    self.board = [[0] * width for _ in range(height)]

    # A level is incremented every 3 lines. Speed tops out at level 15.
    self.completed_lines = level_adjust

    # The board (area in play) is made up of WIDTHxHEIGHT blocks.
    # Each block is 32x32 pixels.
    # Each tetromino (piece) is made up of 4 blocks.
    self.block_size = 32

    self.screen = self.SetupScreen()
    self.sound_line_cleared = self.SetupSound()

    gpath = GetPath('graphics')
    self.block_black = pygame.image.load(os.path.join(gpath, 'block_black.png')).convert()
    self.block_blue = pygame.image.load(os.path.join(gpath, 'block_blue.png')).convert()
    self.block_cyan = pygame.image.load(os.path.join(gpath, 'block_cyan.png')).convert()
    self.block_green = pygame.image.load(os.path.join(gpath, 'block_green.png')).convert()
    self.block_orange = pygame.image.load(os.path.join(gpath, 'block_orange.png')).convert()
    self.block_purple = pygame.image.load(os.path.join(gpath, 'block_purple.png')).convert()
    self.block_red = pygame.image.load(os.path.join(gpath, 'block_red.png')).convert()
    self.block_yellow = pygame.image.load(os.path.join(gpath, 'block_yellow.png')).convert()
    self.blocks = (self.block_black, self.block_blue, self.block_cyan, self.block_green,
                   self.block_orange, self.block_purple, self.block_red, self.block_yellow)

    # The game runs at 40 ticks/frames per second, represented as one game_tick.
    self.clock = pygame.time.Clock()
    self.game_ticks = 1
    # Other ticks are used to delay repeated actions by set amounts of frames.
    self.pause_tick = 1
    self.music_tick = 1
    self.move_left_tick = 1
    self.move_right_tick = 1
    self.move_down_tick = 1
    self.move_rotate_tick = 1
    self.move_tick = 1
    self.block_tick = 1
    self.down_tick = 1

    self.regular_font = pygame.font.Font('fonts/Montserrat-Regular.ttf', 80)
    lose_text = 'The only winning move is not to play'
    lose_img = self.regular_font.render(lose_text, 0, (255, 0, 0), (0, 0, 0)).convert()
    self.lose_img = pygame.transform.scale(lose_img, (math.floor((width*self.block_size + 180) * 0.90),
                                                      math.floor(height*self.block_size * 0.125)))

    # The right-side wall separating the board (area in play) from the status area.
    self.wall_img = pygame.image.load(os.path.join(gpath, 'wall.png')).convert()  # 50x640.
    # The TETЯIS logo.
    self.logo_img = pygame.image.load(os.path.join(gpath, 'logo.png')).convert()  # 99x44.

    # The current tetromino (piece) in play. An Integer from range(1, 8) to index into starting_positions.
    self.current_tetromino = 0
    # The current tetromino's image to display to the screen.
    self.current_tetromino_type = None
    # The current tetromino's four (x,y) coordinates. A List[List[Integer x, Integer y]].
    self.current_tetromino_coords = [[0, 0],]*4
    # The current tetromino's rotation orientation. An Integer from range(0, 4) from the set Z/4Z.
    self.current_tetromino_orientation = 0
    # The next tetromino on deck. Shown in the window and the next to be in play as current_tetromino.
    self.following_tetromino = random.randint(1, 7)

    # Starting position of each type of tetromino. It is 4 (x,y) coordinates except for the index=0 null block
    # that is used to fill the backgroud.
    self.center = center = width // 2
    self.starting_positions = [[[0, 0],]*4,  # Null block -- background block.
                            [[center-1,0], [center-1,1], [center,1], [center+1,1]],  # Leftward L piece.
                            [[center-1,1], [center,1], [center,0], [center+1,0]],    # Rightward Z piece.
                            [[center-2,0], [center-1,0], [center,0], [center+1,0]],  # Long straight piece.
                            [[center-1,1], [center,1], [center,0], [center+1,1]],    # Bump in middle piece.
                            [[center-1,1], [center,1], [center+1,1], [center+1,0]],  # L piece.
                            [[center-1,0], [center,0], [center,1], [center+1,1]],    # Z piece.
                            [[center-1,0], [center-1,1], [center,0], [center,1]],    # Square piece.
                           ]

  def SetupScreen(self) -> pygame.Surface:
    pygame.init()
    width_pixels = self.width*self.block_size + 180  # 50px for the wall and 130 for status.
    height_pixels = self.height*self.block_size
    SCREENRECT = pygame.rect.Rect(0, 0, width_pixels, height_pixels)
    depth = pygame.display.mode_ok(SCREENRECT.size, depth=32)
    return pygame.display.set_mode(SCREENRECT.size, depth=depth)

  def SetupSound(self) -> pygame.mixer.Sound:
    pygame.mixer.init()

    # Start the background music.
    spath = GetPath('sound')
    pygame.mixer.music.load(os.path.join(spath, 'korobeiniki.wav'))
    pygame.mixer.music.play(-1)

    return pygame.mixer.Sound(os.path.join(spath, 'lineclear.wav'))

  def NextTetromino(self) -> None:
    self.current_tetromino = self.following_tetromino
    self.following_tetromino = random.randint(1, 7)
    self.current_tetromino_coords = copy.deepcopy(self.starting_positions[self.current_tetromino])
    self.current_tetromino_type = self.blocks[self.current_tetromino]
    self.current_tetromino_orientation = 0


class Rotation(object):
  # Tuple of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
  # Each rotation is a Tuple of 4 rotations -- one for each orientation of a tetromino.
  # For each rotation, there is a Tuple of 4 (Integer x, Integer y) coordinate diffs for each block of the tetromino.
  # The coordinate diffs map each block to its new location.
  # Thus: [block][orientation][component] to map the 4 components of each block in each orientation.
  ROTATIONS = (
      # Null block (background block).
      ((((0,0),)*4, ((0,0),)*4, ((0,0),)*4, ((0,0),)*4)),
      # Leftward L piece.
      (((0,2), (1,1), (0,0), (-1, -1)), ((2,0), (1,-1), (0,0), (-1,1)), ((0,-2), (-1,-1), (0,0), (1,1)), ((-2,0), (-1,1), (0,0), (1,-1))),
      # Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
      (((1, 0), (0, 1), (-1, 0), (-2, 1)), ((-1, 0), (0, -1), (1, 0), (2, -1)), ((1, 0), (0, 1), (-1, 0), (-2, 1)), ((-1, 0), (0, -1), (1, 0), (2, -1))),
      # Long straight piece. Orientation symmetry: 0==2 and 1==3.
      (((2,-2), (1,-1), (0,0), (-1,1)), ((-2,2), (-1,1), (0,0), (1,-1)), ((2,-2), (1,-1), (0,0), (-1,1)), ((-2,2), (-1,1), (0,0), (1,-1))),
      # Bump in middle piece.
      (((1,1), (0,0), (-1,1), (-1,-1)), ((1,-1), (0,0), (1,1), (-1,1)), ((-1,-1), (0,0), (1,-1), (1,1)), ((-1,1), (0,0), (-1,-1), (1,-1))),
      # L Piece.
      (((1,1), (0,0), (-1,-1), (-2,0)), ((1,-1), (0,0), (-1,1), (0,2)), ((-1,-1), (0,0), (1,1), (2,0)), ((-1,1), (0,0), (1,-1), (0,-2))),
      # Z piece. Orientation symmetry: 0==2 and 1==3.
      (((1,0), (0,1), (-1,0), (-2,1)), ((-1,0), (0,-1), (1,0), (2,-1)), ((1,0), (0,1), (-1,0), (-2,1)), ((-1,0), (0,-1), (1,0), (2,-1))),
      # Square piece. Orientation symmetry: 0==1==2==3.
      ((((0,0),)*4, ((0,0),)*4, ((0,0),)*4, ((0,0),)*4)),
    )

  @classmethod
  def GetRotationCoords(cls, c: GameContext, coords: List[List[int]]) -> Tuple[List[List[int]], int]:
    # For the null block and all 7 game blocks, define the rotation for each orientation.
    # Tuple is [block][orientation][component] to map the 4 components of each block in each orientation
    # to its next location relative to its current location when rotate.
    for i, (dx, dy) in enumerate(cls.ROTATIONS[c.current_tetromino][c.current_tetromino_orientation]):
      coords[i][0] += dx
      coords[i][1] += dy
    return coords, (c.current_tetromino_orientation + 1) % 4

  @classmethod
  def Rotate(cls, c: GameContext) -> None:
    old_orientation = c.current_tetromino_orientation
    new_coords = copy.deepcopy(c.current_tetromino_coords)
    new_board = copy.deepcopy(c.board)

    for coords in new_coords:
      new_board[coords[1]][coords[0]] = 0
    new_coords, c.current_tetromino_orientation = cls.GetRotationCoords(c, new_coords)
    for coords in new_coords:
      if (coords[0] < 0 or coords[0] > c.width - 1 or
          coords[1] < 0 or coords[1] > c.height - 1):
        c.current_tetromino_orientation = old_orientation
        return
      if new_board[coords[1]][coords[0]]:
        c.current_tetromino_orientation = old_orientation
        return

    for coords in c.current_tetromino_coords:
      c.board[coords[1]][coords[0]] = 0
    for coords in new_coords:
      c.board[coords[1]][coords[0]] = c.current_tetromino
    c.current_tetromino_coords = new_coords


class Error(Exception):
  pass


class GameOver(Error):
  pass


class ExitGame(Error):
  pass


def CollisionDetected(c: GameContext, delta_x: int, delta_y: int) -> bool:
  new_coords = copy.deepcopy(c.current_tetromino_coords)
  new_board = copy.deepcopy(c.board)

  for coords in new_coords:
    new_board[coords[1]][coords[0]] = 0
  for coords in new_coords:
    coords[0] = min(coords[0] + delta_x, c.width - 1)
    coords[1] = min(coords[1] + delta_y, c.height - 1)
  for coords in new_coords:
    if new_board[coords[1]][coords[0]]:
      return True
  return False


# Removes completed lines from the board and adds new lines to the top.
def LineRemoval(c: GameContext) -> None:
  CLEAR_LINES_PAUSE = 200  # ms
  assert len(c.board) == c.height
  # Even though there can only be 0-4 lines cleared each move, within a 4-line bound,
  # all lines are checked to be cleared.
  # Delete any line that is completely filled.
  for line in range(c.height-1, -1, -1):
    if 0 not in c.board[line]:
      del c.board[line]
      c.completed_lines += 1
  # Add empty lines to the top to replaced cleared lines.
  for _ in range(c.height - len(c.board)):
    c.board[0:0] = [[0] * c.width]
  assert len(c.board) == c.height, (len(c.board), c.height)

  pygame.time.delay(CLEAR_LINES_PAUSE)
  c.sound_line_cleared.play()
  DrawBoard(c)
  return


# Game over condition is the current piece over lapping pieces on the board.
def CheckGameOver(c):
  for coords in c.current_tetromino_coords:
    if c.board[coords[1]][coords[0]]:
      raise GameOver


def DrawBoard(c: GameContext) -> None:
  # Clear the screen.
  c.screen.fill((0, 0, 0))

  # The right-side board wall is 50x640 pixels and needs to extend the whole screen.
  for x in range(math.ceil(c.height*c.block_size / 640)):
    c.screen.blit(c.wall_img, (c.width*c.block_size, x * 640))
  c.screen.blit(c.logo_img, (c.width*c.block_size + 60, 20))

  lines_text = 'Lines: %s' % c.completed_lines
  lines_img = c.regular_font.render(lines_text, 0, (255, 0, 0), (0, 0, 0))
  lines_img = lines_img.convert()
  lines_img = pygame.transform.scale(lines_img, (len(lines_text)*8, 30))
  c.screen.blit(lines_img, (c.width*c.block_size + 60, 100))

  level_text = 'level: %s' % (c.completed_lines // 3)
  level_img = c.regular_font.render(level_text, 0, (255, 0, 0), (0, 0, 0))
  level_img = level_img.convert()
  level_img = pygame.transform.scale(level_img, (len(lines_text)*8, 30))
  c.screen.blit(level_img, (c.width*c.block_size + 60, 150))

  following_piece = copy.deepcopy(c.starting_positions[c.following_tetromino])
  for coords in following_piece:
    c.screen.blit(c.blocks[c.following_tetromino], ((coords[0]-(c.center-1))*c.block_size + c.width*c.block_size + 75,
                                                    coords[1]*c.block_size + 300))

  for y in range(c.height):
    for x in range(c.width):
      c.screen.blit(c.blocks[c.board[y][x]], (x*c.block_size, y*c.block_size))
  pygame.display.flip()


def MoveTetromino(c: GameContext, delta_x: int, delta_y: int) -> None:
  # Clear the current piece's board location.
  for coords in c.current_tetromino_coords:
    c.board[coords[1]][coords[0]] = 0
  for coords in c.current_tetromino_coords:
    coords[0] += delta_x
    coords[1] += delta_y
  # Add piece back to the board in new location.
  for coords in c.current_tetromino_coords:
    c.board[coords[1]][coords[0]] = c.current_tetromino


def Main(level_adjust: int) -> None:
  print("""
TETЯIS:

  usage: %s [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.
""" % sys.argv[0])

  c = GameContext(width=10, height=20, level_adjust=level_adjust)

  # Set the first piece in play.
  c.NextTetromino()
  for coords in c.current_tetromino_coords:
    c.board[coords[1]][coords[0]] = c.current_tetromino
  DrawBoard(c)
  paused = False

  try:
    while True:
      for event in pygame.event.get():
        if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
          raise ExitGame

      # Auto-move block on timer. Check for new pieces and game over.
      if not paused:
        if c.game_ticks - c.block_tick > max(15 - int(c.completed_lines/3), 1):
          c.block_tick = c.game_ticks
          # Check if a piece has reached the bottom or would collide with the piece beneath it.
          for coords in c.current_tetromino_coords:
            if coords[1] == c.height - 1 or CollisionDetected(c, delta_x=0, delta_y=1):
              LineRemoval(c)
              c.NextTetromino()
              CheckGameOver(c)
              for coords in c.current_tetromino_coords:
                c.board[coords[1]][coords[0]] = c.current_tetromino
              break
          else:
            MoveTetromino(c, delta_x=0, delta_y=1)

      keystate = pygame.key.get_pressed()

      # Music selections.
      if any((keystate[pygame.K_F1], keystate[pygame.K_F2], keystate[pygame.K_F3])):
        spath = GetPath('sound')
        if keystate[pygame.K_F1]:
          if c.game_ticks - c.music_tick > 10:
            pygame.mixer.music.load(os.path.join(spath, 'korobeiniki.wav'))
            pygame.mixer.music.play(-1)
            c.music_tick = c.game_ticks
        elif keystate[pygame.K_F2]:
          if c.game_ticks - c.music_tick > 10:
            pygame.mixer.music.load(os.path.join(spath, 'bwv814menuet.wav'))
            pygame.mixer.music.play(-1)
            c.music_tick = c.game_ticks
        elif keystate[pygame.K_F3]:
          if c.game_ticks - c.music_tick > 10:
            pygame.mixer.music.load(os.path.join(spath, 'russiansong.wav'))
            pygame.mixer.music.play(-1)
            c.music_tick = c.game_ticks

      # Pause the game.
      if keystate[pygame.K_p]:
        if c.game_ticks - c.pause_tick > 10:
          paused = not paused
          c.pause_tick = c.game_ticks
      if paused:
        c.clock.tick(40)
        c.game_ticks += 1
        continue

      # Move piece left.
      if c.game_ticks - c.move_left_tick > 4:
        if keystate[pygame.K_LEFT]:
          c.move_tick = c.game_ticks
          for coords in c.current_tetromino_coords:
            if coords[0] == 0 or CollisionDetected(c, delta_x=-1, delta_y=0):
              break
          else:
            MoveTetromino(c, delta_x=-1, delta_y=0)
          c.move_left_tick = c.game_ticks

      # Move piece right.
      if c.game_ticks - c.move_right_tick > 4:
        if keystate[pygame.K_RIGHT]:
          for coords in c.current_tetromino_coords:
            if coords[0] == c.width- 1 or CollisionDetected(c, delta_x=1, delta_y=0):
              break
          else:
            MoveTetromino(c, delta_x=1, delta_y=0)
          c.move_right_tick = c.game_ticks

      # Rotate piece.
      if c.game_ticks - c.move_rotate_tick > 5:
        if keystate[pygame.K_UP]:
          Rotation.Rotate(c)
          c.move_rotate_tick = c.game_ticks

      # Lower piece down.
      if c.game_ticks - c.move_down_tick > 4:
        # Lower piece down 1 level.
        if keystate[pygame.K_DOWN]:
          for coords in c.current_tetromino_coords:
            if coords[1] == c.height - 1 or CollisionDetected(c, delta_x=0, delta_y=1):
              break
          else:
            MoveTetromino(c, delta_x=0, delta_y=1)
          c.move_down_tick = c.game_ticks
        # Drop piece completely down.
        elif keystate[pygame.K_SPACE] and (c.game_ticks - c.down_tick > 10):
          while not (coords[1] == c.height - 1 or CollisionDetected(c, delta_x=0, delta_y=1)):
            for coords in c.current_tetromino_coords:
              if coords[1] == c.height -1 or CollisionDetected(c, delta_x=0, delta_y=1):
                break
            else:
              MoveTetromino(c, delta_x=0, delta_y=1)
          c.move_down_tick = c.game_ticks
          c.block_tick = c.game_ticks - 1000
          c.down_tick = c.game_ticks

      DrawBoard(c)
      c.clock.tick(40)
      c.game_ticks += 1

  except GameOver:
    spath = GetPath('sound')
    pygame.mixer.music.load(os.path.join(spath, 'gameover.wav'))
    pygame.mixer.music.play(0)
    c.screen.blit(c.lose_img, (25, 250))
    pygame.display.flip()

    while True:
      for event in pygame.event.get():
        if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
          sys.exit(0)
      c.clock.tick(40)

  except ExitGame:
    sys.exit(0)


if __name__ == '__main__':
  level_adjust = 0
  if len(sys.argv) == 2:
    level_adjust = int(sys.argv[1]) * 3
  Main(level_adjust)
