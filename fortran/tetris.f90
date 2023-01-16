! Author: Adam Rogoyski (adam@rogoyski.com).
! Public domain software.
!
! A tetris game.

program main
    use, intrinsic :: iso_c_binding, only: c_associated, c_null_char, c_ptr, c_null_ptr
    use, intrinsic :: iso_fortran_env, only: stdout => output_unit, stderr => error_unit
    use :: sdl2
    use :: sdl2_image
    use :: sdl2_mixer
    use :: sdl2_ttf
    implicit none

    integer, parameter :: WIDTH  = 10
    integer, parameter :: HEIGHT  = 20
    integer, parameter :: BLOCK_SIZE  = 96
    integer, parameter :: WIDTH_PX  = (WIDTH + 6) * BLOCK_SIZE + 50
    integer, parameter :: HEIGHT_PX = HEIGHT * BLOCK_SIZE
    integer, parameter :: NUM_TETROMINOS = 7
    integer, parameter :: FRAME_RATE_MS = int(1000.0 / 60.0)

    type(c_ptr)     :: window
    type(c_ptr)     :: renderer
    type(c_ptr)     :: font
    type(sdl_event) :: event
    type(sdl_rect)  :: src
    type(sdl_rect)  :: dst
    integer         :: rc
    type(sdl_color) :: red
    integer         :: current_piece
    integer         :: next_piece
    integer         :: current_coords(4, 2)
    integer         :: current_orientation = 1
    integer         :: completed_lines = 0
    integer         :: board(HEIGHT, WIDTH)
    integer         :: i, x, y
    logical         :: changed = .true.
    integer         :: last_frame_ms, now_ms
    integer         :: game_ticks = 0
    integer         :: drop_ticks = 0

    character(len=32) :: arg

    INTEGER(SELECTED_INT_KIND(3)), PARAMETER :: IN_PLAY = 0, PAUSED = 1, GAMEOVER = 2
    integer         :: status = IN_PLAY

    integer         :: starting_positions(NUM_TETROMINOS, 4, 2)
    integer, target :: rotations(NUM_TETROMINOS, 4, 4, 2)

    type(c_ptr) :: block_black
    type(c_ptr) :: block_blue
    type(c_ptr) :: block_cyan
    type(c_ptr) :: block_green
    type(c_ptr) :: block_orange
    type(c_ptr) :: block_purple
    type(c_ptr) :: block_red
    type(c_ptr) :: block_yellow
    type(c_ptr) :: blocks(8)
    type(c_ptr) :: logo
    type(c_ptr) :: wall

    type(sdl_surface), pointer :: surface
    type(c_ptr)                :: texture

    type(c_ptr) :: song_korobeiniki
    type(c_ptr) :: song_bwv814menuet
    type(c_ptr) :: song_russiansong
    type(c_ptr) :: sound_gameover

    board = reshape((/ (1, i = 1, HEIGHT*WIDTH) /), shape=shape(board), order=(/ 2, 1 /))

    ! Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
    starting_positions = reshape( (/ &
        -1, 0,   -1, 1,   0, 1,   1, 1, &    ! Leftward L piece.
        -1, 1,    0, 1,   0, 0,   1, 0, &    ! Rightward Z piece.
        -2, 0,   -1, 0,   0, 0,   1, 0, &    ! Long straight piece.
        -1, 1,    0, 1,   0, 0,   1, 1, &    ! Bump in middle piece.
        -1, 1,    0, 1,   1, 1,   1, 0, &    ! L piece.
        -1, 0,    0, 0,   0, 1,   1, 1, &    ! Z piece.
        -1, 0,   -1, 1,   0, 0,   0, 1 /), & ! Square piece.
        shape=(/ size(starting_positions, 1), size(starting_positions, 2), size(starting_positions, 3) /), &
        order=(/ 3, 2, 1 /) )

    ! Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
    ! Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
    ! For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
    ! The coordinate diffs map each block to its new location.
    ! Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
    rotations = reshape ( (/ &
        ! Leftward L piece. &
        0, 2,   1, 1,   0, 0,  -1,-1, &
        2, 0,   1,-1,   0, 0,  -1, 1, &
        0,-2,  -1,-1,   0, 0,   1, 1, &
       -2 ,0,  -1, 1,   0, 0,   1,-1, &
        ! Rightward Z piece. Orientation symmetry: 0==2 and 1==3. &
        1, 0,   0, 1,  -1, 0,  -2, 1, &
       -1, 0,   0,-1,   1, 0,   2,-1, &
        1, 0,   0, 1,  -1, 0,  -2, 1, &
       -1, 0,   0,-1,   1, 0,   2,-1, &
        ! Long straight piece. Orientation symmetry: 0==2 and 1==3. &
        2,-2,   1,-1,   0, 0,  -1, 1, &
       -2, 2,  -1, 1,   0, 0,   1,-1, &
        2,-2,   1,-1,   0, 0,  -1, 1, &
       -2, 2,  -1, 1,   0, 0,   1,-1, &
        ! Bump in middle piece. &
        1, 1,   0, 0,  -1, 1,  -1,-1, &
        1,-1,   0, 0,   1, 1,  -1, 1, &
       -1,-1,   0, 0,   1,-1,   1, 1, &
       -1, 1,   0, 0,  -1,-1,   1,-1, &
        ! L Piece. &
        1, 1,   0, 0,  -1,-1,  -2, 0, &
        1,-1,   0, 0,  -1, 1,   0, 2, &
       -1,-1,   0, 0,   1, 1,   2, 0, &
       -1, 1,   0, 0,   1,-1,   0,-2, &
        ! Z piece. Orientation symmetry: 0==2 and 1==3. &
        1, 0,   0, 1,  -1, 0,  -2, 1, &
       -1, 0,   0,-1,   1, 0,   2,-1, &
        1, 0,   0, 1,  -1, 0,  -2, 1, &
       -1, 0,   0,-1,   1, 0,   2,-1, &
        ! Square piece. Orientation symmetry: 0==1==2==3. &
        0, 0,   0, 0,   0, 0,   0, 0, &
        0, 0,   0, 0,   0, 0,   0, 0, &
        0, 0,   0, 0,   0, 0,   0, 0, &
        0, 0,   0, 0,   0, 0,   0, 0  /), &
        shape=(/ size(rotations, 1), size(rotations, 2), &
                 size(rotations, 3), size(rotations, 4) /), &
        order=(/ 4, 3, 2, 1 /) )

    call srand(XOR(time(), LSHIFT(getpid(), 16) + getpid()))
    current_piece = 1 + mod(irand(), 7)
    next_piece = 1 + MOD(irand(), 7)

    if (sdl_init(SDL_INIT_VIDEO) < 0) then
        write (stderr, *) 'SDL Error: ', sdl_get_error()
        stop
    end if
    if (img_init(IMG_INIT_PNG) < 0) then
        write (stderr, *) 'SDL Error: ', sdl_get_error()
        stop
    end if
    if (ttf_init() < 0) then
        write (stderr, *) 'TTF Error: ', sdl_get_error()
        stop
    end if

    ! Create the SDL window.
    window = sdl_create_window('TETRIS' // c_null_char, &
                               SDL_WINDOWPOS_UNDEFINED, &
                               SDL_WINDOWPOS_UNDEFINED, &
                               WIDTH_PX, &
                               HEIGHT_PX, &
                               SDL_WINDOW_SHOWN)

    if (.not. c_associated(window)) then
        write (stderr, *) 'SDL Error: ', sdl_get_error()
        stop
    end if

    ! Create the renderer.
    renderer = sdl_create_renderer(window, -1, 0)

    block_black  = img_load_texture(renderer, 'graphics/block_black.png'  // c_null_char)
    block_blue   = img_load_texture(renderer, 'graphics/block_blue.png'   // c_null_char)
    block_cyan   = img_load_texture(renderer, 'graphics/block_cyan.png'   // c_null_char)
    block_green  = img_load_texture(renderer, 'graphics/block_green.png'  // c_null_char)
    block_orange = img_load_texture(renderer, 'graphics/block_orange.png' // c_null_char)
    block_purple = img_load_texture(renderer, 'graphics/block_purple.png' // c_null_char)
    block_red    = img_load_texture(renderer, 'graphics/block_red.png'    // c_null_char)
    block_yellow = img_load_texture(renderer, 'graphics/block_yellow.png' // c_null_char)
    blocks = (/ block_black, block_blue, block_cyan, block_green, block_orange, block_purple, block_red, block_yellow /)
    logo = img_load_texture(renderer, 'graphics/logo.png' // c_null_char)
    wall = img_load_texture(renderer, 'graphics/wall.png' // c_null_char)

    font = ttf_open_font('fonts/Montserrat-Regular.ttf' // c_null_char, 48)
    red  = sdl_color(uint8(255), uint8(0), uint8(0), uint8(SDL_ALPHA_OPAQUE))

    rc = mix_open_audio(MIX_DEFAULT_FREQUENCY, AUDIO_S16LSB, MIX_DEFAULT_CHANNELS, 4096)
    song_korobeiniki = mix_load_wav('sound/korobeiniki.wav' // c_null_char)
    song_bwv814menuet = mix_load_wav('sound/bwv814menuet.wav' // c_null_char)
    song_russiansong = mix_load_wav('sound/bwv814menuet.wav' // c_null_char)
    sound_gameover = mix_load_wav('sound/gameover.wav' // c_null_char)
    rc = mix_play_channel(0, song_korobeiniki, -1)

    status = add_board_piece()
    last_frame_ms = sdl_get_ticks()

    call get_command_argument(0, arg)
    print *, ''
    print *, 'TETЯIS:'
    print *, ''
    print *, '  usage: ', trim(arg), ' [level 1-15]'
    print *, ''
    print *, '  F1  - Korobeiniki (gameboy song A).'
    print *, '  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).'
    print *, '  F3  - Russion song (gameboy song C).'
    print *, '  ESC - Quit.'
    print *, '  p   - Pause.'
    print *, ''
    print *, '  Up - Rotate.'
    print *, '  Down - Lower.'
    print *, '  Space - Drop completely.'
    print *, ''

    call get_command_argument(1, arg)
    if (len_trim(arg) /= 0) then
      read(arg, *) completed_lines
      completed_lines = max(min(15, completed_lines), 0)
      completed_lines = completed_lines * 3
    end if

    do while (status /= GAMEOVER)
        do while (sdl_poll_event(event) > 0)
            select case (event%type)
                case (SDL_QUITEVENT)
                    goto 999
                case (SDL_KEYDOWN)
                    select case (event%key%key_sym%sym)
                        case (SDLK_Q)
                            goto 999
                        case (SDLK_ESCAPE)
                            goto 999
                        case (SDLK_P)
                            status = merge(PAUSED, IN_PLAY, status == IN_PLAY)
                        case (SDLK_F1)
                            rc = mix_play_channel(0, song_korobeiniki, -1)
                        case (SDLK_F2)
                            rc = mix_play_channel(0, song_bwv814menuet, -1)
                        case (SDLK_F3)
                            rc = mix_play_channel(0, song_russiansong, -1)
                    end select
            end select

            if (status == IN_PLAY) then
                select case (event%type)
                    case (SDL_KEYDOWN)
                        select case (event%key%key_sym%sym)
                            case (SDLK_LEFT)
                                if (.not. collision_detected(-1, 0)) then
                                    changed = .true.
                                    call move_tetromino(-1, 0)
                                end if
                            case (SDLK_Right)
                                if (.not. collision_detected(1, 0)) then
                                    changed = .true.
                                    call move_tetromino(1, 0)
                                end if
                            case (SDLK_Down)
                                if (.not. collision_detected(0, 1)) then
                                    changed = .true.
                                    call move_tetromino(0, 1)
                                end if
                            case (SDLK_Space)
                                do while (.not. collision_detected(0, 1))
                                    changed = .true.
                                    call move_tetromino(0, 1)
                                end do
                            case (SDLK_Up)
                                changed = rotate()
                        end select
                end select
            end if
        end do

        if (status == IN_PLAY) then
            if (game_ticks >= drop_ticks + max(15 - int(completed_lines / 3), 1)) then
                changed = .true.
                drop_ticks = game_ticks
                if (.not. collision_detected(0, 1)) then
                    call move_tetromino(0, 1)
                else
                    call clear_board
                    current_orientation = 1
                    current_piece = next_piece
                    next_piece = 1 + mod(irand(), 7)
                    status = add_board_piece()
                end if
            end if
        end if

        if (changed) then
            call draw_screen
        end if

        now_ms = sdl_get_ticks()
        if ((now_ms - last_frame_ms) >= FRAME_RATE_MS) then
            game_ticks = game_ticks + 1
            last_frame_ms = now_ms
        end if
        call sdl_delay(1)
    end do

    ! Game over condition.
    ! Clear a rectangle for the game-over message and write the message.
    src = sdl_rect(0, 0, WIDTH_PX, int(HEIGHT_PX*0.125))
    dst = sdl_rect(0, int(HEIGHT_PX*0.4375), WIDTH_PX, int(HEIGHT_PX*0.125))
    rc = sdl_render_copy(renderer, block_black, src, dst)

    surface => ttf_render_text_solid(font, 'The only winning move is not to play' // c_null_char, red)
    texture = sdl_create_texture_from_surface(renderer, surface)
    src     = sdl_rect(0, 0, surface%w, surface%h)
    dst     = sdl_rect(int(WIDTH_PX*0.05), INT(HEIGHT_PX*0.4375), int(WIDTH_PX*0.90), INT(HEIGHT_PX*0.125))
    rc = sdl_render_copy(renderer, texture, src, dst)
    call sdl_free_surface(surface)
    call sdl_destroy_texture(texture)
    call sdl_render_present(renderer)
    rc = mix_play_channel(0, sound_gameover, 0)

    do while (.true.)
        do while (sdl_poll_event(event) > 0)
            select case (event%type)
                case (SDL_QUITEVENT)
                    goto 999
                case (SDL_KEYDOWN)
                    select case (event%key%key_sym%sym)
                        case (SDLK_Q)
                            goto 999
                        case (SDLK_ESCAPE)
                            goto 999
                    end select
            end select
        end do
    end do

999 call sdl_destroy_renderer(renderer)
    call sdl_destroy_window(window)
    call sdl_quit()

contains
    subroutine clear_board()
        integer :: rows_deleted
        integer :: row
        logical :: has_hole
        integer :: x,y
        integer :: deleted_row(WIDTH)

        ! Clear completed (filled) rows.
        ! Start from the bottom of the board, moving all rows down to fill in a completed row, with
        ! the completed row cleared and placed at the top.
        rows_deleted = 0
        row = HEIGHT
        do while (row > rows_deleted)
            has_hole = .false.
            x = 0
            do while (x <= WIDTH .and. .not. has_hole)
                has_hole = board(row,x) == 1
                x = x + 1
            end do
            if (.not. has_hole) then
                deleted_row = board(row,:)
                y = row
                do while (y > rows_deleted)
                  board(y,:) = board(y-1,:)
                  y = y - 1
                end do
                board(rows_deleted+1,:) = deleted_row
                do y=1,WIDTH
                    board(rows_deleted+1,y) = 1
                end do
                rows_deleted = rows_deleted + 1
            else
                row = row - 1
            end if
        end do
        completed_lines = completed_lines + rows_deleted
    end subroutine clear_board

    function rotate()
        logical          :: rotate
        integer          :: new_coords(4, 2)
        integer, pointer :: rotation(:,:)
        integer          :: i, x, y

        rotation => rotations(current_piece, current_orientation, :, :)
        do i=1,4
            new_coords(i,1) = current_coords(i,1) + rotation(i,1)
            new_coords(i,2) = current_coords(i,2) + rotation(i,2)
        end do

        ! Clear the board where the piece currently is to not detect self collision.
        call set_coords(current_coords, 1)
        do i=1,4
            x = new_coords(i,1)
            y = new_coords(i,2)
            ! Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
            if (x <= 0 .or. x > WIDTH .or. y <= 0 .or. y > HEIGHT .or. board(y,x) /= 1) then
                call set_coords(current_coords, current_piece + 1)
                rotate = .false.
                return
            end if
        end do

        do i=1,4
            current_coords(i,1) = new_coords(i,1)
            current_coords(i,2) = new_coords(i,2)
            board(new_coords(i,2), new_coords(i,1)) = current_piece + 1
        end do
        current_orientation = current_orientation + 1
        if (current_orientation >= 5) then
            current_orientation = 1
        end if
        rotate = .true.
    end function rotate

    subroutine set_coords(coords, piece)
        integer, intent(in) :: coords(4, 2)
        integer, intent(in) :: piece
        integer             :: i

        do i=1,4
            board(coords(i,2), coords(i,1)) = piece
        end do
    end subroutine set_coords

    function collision_detected(dx, dy)
        integer, intent(in) :: dx, dy
        logical             :: collision_detected
        integer             :: i

        collision_detected = .false.
        ! Clear the board where the piece currently is to not detect self collision.
        call set_coords(current_coords, 1)
        do i=1,4
            x = current_coords(i,1)
            y = current_coords(i,2)
            if ((x + dx) <= 0 .or. (x + dx) > WIDTH .or. (y + dy) > HEIGHT .or. board(y+dy,x+dx) /= 1) then
                collision_detected = .true.
            end if
        end do
        ! Restore the current piece.
        call set_coords(current_coords, current_piece + 1)
    end function collision_detected

    subroutine move_tetromino(dx, dy)
        integer, intent(in) :: dx, dy

        do i=1,4
            x = current_coords(i,1)
            y = current_coords(i,2)
            board(y,x) = 1
        end do
        do i=1,4
            current_coords(i,1) = current_coords(i, 1) + dx
            current_coords(i,2) = current_coords(i, 2) + dy
            board(current_coords(i,2), current_coords(i,1)) = current_piece + 1
        end do
    end subroutine move_tetromino

    function add_board_piece()
        integer            :: add_board_piece
        integer, parameter :: center = WIDTH / 2
        integer            :: i, x, y

        add_board_piece = IN_PLAY
        do i=1,4
            x = center + starting_positions(current_piece, i, 1) + 1
            y = starting_positions(current_piece, i, 2) + 1
            if (board(y, x) /= 1) then
                add_board_piece = GAMEOVER
                return
            end if
        end do
        do i=1,4
            x = center + starting_positions(current_piece, i, 1) + 1
            y = starting_positions(current_piece, i, 2) + 1
            board(y, x) = current_piece + 1
            current_coords(i,1) = x
            current_coords(i,2) = y
        end do
    end function add_board_piece

    subroutine draw_screen()
        type(sdl_surface), pointer :: surface
        type(c_ptr)                :: texture
        integer, parameter         :: LEFT_BORDER  = WIDTH*BLOCK_SIZE + 50 + INT(6*BLOCK_SIZE*0.05)
        integer, parameter         :: STATUS_WIDTH = INT(6*BLOCK_SIZE*0.90)
        character(len=11)          :: status_msg
        integer                    :: np_left, np_top, x, y

        rc = sdl_render_clear(renderer)
        rc = sdl_set_render_draw_color(renderer, &
                                       uint8(0), &
                                       uint8(0), &
                                       uint8(0), &
                                       uint8(SDL_ALPHA_OPAQUE))

        ! Wall extends from top to bottom, separating the board from the status area.
        src = sdl_rect(0, 0, 50, 640)
        dst = sdl_rect(WIDTH*BLOCK_SIZE, 0, 50, HEIGHT_PX)
        rc = sdl_render_copy(renderer, wall, src, dst)

        ! The logo sits at the top right of the screen right of the wall.
        src = sdl_rect(0, 0, 99, 44)
        dst = sdl_rect(LEFT_BORDER, 0, STATUS_WIDTH, INT(HEIGHT_PX*0.20))
        rc = sdl_render_copy(renderer, logo, src, dst)

        write (status_msg, "(A7,I3)") "Lines: ", completed_lines
        surface => ttf_render_text_solid(font, status_msg // c_null_char, red)
        texture = sdl_create_texture_from_surface(renderer, surface)
        src     = sdl_rect(0, 0, surface%w, surface%h)
        dst     = sdl_rect(LEFT_BORDER, INT(HEIGHT_PX*0.25), STATUS_WIDTH, INT(HEIGHT_PX*0.05))
        rc = sdl_render_copy(renderer, texture, src, dst)
        call sdl_free_surface(surface)
        call sdl_destroy_texture(texture)

        write (status_msg, "(A7,I3)") "Level: ", int(completed_lines / 3)
        surface => ttf_render_text_solid(font, status_msg // c_null_char, red)
        texture = sdl_create_texture_from_surface(renderer, surface)
        src     = sdl_rect(0, 0, surface%w, surface%h)
        dst     = sdl_rect(LEFT_BORDER, INT(HEIGHT_PX*0.35), STATUS_WIDTH, INT(HEIGHT_PX*0.05))
        rc = sdl_render_copy(renderer, texture, src, dst)
        call sdl_free_surface(surface)
        call sdl_destroy_texture(texture)

        ! Draw the next tetromino piece.
        do i=1,4
            np_top = int(HEIGHT_PX * 0.45)
            np_left = (WIDTH + 2)*BLOCK_SIZE + 50 + int(6*BLOCK_SIZE*0.05)
            x = np_left + starting_positions(next_piece,i,1)*BLOCK_SIZE
            y = np_top  + starting_positions(next_piece,i,2)*BLOCK_SIZE
            src = sdl_rect(0, 0, BLOCK_SIZE, BLOCK_SIZE)
            dst = sdl_rect(x, y, BLOCK_SIZE, BLOCK_SIZE)
            rc = sdl_render_copy(renderer, blocks(next_piece+1), src, dst)
        end do

        ! The the play board.
        do x = 0,WIDTH-1
            do y = 0,HEIGHT-1
                    src = sdl_rect(0, 0, BLOCK_SIZE, BLOCK_SIZE)
                    dst = sdl_rect(x*BLOCK_SIZE, y*BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
                    rc = sdl_render_copy(renderer, blocks(board(y+1, x+1)), src, dst)
            end do
        end do

        call sdl_render_present(renderer)
    end subroutine draw_screen
end program main
