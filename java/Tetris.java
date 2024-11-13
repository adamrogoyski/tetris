// Author: Adam Rogoyski (adam@rogoyski.com).
// Public domain software.
//
// A tetris game.
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.LineUnavailableException;
import javax.sound.sampled.UnsupportedAudioFileException;
import java.awt.*;
import java.awt.image.BufferStrategy;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.Objects;
import java.util.Random;

enum Status {PLAY, PAUSE, GAMEOVER};

class GameContext {
  public static final int NUM_TETROMINOS = 7;

  // Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
  final int[][][] starting_positions = new int[][][] {
    {{-1,0}, {-1,1}, {0,1}, {1,1}},  // Leftward L piece.
    {{-1,1}, {0,1},  {0,0}, {1,0}},  // Rightward Z piece.
    {{-2,0}, {-1,0}, {0,0}, {1,0}},  // Long straight piece.
    {{-1,1}, {0,1},  {0,0}, {1,1}},  // Bump in middle piece.
    {{-1,1}, {0,1},  {1,1}, {1,0}},  // L piece.
    {{-1,0}, {0,0},  {0,1}, {1,1}},  // Z piece.
    {{-1,0}, {-1,1}, {0,0}, {0,1}},  // Square piece.
  };

  final int[][][][] rotations = new int[][][][] {
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

  int width;
  int height;
  int block_size;
  int framerate;
  int width_px;
  int height_px;
  int completed_lines = 0;
  int current_orientation = 0;
  int current_piece;
  int next_piece;
  int[][] board;
  int[][] current_coords;
  Status status = Status.PLAY;

  public GameContext(int width, int height, int block_size, int framerate) {
    this.width = width;
    this.height = height;
    this.block_size = block_size;
    this.framerate = framerate;
    this.width_px = width*block_size + 50 + 6*block_size;
    this.height_px = height*block_size;
    board = new int[height][];
    for (int y = 0; y < height; ++y) {
      board[y] = new int[width];
      for (int x = 0; x < width; ++x) {
        board[y][x] = 0;
      }
    }
    current_coords = new int[4][2];
  }
}

class TetrisCanvas extends Canvas {
  GameContext ctx;
  Image block_black  = Toolkit.getDefaultToolkit().getImage("graphics/block_black.png");
  Image block_blue   = Toolkit.getDefaultToolkit().getImage("graphics/block_blue.png");
  Image block_cyan   = Toolkit.getDefaultToolkit().getImage("graphics/block_cyan.png");
  Image block_green  = Toolkit.getDefaultToolkit().getImage("graphics/block_green.png");
  Image block_orange = Toolkit.getDefaultToolkit().getImage("graphics/block_orange.png");
  Image block_purple = Toolkit.getDefaultToolkit().getImage("graphics/block_purple.png");
  Image block_red    = Toolkit.getDefaultToolkit().getImage("graphics/block_red.png");
  Image block_yellow = Toolkit.getDefaultToolkit().getImage("graphics/block_yellow.png");
  Image[] blocks = {block_black, block_blue, block_cyan, block_green, block_orange, block_purple, block_red, block_yellow};
  Image logo = Toolkit.getDefaultToolkit().getImage("graphics/logo.png");
  Image wall = Toolkit.getDefaultToolkit().getImage("graphics/wall.png");
  Font font;

  public TetrisCanvas(GameContext ctx) {
    this.ctx = ctx;
    setFocusable(false);
    try {
      GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
      ge.registerFont(Font.createFont(Font.TRUETYPE_FONT, new File("fonts/Montserrat-Regular.ttf")));
      font = new Font("Montserrat", Font.PLAIN, 76);
    } catch (IOException|FontFormatException e) {
    }
  }

  void DrawBoard(Graphics g) {
    for (int x = 0; x < ctx.width; ++x) {
      for (int y = 0; y < ctx.height; ++y) {
         g.drawImage(blocks[ctx.board[y][x]], x*ctx.block_size, y*ctx.block_size, (x+1)*ctx.block_size-1, (y+1)*ctx.block_size-1, 0, 0, 32, 32, this);
      }
    }
  }

  void DrawStatus(Graphics g) {
    // Wall extends from top to bottom, separating the board from the status area.
    g.drawImage(wall, ctx.width*ctx.block_size, 0, ctx.width*ctx.block_size+50, ctx.height_px, 0, 0, 50, 640, this);

    // The logo sits at the top right of the screen right of the wall.
    int left_border = ctx.width*ctx.block_size + 50 + 6*(int)(ctx.block_size*0.05);
    final int width = 6*(int)(ctx.block_size*0.90);
    g.drawImage(logo, left_border, 0, left_border+width, (int)(ctx.height_px*0.20), 0, 0, 99, 44, this);

    // Write the number of completed lines.
    g.setColor(Color.RED);
    g.setFont(font);
    g.drawString("Lines: " + ctx.completed_lines, left_border, (int)(ctx.height_px*0.25)); // width, height_px*0.05

    // Write the current game level.
    g.drawString("Level: " + (int) (ctx.completed_lines / 3), left_border, (int)(ctx.height_px*0.35)); // width, height_px*0.05

    // Draw the next tetromino piece.
    for (int i = 0; i < 4; ++i) {
      final int top_border = (int) (ctx.height_px * 0.45);
      left_border = (ctx.width + 2)*ctx.block_size + 50 + (int) ( 6*ctx.block_size*0.05);
      final int x = left_border + ctx.starting_positions[ctx.next_piece-1][i][0]*ctx.block_size;
      final int y = top_border + ctx.starting_positions[ctx.next_piece-1][i][1]*ctx.block_size;
      g.drawImage(blocks[ctx.next_piece], x, y, x+ctx.block_size, y+ctx.block_size, 0, 0, 32, 32, this);
    }
  }

  void DrawGameOver(Graphics g) {
    // Clear a rectangle for the game-over message and write the message.
    g.setColor(Color.BLACK);
    g.clearRect(0, (int) (ctx.height_px*0.4375), ctx.width_px, (int) (ctx.height_px*0.125));
    g.setColor(Color.RED);
    g.drawString("The only winning move is not to play", (int) (ctx.width_px*0.05), (int) (ctx.height_px*0.51));
  }

  public void paint(Graphics g) {
    if (getBufferStrategy() == null) {
      createBufferStrategy(2);
    }
    BufferStrategy buffer = getBufferStrategy();
    Graphics2D g2d = (Graphics2D) buffer.getDrawGraphics();
    g.setColor(Color.BLACK);
    g2d.clearRect(0, 0, ctx.width_px, ctx.height_px);
    DrawBoard(g2d);
    DrawStatus(g2d);
    if (ctx.status == Status.GAMEOVER) {
      DrawGameOver(g2d);
    }
    buffer.show();
  }

  // Needed to not default to clearing the screen each update.
  public void update (Graphics g) { paint (g); }
}

class TetrisGame {
  GameContext ctx;
  private final TetrisCanvas canvas;
  Random rand;
  boolean changed = false;
  Clip song_bwv814menuet;
  Clip song_korobeiniki;
  Clip song_russiansong;
  Clip song_gameover;

  public TetrisGame(GameContext ctx, TetrisCanvas canvas) {
    this.ctx = ctx;
    this.canvas = Objects.requireNonNull(canvas);
  }

  boolean AddBoardPiece() {
    final int center = (int) (ctx.width / 2);
    for (int i = 0; i < 4; ++i) {
      final int x = center + ctx.starting_positions[ctx.current_piece-1][i][0];
      final int y = ctx.starting_positions[ctx.current_piece-1][i][1];
      if (ctx.board[y][x] > 0) {
        return true;
      }
      ctx.board[y][x] = ctx.current_piece;
      ctx.current_coords[i][0] = x;
      ctx.current_coords[i][1] = y;
    }
    return false;
  }

  void SetCoords(int[][] board, int[][] coords, final int piece) {
    for (int i = 0; i < 4; ++i) {
      board[coords[i][1]][coords[i][0]] = piece;
    }
  }

  public boolean CollisionDetected(final int dx, final int dy) {
    boolean collision = false;
    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(ctx.board, ctx.current_coords, 0);
    for (int i = 0; i < 4; ++i) {
      final int x = ctx.current_coords[i][0];
      final int y = ctx.current_coords[i][1];
      // Collision is hitting the left wall, right wall, bottom, or a non-black block.
      // Since this collision detection is only for movement, check the top (y < 0) is not needed.
      if ((x + dx) < 0 || (x + dx) >= ctx.width || (y + dy) >= ctx.height || ctx.board[y+dy][x+dx] != 0) {
        collision = true;
        break;
      }
    }
    // Restore the current piece.
    SetCoords(ctx.board, ctx.current_coords, ctx.current_piece);
    return collision;
  }

  boolean Rotate() {
    int[][] new_coords = new int[4][2];
    final int[][] rotation = ctx.rotations[ctx.current_piece-1][ctx.current_orientation];
    for (int i = 0; i < 4; ++i) {
      new_coords[i][0] = ctx.current_coords[i][0] + rotation[i][0];
      new_coords[i][1] = ctx.current_coords[i][1] + rotation[i][1];
    }

    // Clear the board where the piece currently is to not detect self collision.
    SetCoords(ctx.board, ctx.current_coords, 0);
    for (int i = 0; i < 4; ++i) {
      final int x = new_coords[i][0];
      final int y = new_coords[i][1];
      // Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
      if (x < 0 || x >= ctx.width || y < 0 || y >= ctx.height || ctx.board[y][x] != 0) {
        // Restore the current piece.
        SetCoords(ctx.board, ctx.current_coords, ctx.current_piece);
        return false;
      }
    }

    for (int i = 0; i < 4; ++i) {
      ctx.current_coords[i][0] = new_coords[i][0];
      ctx.current_coords[i][1] = new_coords[i][1];
      ctx.board[new_coords[i][1]][new_coords[i][0]] = ctx.current_piece;
    }
    ctx.current_orientation = (ctx.current_orientation + 1) % 4;
    return true;
  }

  public void MoveTetromino(int dx, int dy) {
    // Clear the board where the piece currently is.
    for (int i = 0; i < 4; ++i) {
      final int x = ctx.current_coords[i][0];
      final int y = ctx.current_coords[i][1];
      ctx.board[y][x] = 0;
    }
    // Update the current piece's coordinates and fill the board in the new coordinates.
    for (int i = 0; i < 4; ++i) {
      ctx.current_coords[i][0] += dx;
      ctx.current_coords[i][1] += dy;
      ctx.board[ctx.current_coords[i][1]][ctx.current_coords[i][0]] = ctx.current_piece;
    }
  }

  // Clear completed (filled) rows.
  // Start from the bottom of the board, moving all rows down to fill in a completed row, with
  // the completed row cleared and placed at the top.
  void ClearBoard() {
    int rows_deleted = 0;
    for (int row = ctx.height - 1; row >= rows_deleted;) {
      boolean has_hole = false;
      for (int x = 0; x < ctx.width && !has_hole; ++x) {
        has_hole = ctx.board[row][x] == 0;
      }
      if (!has_hole) {
        int[] deleted_row = ctx.board[row];
        for (int y = row; y > rows_deleted; --y) {
          ctx.board[y] = ctx.board[y-1];
        }
        ctx.board[rows_deleted] = deleted_row;
        Arrays.fill(ctx.board[rows_deleted], 0);
        ++rows_deleted;
      } else {
        --row;
      }
    }
    ctx.completed_lines += rows_deleted;
  }

  void PlayMusic(Clip song, boolean loop) {
    song_korobeiniki.stop();
    song_bwv814menuet.stop();
    song_russiansong.stop();
    if (loop) {
      song.loop(Clip.LOOP_CONTINUOUSLY);
    }
    song.setFramePosition(0);
    song.start();
  }

  public void GameLoop(Random rand) {
    long last_frame_ms = System.currentTimeMillis();
    final long ms_per_frame = (long) (1000 / ctx.framerate);
    long game_ticks = 0;
    long drop_ticks = 0;
    while (ctx.status != Status.GAMEOVER) {
      if (ctx.status == Status.PLAY) {
        if (game_ticks >= drop_ticks + Math.max(15 - ctx.completed_lines / 3, 1)) {
          changed = true;
          drop_ticks = game_ticks;
          if (!CollisionDetected(0, 1)) {
            MoveTetromino(0, 1);
          } else {
            ClearBoard();
            ctx.current_orientation = 0;
            ctx.current_piece = ctx.next_piece;
            ctx.next_piece = 1 + (rand.nextInt(ctx.NUM_TETROMINOS));
            if (AddBoardPiece()) {
              ctx.status = Status.GAMEOVER;
            }
          }
        }
      }
      if (changed) {
        changed = false;
        canvas.repaint();
      }
      long now_ms = System.currentTimeMillis();
      if ((now_ms - last_frame_ms) >= ms_per_frame) {
        ++game_ticks;
        last_frame_ms = now_ms;
      }
      try { Thread.sleep(1); } catch (InterruptedException e) { }
    }

    // Game over.
    PlayMusic(song_gameover, false);
    canvas.repaint();
    while (true) {
      try { Thread.sleep(10); } catch (InterruptedException e) { }
    }
  }

  public void start() throws LineUnavailableException, UnsupportedAudioFileException, IOException {
    Frame frame = new Frame();
    frame.addWindowListener(new WindowAdapter() {
      public void windowClosing(WindowEvent e) {
        System.exit(0);
      }
    });

    File file_bwv814menuet = new File("sound/bwv814menuet.wav");
    File file_korobeiniki = new File("sound/korobeiniki.wav");
    File file_russiansong = new File("sound/russiansong.wav");
    File file_gameover = new File("sound/gameover.wav");
    song_bwv814menuet = AudioSystem.getClip();
    song_bwv814menuet.open(AudioSystem.getAudioInputStream(file_bwv814menuet));

    song_korobeiniki = AudioSystem.getClip();
    song_korobeiniki.open(AudioSystem.getAudioInputStream(file_korobeiniki));

    song_russiansong = AudioSystem.getClip();
    song_russiansong.open(AudioSystem.getAudioInputStream(file_russiansong));

    song_gameover = AudioSystem.getClip();
    song_gameover.open(AudioSystem.getAudioInputStream(file_gameover));

    StackTraceElement[] stack = Thread.currentThread().getStackTrace ();
    String progname = stack[stack.length - 1].getClassName();
    System.out.println("\n" +
      "TETЯIS: \n\n" +
      "  usage: " + progname + " [level 1-15]\n\n" +
      "  F1  - Korobeiniki (gameboy song A).\n" +
      "  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).\n" +
      "  F3  - Russion song (gameboy song C).\n" +
      "  ESC - Quit.\n" +
      "  p   - Pause.\n\n" +
      "  Up - Rotate.\n" +
      "  Down - Lower.\n" +
      "  Space - Drop completely.\n");

    frame.addKeyListener(new KeyListener() {
      @Override
      public void keyTyped(KeyEvent e) {
        switch(e.getKeyChar()) {
          case 'p':
            switch (ctx.status) {
              case PLAY:
                ctx.status = Status.PAUSE;
                break;
              case PAUSE:
                ctx.status = Status.PLAY;
                break;
            }
            break;

          case 'q':
          case KeyEvent.VK_ESCAPE:
            System.exit(0);
            break;
        }
      }

      @Override public void keyPressed(KeyEvent e) {
        switch(e.getKeyCode()) {
         case KeyEvent.VK_LEFT:
           if (ctx.status == Status.PLAY && !CollisionDetected(-1, 0)) {
             changed = true;
             MoveTetromino(-1, 0);
           }
           break;

         case KeyEvent.VK_RIGHT:
           if (ctx.status == Status.PLAY && !CollisionDetected(1, 0)) {
             changed = true;
             MoveTetromino(1, 0);
           }
           break;

         case KeyEvent.VK_DOWN:
           if (ctx.status == Status.PLAY && !CollisionDetected(0, 1)) {
             changed = true;
             MoveTetromino(0, 1);
           }
           break;

         case KeyEvent.VK_SPACE:
           while (ctx.status == Status.PLAY && !CollisionDetected(0, 1)) {
             changed = true;
             MoveTetromino(0, 1);
           }
           break;

         case KeyEvent.VK_UP:
           if (ctx.status == Status.PLAY) {
             changed = Rotate();
           }
           break;

         case KeyEvent.VK_F1:
           PlayMusic(song_korobeiniki, true);
           break;

         case KeyEvent.VK_F2:
           PlayMusic(song_bwv814menuet, true);
           break;

         case KeyEvent.VK_F3:
           PlayMusic(song_russiansong, true);
           break;
        }
      }
      @Override public void keyReleased(KeyEvent e) { }
    });

    rand = new Random(System.currentTimeMillis());
    ctx.current_piece = 1 + rand.nextInt(ctx.NUM_TETROMINOS);
    ctx.next_piece = 1 + rand.nextInt(ctx.NUM_TETROMINOS);
    AddBoardPiece();

    canvas.setSize(ctx.width_px, ctx.height_px);
    canvas.setBackground(Color.BLACK);
    canvas.setVisible(true);
    frame.add(canvas);
    frame.setSize(ctx.width_px, ctx.height_px + 96);
    frame.setTitle("TETЯIS");
    frame.setVisible(true);
    canvas.repaint();
    PlayMusic(song_korobeiniki, true);
    GameLoop(rand);
  }
}

public class Tetris {
  public static void main(String[] args) throws InterruptedException {
    GameContext ctx = new GameContext(10, 20, 96, 60);
    if (args.length > 0) {
      ctx.completed_lines = Math.max(0, Math.min(45, 3 * Integer.parseInt(args[0])));
    }
    TetrisGame game = new TetrisGame(ctx, new TetrisCanvas(ctx));
    try {
      game.start();
    } catch (Throwable e) {
      System.out.println("Exception: " + e.getMessage());
    }
  }
}
