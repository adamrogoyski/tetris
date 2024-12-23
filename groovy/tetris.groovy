// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.Clip
import java.awt.*
import java.awt.image.BufferStrategy
import java.awt.event.KeyEvent
import java.awt.event.KeyListener
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent

class Tetris {
  final NUM_TETROMINOS = 7
  final framerate = 60
  final block_size = 64

  // Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
  final int[][][] starting_positions = [
    [[-1,0], [-1,1], [0,1], [1,1]],  // Leftward L piece.
    [[-1,1], [0,1],  [0,0], [1,0]],  // Rightward Z piece.
    [[-2,0], [-1,0], [0,0], [1,0]],  // Long straight piece.
    [[-1,1], [0,1],  [0,0], [1,1]],  // Bump in middle piece.
    [[-1,1], [0,1],  [1,1], [1,0]],  // L piece.
    [[-1,0], [0,0],  [0,1], [1,1]],  // Z piece.
    [[-1,0], [-1,1], [0,0], [0,1]],  // Square piece.
  ]

  final int[][][][] rotations = [
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
  ]


  Clip song_bwv814menuet = AudioSystem.getClip()
  Clip song_korobeiniki = AudioSystem.getClip()
  Clip song_russiansong = AudioSystem.getClip()
  Clip song_gameover = AudioSystem.getClip()
  Random rand
  final _width = 10
  final _height = 20
  final width_px = _width*block_size + 50 + 6*block_size
  final height_px = _height*block_size
  enum Status {PLAY, PAUSE, GAMEOVER}
  Status status = Status.PLAY
  int completed_lines = 0
  int current_piece
  int current_orientation = 0
  int next_piece
  int[][] board
  int[][] current_coords
  boolean changed = false

  class TetrisCanvas extends Canvas {
    Image block_black  = Toolkit.getDefaultToolkit().getImage("graphics/block_black.png")
    Image block_blue   = Toolkit.getDefaultToolkit().getImage("graphics/block_blue.png")
    Image block_cyan   = Toolkit.getDefaultToolkit().getImage("graphics/block_cyan.png")
    Image block_green  = Toolkit.getDefaultToolkit().getImage("graphics/block_green.png")
    Image block_orange = Toolkit.getDefaultToolkit().getImage("graphics/block_orange.png")
    Image block_purple = Toolkit.getDefaultToolkit().getImage("graphics/block_purple.png")
    Image block_red    = Toolkit.getDefaultToolkit().getImage("graphics/block_red.png")
    Image block_yellow = Toolkit.getDefaultToolkit().getImage("graphics/block_yellow.png")
    Image[] blocks = [block_black, block_blue, block_cyan, block_green, block_orange, block_purple, block_red, block_yellow]
    Image logo = Toolkit.getDefaultToolkit().getImage("graphics/logo.png")
    Image wall = Toolkit.getDefaultToolkit().getImage("graphics/wall.png")
    BufferStrategy buffer
    Font font

    TetrisCanvas() {
      setFocusable(false)
      try {
        GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment()
        ge.registerFont(Font.createFont(Font.TRUETYPE_FONT, new File("fonts/Montserrat-Regular.ttf")))
        font = new Font("Montserrat", Font.PLAIN, 24 * (int) (block_size / 32))
      } catch (IOException|FontFormatException e) {
      }
    }

    void DrawBoard(Graphics _g) {
      for (int x = 0; x < _width; ++x) {
        for (int y = 0; y < _height; ++y) {
          _g.drawImage(blocks[board[y][x]], x*block_size, y*block_size, (x+1)*block_size, (y+1)*block_size, 0, 0, 32, 32, this)
        }
      }    
    }

    void DrawStatus(Graphics g) {
      // Wall extends from top to bottom, separating the board from the status area.
      g.drawImage(wall, _width*block_size, 0, _width*block_size+50, height_px, 0, 0, 50, 640, this)

      // The logo sits at the top right of the screen right of the wall.
      int left_border = _width*block_size + 50 + 6*(int)(block_size*0.05)
      final int width = 6*(int)(block_size*0.90)
      g.drawImage(logo, left_border, 0, left_border+width, (int)(height_px*0.20), 0, 0, 99, 44, this)

      // Write the number of completed lines.
      g.setColor(Color.RED)
      g.setFont(font)
      g.drawString("Lines: " + completed_lines, left_border, (int)(height_px*0.25))

      // Write the current game level.
      g.drawString("Level: " + (int) (completed_lines / 3), left_border, (int)(height_px*0.35))

      // Draw the next tetromino piece.
      for (int i = 0; i < 4; ++i) {
        final int top_border = (int) (height_px * 0.45)
        left_border = (_width + 2)*block_size + 50 + (int) (6*block_size*0.05)
        final int x = left_border + starting_positions[next_piece-1][i][0]*block_size
        final int y = top_border + starting_positions[next_piece-1][i][1]*block_size
        g.drawImage(blocks[next_piece], x, y, x+block_size, y+block_size, 0, 0, 32, 32, this)
      } 
    }

    void DrawGameOver(Graphics g) {
      // Clear a rectangle for the game-over message and write the message.
      g.setColor(Color.BLACK)
      g.clearRect(0, (int) (height_px*0.4375), width_px, (int) (height_px*0.125))
      g.setColor(Color.RED)
      g.drawString("The only winning move is not to play", (int) (width_px*0.05), (int) (height_px*0.51))
    }

    void paint(Graphics _g) {
      if (getBufferStrategy() == null) {
        createBufferStrategy(2)
        buffer = getBufferStrategy()
      }
      Graphics2D g = (Graphics2D) buffer.getDrawGraphics()
      g.setBackground(Color.BLACK)
      g.setColor(Color.BLACK)
      g.clearRect(0, 0, width_px, height_px)
      DrawBoard(g)
      DrawStatus(g)
      if (status == Status.GAMEOVER) {
        DrawGameOver(g)
      }
      g.dispose()
      buffer.show()
    }

    // Needed to not default to clearing the screen each update.
    public void update (Graphics g) { paint (g) }
  }

  TetrisCanvas canvas
  Frame frame

  void SetCoords(int[][] board, int[][] coords, final int piece) {
    for (int i = 0; i < 4; ++i) {
      board[coords[i][1]][coords[i][0]] = piece
    }
  }

  boolean CollisionDetected(final int dx, final int dy) {
    boolean collision = false
    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(board, current_coords, 0)
    for (int i = 0; i < 4; ++i) {
      final int x = current_coords[i][0]
      final int y = current_coords[i][1]
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if ((x + dx) < 0 || (x + dx) >= _width || (y + dy) >= _height || board[y+dy][x+dx] != 0) {
        collision = true
        break
      }
    }
    // Restore the current piece.
    SetCoords(board, current_coords, current_piece);
    return collision
  }

  boolean Rotate() {
    int[][] new_coords = new int[4][2]
    final int[][] rotation = rotations[current_piece-1][current_orientation]
    for (int i = 0; i < 4; ++i) {
      new_coords[i][0] = current_coords[i][0] + rotation[i][0]
      new_coords[i][1] = current_coords[i][1] + rotation[i][1]
    }

    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(board, current_coords, 0)
    for (int i = 0; i < 4; ++i) {
      final int x = new_coords[i][0]
      final int y = new_coords[i][1]
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if (x < 0 || x >= _width || y < 0 || y >= _height || board[y][x] != 0) {
        // Restore the current piece.
        SetCoords(board, current_coords, current_piece)
        return false
      }
    }

    for (int i = 0; i < 4; ++i) {
      current_coords[i][0] = new_coords[i][0]
      current_coords[i][1] = new_coords[i][1]
      board[new_coords[i][1]][new_coords[i][0]] = current_piece
    }
    current_orientation = (current_orientation + 1) % 4
    return true
  }

  public void MoveTetromino(int dx, int dy) {
    // Clear the board where the piece currently is.
    for (int i = 0; i < 4; ++i) {
      final int x = current_coords[i][0]
      final int y = current_coords[i][1]
      board[y][x] = 0
    }
    // Update the current piece's coordinates and fill the board in the new coordinates.
    for (int i = 0; i < 4; ++i) {
      current_coords[i][0] += dx
      current_coords[i][1] += dy
      board[current_coords[i][1]][current_coords[i][0]] = current_piece
    }
  }

  // Clear completed (filled) rows.
  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  void ClearBoard() {
    int rows_deleted = 0
    for (int row = _height - 1; row >= rows_deleted;) {
      boolean has_hole = false
      for (int x = 0; x < _width && !has_hole; ++x) {
        has_hole = board[row][x] == 0
      }
      if (!has_hole) {
        int[] deleted_row = board[row]
        for (int y = row; y > rows_deleted; --y) {
          board[y] = board[y-1]
        }
        board[rows_deleted] = deleted_row
        Arrays.fill(board[rows_deleted], 0)
        ++rows_deleted
      } else {
        --row
      }
    }
    completed_lines += rows_deleted
  }

  boolean AddBoardPiece() {
    final int center = (int) (_width / 2)
    for (int i = 0; i < 4; ++i) {
      final int x = center + starting_positions[current_piece-1][i][0]
      final int y = starting_positions[current_piece-1][i][1]
      if (board[y][x] > 0) {
        return true
      }
      board[y][x] = current_piece
      current_coords[i][0] = x
      current_coords[i][1] = y
    }
    return false
  }

  void PlayMusic(Clip song, boolean loop) {
    song_korobeiniki.stop()
    song_bwv814menuet.stop()
    song_russiansong.stop()
    if (loop) {
      song.loop(Clip.LOOP_CONTINUOUSLY)
    }
    song.setFramePosition(0)
    song.start()
  }

  void init(final int lines) {
    File file_bwv814menuet = new File('sound/bwv814menuet.wav')
    File file_korobeiniki = new File("sound/korobeiniki.wav")
    File file_russiansong = new File("sound/russiansong.wav")
    File file_gameover = new File("sound/gameover.wav")
    song_bwv814menuet.open AudioSystem.getAudioInputStream(file_bwv814menuet)
    song_korobeiniki.open AudioSystem.getAudioInputStream(file_korobeiniki)
    song_russiansong.open AudioSystem.getAudioInputStream(file_russiansong)
    song_gameover.open AudioSystem.getAudioInputStream(file_gameover)

    board = new int[_height][]
    for (int y = 0; y < _height; ++y) {
      board[y] = new int[_width]
      for (int x = 0; x < _width; ++x) {
        board[y][x] = 0
      }
    }
    current_coords = new int[4][2]

    rand = new Random(System.currentTimeMillis())
    current_piece = 1 + rand.nextInt(NUM_TETROMINOS)
    next_piece = 1 + rand.nextInt(NUM_TETROMINOS)
    AddBoardPiece()
    completed_lines = lines

    canvas = new TetrisCanvas()
    canvas.setSize(width_px, height_px)
    canvas.setBackground(Color.BLACK)
    canvas.setVisible(true)
    canvas.repaint()
    Frame frame = new Frame()
    frame.add(canvas)
    frame.setSize(width_px, height_px + block_size)
    frame.setTitle("TETЯIS")
    frame.pack()
    frame.setVisible(true)
    frame.addWindowListener(new WindowAdapter() {
      void windowClosing(WindowEvent we) { System.exit(0) }
    })
    frame.addKeyListener(new KeyListener() {
      @Override void keyTyped(KeyEvent e) {
        switch(e.getKeyChar()) {
          case 'p':
            switch (status) {
              case Status.PLAY:
                status = Status.PAUSE
                break
              case Status.PAUSE:
                status = Status.PLAY
                break
            }
            break

          case 'q':
          case KeyEvent.VK_ESCAPE:
            System.exit(0)
            break
        }
      }
      @Override void keyReleased(KeyEvent e) {}
      @Override void keyPressed(KeyEvent e) {
        switch(e.getKeyCode()) {
          case KeyEvent.VK_ESCAPE:
            System.exit(0)
            break
          case KeyEvent.VK_F1:
            PlayMusic(song_korobeiniki, true)
            break
          case KeyEvent.VK_F2:
            PlayMusic(song_bwv814menuet, true)
            break
          case KeyEvent.VK_F3:
            PlayMusic(song_russiansong, true)
            break
          case KeyEvent.VK_LEFT:
            if (status == Status.PLAY && !CollisionDetected(-1, 0)) {
              changed = true
              MoveTetromino(-1, 0)
            }
            break
          case KeyEvent.VK_RIGHT:
            if (status == Status.PLAY && !CollisionDetected(1, 0)) {
              changed = true
              MoveTetromino(1, 0)
            }
            break
          case KeyEvent.VK_DOWN:
            if (status == Status.PLAY && !CollisionDetected(0, 1)) {
              changed = true
              MoveTetromino(0, 1)
            }
            break
          case KeyEvent.VK_SPACE:
            while (status == Status.PLAY && !CollisionDetected(0, 1)) {
              changed = true
              MoveTetromino(0, 1)
            }
            break
          case KeyEvent.VK_UP:
            if (status == Status.PLAY) {
              changed = Rotate()
            }
            break
        }
      }
    })
  }

  void GameLoop() {
    long last_frame_ms = System.currentTimeMillis()
    final long ms_per_frame = (long) (1000 / framerate)
    long game_ticks = 0
    long drop_ticks = 0
    while (status != Status.GAMEOVER) {
      if (status == Status.PLAY) {
        if (game_ticks >= drop_ticks + Math.max((int) (15 - completed_lines / 3), 1)) {
          changed = true
          drop_ticks = game_ticks
          if (!CollisionDetected(0, 1)) {
            MoveTetromino(0, 1)
          } else {
            ClearBoard()
            current_orientation = 0
            current_piece = next_piece
            next_piece = 1 + (rand.nextInt(NUM_TETROMINOS))
            if (AddBoardPiece()) {
              status = Status.GAMEOVER
            }
          }
        }
      }
      if (changed) {
        changed = false
        canvas.repaint()
      }
      long now_ms = System.currentTimeMillis()
      if ((now_ms - last_frame_ms) >= ms_per_frame) {
        ++game_ticks
        last_frame_ms = now_ms
      }
      try { Thread.sleep(1) } catch (InterruptedException e) { }
    }

    // Game over.
    PlayMusic(song_gameover, false);
    canvas.repaint();
    while (true) {
      try { Thread.sleep(10); } catch (InterruptedException e) { }
    }
  }

  static void main(String[] args) {
    int lines = 0
    if (args.length > 0) {
      lines = Math.max(0, Math.min(45, 3 * Integer.parseInt(args[0])))
    }
    Tetris ctx = new Tetris()
    def fname = Tetris.protectionDomain.codeSource.location.path
    println '\n' +
    'TETЯIS: \n\n' +
    "  usage: ${fname.substring(fname.lastIndexOf('/') + 1)} [level 1-15]\n\n" +
    '  F1  - Korobeiniki (gameboy song A).\n' +
    '  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).\n' +
    '  F3  - Russion song (gameboy song C).\n' +
    '  ESC - Quit.\n' +
    '  p   - Pause.\n\n' +
    '  Up - Rotate.\n' +
    '  Down - Lower.\n' +
    '  Space - Drop completely.\n'
    ctx.init(lines)
    ctx.PlayMusic(ctx.song_korobeiniki, true)
    ctx.GameLoop()
  }
}
