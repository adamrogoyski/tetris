#!/usr/bin/env perl
#
# Author: Adam Rogoyski (adam@rogoyski.com).
# Public domain software.
#
# A tetris game.
#
# Style:
#   $ perltidy -b tetris.pl
#   $ perlcritic --brutal tetris.pl

use 5.016;
use warnings;
use autodie;
use Carp         qw(croak);
use experimental qw( switch );
use Readonly;
use SDL;
use SDL::Events;
use SDL::Mixer::Samples;
use SDL::Mixer::Channels;
use SDLx::App;
use SDLx::Sound;
use SDLx::Text;
our $VERSION = 1;

Readonly::Scalar my $WIDTH       => 10;
Readonly::Scalar my $HEIGHT      => 30;
Readonly::Scalar my $BLOCK_SIZE  => 32;
Readonly::Scalar my $WALL_WIDTH  => 50;
Readonly::Scalar my $WALL_HEIGHT => 640;
Readonly::Scalar my $LOGO_WIDTH  => 99;
Readonly::Scalar my $LOGO_HEIGHT => 44;
Readonly::Scalar my $WIDTH_PX => $WIDTH * $BLOCK_SIZE +
  $WALL_WIDTH + $LOGO_WIDTH + 60;
Readonly::Scalar my $HEIGHT_PX           => $HEIGHT * $BLOCK_SIZE;
Readonly::Scalar my $BPP                 => 32;
Readonly::Scalar my $OPAQUE              => 255;
Readonly::Scalar my $FULL_COLOR          => 255;
Readonly::Scalar my $RED_BIT_POSITION    => 16;
Readonly::Scalar my $CENTER              => $WIDTH / 2;
Readonly::Scalar my $NUM_TETROMINOS      => 7;
Readonly::Scalar my $NUM_ORIENTATIONS    => 4;
Readonly::Scalar my $BLOCKS_PER_PIECE    => 4;
Readonly::Scalar my $LEFT_1              => -1;
Readonly::Scalar my $RIGHT_1             => 1;
Readonly::Scalar my $DOWN_1              => 1;
Readonly::Scalar my $STATE_IN_PLAY       => 0;
Readonly::Scalar my $STATE_PAUSE         => 1;
Readonly::Scalar my $STATE_GAMEOVER      => 2;
Readonly::Scalar my $FRAME_RATE          => 60;
Readonly::Scalar my $MS_PER_FRAME        => int( 1000 / $FRAME_RATE );
Readonly::Scalar my $MAX_LEVEL           => 15;
Readonly::Scalar my $LINES_PER_LEVEL     => 3;
Readonly::Scalar my $KEY_REPEAT_DELAY    => 200;
Readonly::Scalar my $KEY_REPEAT_INTERVAL => 50;
Readonly::Scalar my $FONT_TTF            => 'fonts/Montserrat-Regular.ttf';
Readonly::Array my @FONT_COLOR => ( $FULL_COLOR, 0, 0, $OPAQUE );
Readonly::Scalar my $SONG_KOROBEINIKI  => 'sound/korobeiniki.wav';
Readonly::Scalar my $SONG_BWV814MENUET => 'sound/bwv814menuet.wav';
Readonly::Scalar my $SONG_RUSSIANSONG  => 'sound/russiansong.wav';
Readonly::Scalar my $SOUND_GAMEOVER    => 'sound/gameover.wav';
Readonly::Scalar my $SOUND_LINECLEAR   => 'sound/lineclear.wav';
Readonly::Scalar my $PROGRAM_NAME      => __FILE__;

Readonly::Array my @STARTING_POSITIONS => (
    [ [ -1, 0 ], [ -1, 1 ], [ 0, 1 ], [ 1, 1 ] ],    # Leftward L piece.
    [ [ -1, 1 ], [ 0,  1 ], [ 0, 0 ], [ 1, 0 ] ],    # Rightward Z piece.
    [ [ -2, 0 ], [ -1, 0 ], [ 0, 0 ], [ 1, 0 ] ],    # Long straight piece.
    [ [ -1, 1 ], [ 0,  1 ], [ 0, 0 ], [ 1, 1 ] ],    # Bump in middle piece.
    [ [ -1, 1 ], [ 0,  1 ], [ 1, 1 ], [ 1, 0 ] ],    # L piece.
    [ [ -1, 0 ], [ 0,  0 ], [ 0, 1 ], [ 1, 1 ] ],    # Z piece.
    [ [ -1, 0 ], [ -1, 1 ], [ 0, 0 ], [ 0, 1 ] ],    # Square piece.
);

# Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
# Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
# For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
# The coordinate diffs map each block to its new location.
# Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation
Readonly::Array my @ROTATIONS => (

    # Leftward L piece.
    [
        [ [ 0,  2 ],  [ 1,  1 ],  [ 0, 0 ], [ -1, -1 ] ],
        [ [ 2,  0 ],  [ 1,  -1 ], [ 0, 0 ], [ -1, 1 ] ],
        [ [ 0,  -2 ], [ -1, -1 ], [ 0, 0 ], [ 1,  1 ] ],
        [ [ -2, 0 ],  [ -1, 1 ],  [ 0, 0 ], [ 1,  -1 ] ]
    ],

    # Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
    [
        [ [ 1,  0 ], [ 0, 1 ],  [ -1, 0 ], [ -2, 1 ] ],
        [ [ -1, 0 ], [ 0, -1 ], [ 1,  0 ], [ 2,  -1 ] ],
        [ [ 1,  0 ], [ 0, 1 ],  [ -1, 0 ], [ -2, 1 ] ],
        [ [ -1, 0 ], [ 0, -1 ], [ 1,  0 ], [ 2,  -1 ] ]
    ],

    # Long straight piece. Orientation symmetry: 0==2 and 1==3.
    [
        [ [ 2,  -2 ], [ 1,  -1 ], [ 0, 0 ], [ -1, 1 ] ],
        [ [ -2, 2 ],  [ -1, 1 ],  [ 0, 0 ], [ 1,  -1 ] ],
        [ [ 2,  -2 ], [ 1,  -1 ], [ 0, 0 ], [ -1, 1 ] ],
        [ [ -2, 2 ],  [ -1, 1 ],  [ 0, 0 ], [ 1,  -1 ] ]
    ],

    # Bump in middle piece.
    [
        [ [ 1,  1 ],  [ 0, 0 ], [ -1, 1 ],  [ -1, -1 ] ],
        [ [ 1,  -1 ], [ 0, 0 ], [ 1,  1 ],  [ -1, 1 ] ],
        [ [ -1, -1 ], [ 0, 0 ], [ 1,  -1 ], [ 1,  1 ] ],
        [ [ -1, 1 ],  [ 0, 0 ], [ -1, -1 ], [ 1,  -1 ] ]
    ],

    # L Piece.
    [
        [ [ 1,  1 ],  [ 0, 0 ], [ -1, -1 ], [ -2, 0 ] ],
        [ [ 1,  -1 ], [ 0, 0 ], [ -1, 1 ],  [ 0,  2 ] ],
        [ [ -1, -1 ], [ 0, 0 ], [ 1,  1 ],  [ 2,  0 ] ],
        [ [ -1, 1 ],  [ 0, 0 ], [ 1,  -1 ], [ 0,  -2 ] ]
    ],

    # Z piece. Orientation symmetry: 0==2 and 1==3.
    [
        [ [ 1,  0 ], [ 0, 1 ],  [ -1, 0 ], [ -2, 1 ] ],
        [ [ -1, 0 ], [ 0, -1 ], [ 1,  0 ], [ 2,  -1 ] ],
        [ [ 1,  0 ], [ 0, 1 ],  [ -1, 0 ], [ -2, 1 ] ],
        [ [ -1, 0 ], [ 0, -1 ], [ 1,  0 ], [ 2,  -1 ] ]
    ],

    # Square piece. Orientation symmetry: 0==1==2==3.
    [
        [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ],
        [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ],
        [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ],
        [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ]
    ],
);

my $app = SDLx::App->new(
    width  => $WIDTH_PX,
    height => $HEIGHT_PX,
    title  => 'TETЯIS'
);
my $snd = SDLx::Sound->new();
Readonly::Scalar my $LINECLEAR_SAMPLE =>
  SDL::Mixer::Samples::load_WAV($SOUND_LINECLEAR);

my $block_black  = SDLx::Surface->load('graphics/block_black.png');
my $block_blue   = SDLx::Surface->load('graphics/block_blue.png');
my $block_cyan   = SDLx::Surface->load('graphics/block_cyan.png');
my $block_green  = SDLx::Surface->load('graphics/block_green.png');
my $block_orange = SDLx::Surface->load('graphics/block_orange.png');
my $block_purple = SDLx::Surface->load('graphics/block_purple.png');
my $block_red    = SDLx::Surface->load('graphics/block_red.png');
my $block_yellow = SDLx::Surface->load('graphics/block_yellow.png');
my @blocks       = (
    $block_black,  $block_blue,   $block_cyan, $block_green,
    $block_orange, $block_purple, $block_red,  $block_yellow,
);
my $logo = SDLx::Surface->load('graphics/logo.png');
my $wall = SDLx::Surface->load('graphics/wall.png');

my $current_piece       = int( rand $NUM_TETROMINOS ) + 1;
my $next_piece          = int( rand $NUM_TETROMINOS ) + 1;
my @current_coords      = ( [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] );
my $current_orientation = 0;

my $font_small = SDLx::Text->new(
    font    => $FONT_TTF,
    h_align => 'center',
    color   => [@FONT_COLOR]
);
my $font_large = SDLx::Text->new(
    font    => $FONT_TTF,
    h_align => 'center',
    color   => [@FONT_COLOR],
    size    => 22,
    bold    => 1,
);

my @board = ();
for my $i ( 1 .. ${HEIGHT} ) {
    push @board, [ (0) x $WIDTH ];
}

sub execute_board_piece {
    my ( $current_piece_r, $invoke_r ) = @_;
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        Readonly::Scalar my $X => $CENTER +
          $STARTING_POSITIONS[ ${$current_piece_r} - 1 ][$i][0];
        Readonly::Scalar my $Y =>
          $STARTING_POSITIONS[ ${$current_piece_r} - 1 ][$i][1];
        if ( $board[$Y][$X] ) { return $STATE_GAMEOVER; }
        $invoke_r->( $i, $X, $Y );
    }
    return $STATE_IN_PLAY;
}

sub add_board_piece {
    my ( $current_piece_r, $next_piece_r ) = @_;
    $current_orientation = 0;
    ${$current_piece_r} = ${$next_piece_r};
    ${$next_piece_r}    = int( rand $NUM_TETROMINOS ) + 1;
    if ( execute_board_piece( $current_piece_r, sub { } ) == $STATE_GAMEOVER ) {
        return $STATE_GAMEOVER;
    }
    return execute_board_piece(
        $current_piece_r,
        sub {
            my ( $i, $X, $Y ) = @_;
            $board[$Y][$X]         = ${$current_piece_r};
            $current_coords[$i][0] = $X;
            $current_coords[$i][1] = $Y;
        }
    );
}

sub draw_board {
    my ($app_r) = @_;
    for my $y ( 0 .. ${HEIGHT} - 1 ) {
        for my $x ( 0 .. ${WIDTH} - 1 ) {
            my $block = $blocks[ $board[$y][$x] ];
            $block->blit(
                $app_r,
                [ 0, 0, $BLOCK_SIZE, $BLOCK_SIZE ],
                [ $x * $BLOCK_SIZE, $y * $BLOCK_SIZE ]
            );
        }
    }
    return;
}

sub draw_status {
    my ( $app_r, $completed_lines ) = @_;
    my $wall_coverage = 0;
    while ( $wall_coverage < $HEIGHT_PX ) {
        my $h =
            $wall_coverage + $WALL_HEIGHT > $HEIGHT_PX
          ? $HEIGHT_PX - $wall_coverage
          : $WALL_HEIGHT;
        $wall->blit(
            $app_r,
            [ 0, 0, $WALL_WIDTH, $h ],
            [ $WIDTH * $BLOCK_SIZE, $wall_coverage ]
        );
        $wall_coverage += $WALL_HEIGHT;
    }

    # The logo sits at the top right of the screen right of the wall.
    Readonly::Scalar my $WALL_X => $WIDTH * $BLOCK_SIZE + 60;
    Readonly::Scalar my $WALL_Y => 20;
    $logo->blit(
        $app_r,
        [ 0, 0, $LOGO_WIDTH, $LOGO_HEIGHT ],
        [ $WALL_X, $WALL_Y ]
    );

    # Write the number of completed lines.
    Readonly::Scalar my $LINES_X => $WIDTH * $BLOCK_SIZE + 60;
    Readonly::Scalar my $LINES_Y => 100;
    $font_small->write_xy( $app_r, $LINES_X, $LINES_Y,
        'Lines: ' . $completed_lines );

    # Write the current game level.
    Readonly::Scalar my $LEVEL_X => $WIDTH * $BLOCK_SIZE + 60;
    Readonly::Scalar my $LEVEL_Y => 180;
    $font_small->write_xy( $app_r, $LEVEL_X, $LEVEL_Y,
        'Level: ' . int( $completed_lines / $LINES_PER_LEVEL ) );

    # Draw the next tetromino piece.
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        Readonly::Scalar my $X =>
          ( $STARTING_POSITIONS[ $next_piece - 1 ][$i][0] + $WIDTH + 4 ) *
          $BLOCK_SIZE;
        Readonly::Scalar my $Y =>
          ( $STARTING_POSITIONS[ $next_piece - 1 ][$i][1] +
              ( 4 > $HEIGHT / 2 - 1 ? 4 : $HEIGHT / 2 - 1 ) ) *
          $BLOCK_SIZE;
        my $block = $blocks[$next_piece];
        $block->blit( $app_r, [ 0, 0, $BLOCK_SIZE, $BLOCK_SIZE ], [ $X, $Y ] );
    }
    return;
}

sub draw_screen {
    my ( $app_r, $state, $completed_lines ) = @_;
    $app->draw_rect( [ 0, 0, $app->w, $app->h ], 0 );
    draw_board($app_r);
    draw_status( $app_r, $completed_lines );

    if ( $state == $STATE_GAMEOVER ) {

        # Clear a rectangle for the game-over message and write the message.
        Readonly::Scalar my $MSG_X        => $WIDTH_PX * 0.05;
        Readonly::Scalar my $MSG_Y        => $HEIGHT_PX * 0.4375;
        Readonly::Scalar my $MSG_Y_CENTER => $HEIGHT_PX * 0.49;
        Readonly::Scalar my $MSG_WIDTH    => $WIDTH_PX * 0.9;
        Readonly::Scalar my $MSG_HEIGHT   => $HEIGHT_PX * 0.125;
        $app_r->draw_rect( [ 0, $MSG_Y, $app->w, $MSG_HEIGHT ], 0 );
        $font_large->write_xy( $app, $MSG_X, $MSG_Y_CENTER,
            'The only winning move is not to play' );
    }
    return;
}

sub rotate {
    my ( $board_r, $coords_r, $piece ) = @_;
    my @new_coords = ( [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] );
    my $rotation   = $ROTATIONS[ $piece - 1 ][$current_orientation];
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        $new_coords[$i][0] = $coords_r->[$i][0] + $rotation->[$i][0];
        $new_coords[$i][1] = $coords_r->[$i][1] + $rotation->[$i][1];
    }

    # Clear the board where the piece currently is to not detect self collision.
    set_coords( $board_r, $coords_r, 0 );
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        Readonly::Scalar my $X => $new_coords[$i][0];
        Readonly::Scalar my $Y => $new_coords[$i][1];

        # Collision is hitting the left wall, right wall, top, bottom, or a
        # non-black block.
        if (   $X < 0
            || $X >= $WIDTH
            || $Y < 0
            || $Y >= $HEIGHT
            || $board_r->[$Y][$X] )
        {
            # Restore the current piece.
            set_coords( $board_r, $coords_r, $piece );
            return 0;
        }
    }

    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        $coords_r->[$i][0] = $new_coords[$i][0];
        $coords_r->[$i][1] = $new_coords[$i][1];
        $board_r->[ $new_coords[$i][1] ][ $new_coords[$i][0] ] = $piece;
    }
    $current_orientation = ( $current_orientation + 1 ) % $NUM_ORIENTATIONS;
    return 1;
}

sub move_tetromino {
    my ( $dx, $dy ) = @_;

    # Clear the board where the piece currently is.
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        Readonly::Scalar my $X => $current_coords[$i][0];
        Readonly::Scalar my $Y => $current_coords[$i][1];
        $board[$Y][$X] = 0;
    }

    # Update the current piece's coordinates and fill the board in the new
    # coordinates.
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        $current_coords[$i][0] += $dx;
        $current_coords[$i][1] += $dy;
        $board[ $current_coords[$i][1] ][ $current_coords[$i][0] ] =
          $current_piece;
    }
    return;
}

sub set_coords {
    my ( $board_r, $coords_r, $piece ) = @_;
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        $board_r->[ $coords_r->[$i][1] ][ $coords_r->[$i][0] ] = $piece;
    }
    return;
}

sub collision_detected {
    my ( $dx, $dy ) = @_;
    my $collision = 0;

    # Clear the board where the piece currently is to not detect self collision.
    set_coords( \@board, \@current_coords, 0 );
    for my $i ( 0 .. $BLOCKS_PER_PIECE - 1 ) {
        my $x = $current_coords[$i][0];
        my $y = $current_coords[$i][1];

        # Collision is hitting the left wall, right wall, bottom, or a non-black
        # block. Since this collision detection is only for movement, check the
        # top (y < 0) is not needed.
        if (   ( $x + $dx ) < 0
            || ( $x + $dx ) >= $WIDTH
            || ( $y + $dy ) >= $HEIGHT
            || $board[ $y + $dy ][ $x + $dx ] )
        {
            $collision = 1;
            last;
        }
    }

    # Restore the current piece.
    set_coords( \@board, \@current_coords, $current_piece );
    return $collision;
}

sub clear_board {
    my ($completed_lines_r) = @_;
    my $rows_deleted        = 0;
    my $row                 = $HEIGHT - 1;
    while ( $row >= $rows_deleted ) {
        my $has_hole = 0;
        foreach my $elem ( @{ $board[$row] } ) {
            $has_hole = $has_hole || !$elem;
        }
        if ( !$has_hole ) {
            my $deleted_row = $board[$row];
            my $y           = $row;
            while ( $y > $rows_deleted ) {
                $board[$y] = $board[ $y - 1 ];
                $y--;
            }
            $board[$rows_deleted] = [ (0) x $WIDTH ];
            $rows_deleted++;
        }
        else {
            $row--;
        }
    }
    ${$completed_lines_r} += $rows_deleted;
    if ( $rows_deleted > 0 ) {
        Readonly::Scalar my $CHANNEL_ANY => -1;
        SDL::Mixer::Channels::play_channel( $CHANNEL_ANY, $LINECLEAR_SAMPLE,
            0 );
    }
    return;
}

sub drop_check {
    my ( $game_ticks, $drop_ticks_r, $completed_lines ) = @_;
    Readonly::Scalar my $LEVEL => $completed_lines / $LINES_PER_LEVEL;
    Readonly::Scalar my $DROP_FRAMES => ( $MAX_LEVEL - $LEVEL ) > 1
      ? ( $MAX_LEVEL - $LEVEL )
      : 1;
    if ( $game_ticks >= ${$drop_ticks_r} + $DROP_FRAMES ) {
        ${$drop_ticks_r} = $game_ticks;
        return 1;
    }
    return 0;
}

SDL::Events::enable_key_repeat( $KEY_REPEAT_DELAY, $KEY_REPEAT_INTERVAL );

my $event           = SDL::Event->new();
my $state           = $STATE_IN_PLAY;
my $completed_lines = 0;
my $last_frame_ms   = SDL::get_ticks();
my $game_ticks      = 0;
my $drop_ticks      = 0;

add_board_piece( \$current_piece, \$next_piece );
$app->flip();
draw_screen( $app, $state, $completed_lines );
$snd->play($SONG_KOROBEINIKI);

print <<"EOF" or croak 'print';
TETЯIS:

  usage: $PROGRAM_NAME [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.

EOF

while ( $state != $STATE_GAMEOVER ) {
    my $changed = 0;
    SDL::Events::pump_events();
    while ( SDL::Events::poll_event($event) ) {
        given ( $event->type ) {
            when (SDL_QUIT) { quit(); }
            when (SDL_KEYDOWN) {
                given ( SDL::Events::get_key_name( $event->key_sym ) ) {
                    when (/q|esc/msx) { exit; }
                    when ('p') {
                        $state =
                            $state == $STATE_IN_PLAY
                          ? $STATE_PAUSE
                          : $STATE_IN_PLAY;
                    }
                    when ('f1') {
                        $snd->play($SONG_KOROBEINIKI);
                    }
                    when ('f2') {
                        $snd->play($SONG_BWV814MENUET);
                    }
                    when ('f3') {
                        $snd->play($SONG_RUSSIANSONG);
                    }
                }
            }
        }
        if ( $state == $STATE_IN_PLAY ) {
            given ( $event->type ) {
                when (SDL_KEYDOWN) {
                    given ( SDL::Events::get_key_name( $event->key_sym ) ) {
                        when (/q|esc/msx) { exit; }
                        when ('left') {
                            if ( !collision_detected( $LEFT_1, 0 ) ) {
                                $changed = 1;
                                move_tetromino( $LEFT_1, 0 );
                            }
                        }
                        when ('right') {
                            if ( !collision_detected( $RIGHT_1, 0 ) ) {
                                $changed = 1;
                                move_tetromino( $RIGHT_1, 0 );
                            }
                        }
                        when ('up') {
                            $changed = rotate( \@board, \@current_coords,
                                $current_piece );
                        }
                        when ('down') {
                            if ( !collision_detected( 0, $DOWN_1 ) ) {
                                $changed = 1;
                                move_tetromino( 0, $DOWN_1 );
                            }
                        }
                        when ('space') {
                            while ( !collision_detected( 0, $DOWN_1 ) ) {
                                $changed = 1;
                                move_tetromino( 0, $DOWN_1 );
                            }
                        }
                    }
                }
            }
        }
    }
    if ( $state == $STATE_IN_PLAY ) {
        if ( drop_check( $game_ticks, \$drop_ticks, $completed_lines ) ) {
            $changed = 1;
            if ( !collision_detected( 0, $DOWN_1 ) ) {
                move_tetromino( 0, $DOWN_1 );
            }
            else {
                clear_board( \$completed_lines );
                $state = add_board_piece( \$current_piece, \$next_piece );
            }
        }
    }
    if ($changed) {
        draw_screen( $app, $state, $completed_lines );
        $app->flip();
    }
    Readonly::Scalar my $NOW_MS => SDL::get_ticks();
    if ( ( $NOW_MS - $last_frame_ms ) >= $MS_PER_FRAME ) {
        $game_ticks++;
        $last_frame_ms = $NOW_MS;
    }
    SDL::delay(1);
}

# Game over.
$snd->stop();
SDL::Mixer::Music::play_music( SDL::Mixer::Music::load_MUS($SOUND_GAMEOVER),
    0 );

Readonly::Scalar my $POLL_DELAY => 10;
while (1) {
    while ( SDL::Events::poll_event($event) ) {
        given ( $event->type ) {
            when (SDL_QUIT) { quit(); }
            when (SDL_KEYDOWN) {
                given ( SDL::Events::get_key_name( $event->key_sym ) ) {
                    when (/q|esc/msx) { exit; }
                }
            }
        }
    }
    SDL::delay($POLL_DELAY);
}
