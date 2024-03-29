; Author: Adam Rogoyski (adam@rogoyski.com).
; Public domain software.
;
; A tetris game.

(use-modules (chickadee)       ; https://dthompson.us/projects/chickadee.html
             (chickadee graphics 9-patch)
             (chickadee graphics sprite)
             (chickadee graphics texture)
             (srfi srfi-1)     ; https://www.gnu.org/software/guile/manual/html_node/SRFI_002d1-Fold-and-Map.html
             (ice-9 copy-tree) ; https://www.gnu.org/software/guile/manual/html_node/Copying.html
             (ice-9 match))    ; https://www.gnu.org/software/guile/manual/html_node/Pattern-Matching.html

(set! *random-state* (random-state-from-platform))

(define logo         (load-image "graphics/logo.png"))
(define wall         (load-image "graphics/wall.png"))
(define block-black  (load-image "graphics/block_black.png"))
(define block-blue   (load-image "graphics/block_blue.png"))
(define block-cyan   (load-image "graphics/block_cyan.png"))
(define block-green  (load-image "graphics/block_green.png"))
(define block-orange (load-image "graphics/block_orange.png"))
(define block-purple (load-image "graphics/block_purple.png"))
(define block-red    (load-image "graphics/block_red.png"))
(define block-yellow (load-image "graphics/block_yellow.png"))
(define block-colors (list block-blue block-cyan block-green block-orange block-purple block-red block-yellow))

(define song-bwv814menuet (load-audio "sound/bwv814menuet.wav"))
(define song-korobeiniki  (load-audio "sound/korobeiniki.wav"))
(define song-russiansong  (load-audio "sound/russiansong.wav"))
(define sound-gameover  (load-audio "sound/gameover.wav"))
(define sound-lineclear (load-audio "sound/lineclear.wav"))
(define (swap-music song)
  (source-stop music-loop)
  (set-source-audio! music-loop song)
  (source-play music-loop))
(define music-loop (make-source #:audio song-korobeiniki #:loop? #t))
(set-source-audio! music-loop song-korobeiniki)
(source-play music-loop)

(define font-small (load-font "fonts/Montserrat-Regular.ttf" 20))
(define font-big (load-font "fonts/Montserrat-Regular.ttf" 30))
(define color-red (make-color 1.0 0.0 0.0 1.0))

; One of ('play 'pause 'gameover).
(define game-state 'play)

; The screen and the board rows both go left to right. The screen pixel 0 is at the bottom, whereas the board row 0 is at top.
(define board.block.width 10)
(define board.block.height 20)
(define square-size 32)
(define height-px (* board.block.height square-size))
(define width-px (+ (* (+ board.block.width 6) square-size) 50))
(define (make-board-rows board width height)
  (define (make-row n)
    (if (= n 0)
        '()
        (cons block-black (make-row (- n 1)))))
  (define (make-rows width n)
    (if (= n 0)
        '()
        (cons (make-row width)
              (make-rows width (- n 1)))))
  (append (make-rows board.block.width (- board.block.height (length board))) board))
(define board (make-board-rows '() board.block.width board.block.height))
(define completed-lines 0)
(define reduce-speed 0)  ; Increment to lower the block drop speed.
(define next-piece-type (random 7))
(define current-piece-type (random 7))
(define current-piece-coords #f)
(define current-piece-rotation 0)
(define starting-positions
  (let ((center (floor (/ board.block.width 2))))
    (list
       (list (list (- center 1) 0) (list (- center 1) 1) (list center 1) (list (+ center 1) 1) ) ; Leftward L piece.
       (list (list (- center 1) 1) (list center 1) (list center 0) (list (+ center 1) 0) )       ; Rightward Z piece.
       (list (list (- center 2) 0) (list (- center 1) 0) (list center 0) (list (+ center 1) 0) ) ; Long straight piece.
       (list (list (- center 1) 1) (list center 1) (list center 0) (list (+ center 1) 1) )       ; Bump in middle piece.
       (list (list (- center 1) 1) (list center 1) (list (+ center 1) 1) (list (+ center 1) 0) ) ; L piece.
       (list (list (- center 1) 0) (list center 0) (list center 1) (list (+ center 1) 1) )       ; Z piece.
       (list (list (- center 1) 0) (list (- center 1) 1) (list center 0) (list center 1) )       ; Square piece.
     )))

(define key-press (lambda (key modifiers repeat?) #f))
(define update (lambda (dt) #f))

; Useful to dump the board for debugging or unit tests.
(define (draw-board-ascii board)
  (for-each (lambda (row)
              (for-each (lambda (elem)
                          (display (if (eq? block-black elem) "_" "o")) (display " "))
                        row)
              (newline))
            board))

; Return new coordinates (x,y) -> (x+dx, y+dy).
(define (update-coords coords dx dy)
  (map (lambda (coord)
         (let ((x (car coord))
               (y (cadr coord)))
           (list (+ x dx) (+ y dy))))
       coords))

; Determine if the coordinates collide with any non-black blocks on the board.
(define (collision-detected board coords)
  (define (collision coord)
    (let* ((row (cadr coord))
           (column (car coord))
           (board-value (list-ref (list-ref board row) column)))
      (if (eq? board-value block-black)
        #f
        #t)))
  (not (eq? '() (filter collision coords))))

; Detect if move the specified coords by dx,dy would lead to a collision on the board with non-black pieces.
; Since the piece is moving, clear it from a copy of the board so it won't collide with itself.
(define (collision-detected-moving board coords dx dy)
  (define tboard (copy-tree board))
  (add-board-piece tboard coords block-black)
  (collision-detected tboard (update-coords coords dx dy)))

; A piece is 4 colored blocks. Place one block on the board. Placing black blocks clears board.
(define (add-board-block board coords color)
  (let* ((x (car coords))
         (y (cadr coords))
         (row (list-ref board y)))
    (list-set! row x color)))

; Place all 4 pieces of a block on the board by setting the piece's color at its coordinates.
(define (add-board-piece board coords color)
  (for-each (lambda (coord) (add-board-block board coord color)) coords))

; End the game by changing game state, restricting input, stopping updates, and announcing game over.
(define (game-over)
  (let ((key-press-game-over (lambda (key modifiers repeat?)
                               (match key
                               ('q (abort-game))
                               ('escape (abort-game))
                               (_ #t)))))
    (set! game-state 'gameover)
    (set! key-press key-press-game-over)
    (set! update (lambda (x) #t))
    (display "Game Over\n")
    (source-stop music-loop)
    (audio-play sound-gameover)))

; Add a new piece to the board. If the new piece collides, the game is over.
(define (add-new-piece board current-piece-type)
  (let ((coords (list-ref starting-positions current-piece-type))
        (color (list-ref block-colors current-piece-type)))
    (set! current-piece-coords (copy-tree coords))
    (let ((game-over-condition (collision-detected board coords)))
      (if game-over-condition
        (game-over)
        (add-board-piece board coords color)))))

; Add the initial tetromino to the board.
(add-new-piece board current-piece-type)

; List of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
; Each rotation is a list of 4 rotations -- one for each orientation of a tetromino.
; For each rotation, there is a list of 4 (x, y) coordinate diffs for each block of the tetromino.
; The coordinate diffs map each block to its new location.
; Thus: [block][orientation][component] to map the 4 components of each block in each orientation.
(define rotations
  '(
    ( ; Leftward L piece.
      ((0 2) (1 1) (0 0) (-1 -1))
      ((2 0) (1 -1) (0 0) (-1 1))
      ((0 -2) (-1 -1) (0 0) (1 1))
      ((-2 0) (-1 1) (0 0) (1 -1)))
    ( ; Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
      ((1 0) (0 1) (-1 0) (-2 1))
      ((-1 0) (0 -1) (1 0) (2 -1))
      ((1 0) (0 1) (-1 0) (-2 1))
      ((-1 0) (0 -1) (1 0) (2 -1)))
    ( ; Long straight piece. Orientation symmetry: 0==2 and 1==3.
      ((2 -2) (1 -1) (0 0) (-1 1))
      ((-2 2) (-1 1) (0 0) (1 -1))
      ((2 -2) (1 -1) (0 0) (-1 1))
      ((-2 2) (-1 1) (0 0) (1 -1)))
    ( ; Bump in middle piece.
      ((1 1) (0 0) (-1 1) (-1 -1))
      ((1 -1) (0 0) (1 1) (-1 1))
      ((-1 -1) (0 0) (1 -1) (1 1))
      ((-1 1) (0 0) (-1 -1) (1 -1)))
    ( ; L Piece.
      ((1 1) (0 0) (-1 -1) (-2 0))
      ((1 -1) (0 0) (-1 1) (0 2))
      ((-1 -1) (0 0) (1 1) (2 0))
      ((-1 1) (0 0) (1 -1) (0 -2)))
    ( ; Z piece. Orientation symmetry: 0==2 and 1==3.
      ((1 0) (0 1) (-1 0) (-2 1))
      ((-1 0) (0 -1) (1 0) (2 -1))
      ((1 0) (0 1) (-1 0) (-2 1))
      ((-1 0) (0 -1) (1 0) (2 -1)))
    ( ; Square piece. Orientation symmetry: 0==1==2==3.
      ((0 0) (0 0) (0 0) (0 0))
      ((0 0) (0 0) (0 0) (0 0))
      ((0 0) (0 0) (0 0) (0 0))
      ((0 0) (0 0) (0 0) (0 0)))))

; Check if the coordinates are within the bounds of the playing board rectangle from (0,0) to (width-1, height-1).
(define (within-bounds coords)
  (if (null? coords)
    #t
    (let ((x (caar coords))
          (y (cadar coords)))
      (and (>= x 0)
           (>= y 0)
           (< x board.block.width)
           (< y board.block.height)
           (within-bounds (cdr coords))))))

; Rotate the current piece if possible. Remove it from a temporary board, rotate its coordinates, and if it is within
; the board bounds and not colliding with another piece, commit the rotation to the board.
(define (try-rotation board current-piece-type)
  (let ((tboard (copy-tree board))
        (tcoords (copy-tree current-piece-coords))
        (rotation (list-ref (list-ref rotations current-piece-type) current-piece-rotation))
        (color (list-ref block-colors current-piece-type)))
    (add-board-piece tboard current-piece-coords block-black)
    (for-each
      (lambda (coord crot)
        (set-car!  coord   (+ (car  coord) (car  crot)))
        (list-set! coord 1 (+ (cadr coord) (cadr crot))))
      tcoords rotation)
    (cond ((within-bounds tcoords)
           (cond ((not (collision-detected tboard tcoords))
                  (add-board-piece board current-piece-coords block-black)
                  (add-board-piece board tcoords color)
                  (set! current-piece-rotation (modulo (+ current-piece-rotation 1) 4))
                  (set! current-piece-coords tcoords)))))))

(define (key-press key modifiers repeat?)
  (match key
    ('q (abort-game))
    ('escape (abort-game))
    ('f1 (swap-music song-bwv814menuet))
    ('f2 (swap-music song-korobeiniki))
    ('f3 (swap-music song-russiansong))
    ('p (if (eq? game-state 'play)
            (set! game-state 'pause)
            (set! game-state 'play)))
    (_ #t))

  (if (eq? game-state 'play)
    (match key
      ('left
        (let ((collided-left-wall (> (length (filter-map (lambda (x) (= (car x) 0)) current-piece-coords)) 0)))
          (cond ((not (or collided-left-wall
                          (collision-detected-moving board current-piece-coords -1 0)))
                 (move-tetromino board -1 0)))))
      ('right
        (let ((collided-right-wall (> (length (filter-map (lambda (x) (= (car x) (- board.block.width 1))) current-piece-coords)) 0)))
          (cond ((not (or collided-right-wall
                          (collision-detected-moving board current-piece-coords 1 0)))
                 (move-tetromino board 1 0)))))
      ('down
        (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- board.block.height 1))) current-piece-coords)) 0)))
          (cond ((not (or bottomed_out
                          (collision-detected-moving board current-piece-coords 0 1)))
                 (move-tetromino board 0 1)))))
      ('up
        (try-rotation board current-piece-type))
      ('space
        (letrec ((down-iter (lambda ()
          (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- board.block.height 1))) current-piece-coords)) 0)))
            (cond ((not (or bottomed_out
                            (collision-detected-moving board current-piece-coords 0 1)))
                   (move-tetromino board 0 1)
                   (down-iter)))))))
          (down-iter)))
      (_ #t))))

(define (draw alpha)
  (define (draw-row row rownum colnum)
    (cond ((not (null? row))
           (let ((x (* colnum square-size))
                 (y (* (- (- board.block.height rownum) 1) square-size)))
             (draw-sprite (car row) (vec2 x y))
             (draw-row (cdr row) rownum (+ colnum 1))))))
  (define (draw-board board rownum)
    (cond ((not (null? board))
           (draw-row (car board) rownum 0)
           (draw-board (cdr board) (+ rownum 1)))))
  ; The height of the screen may be larger than the wall image, so draw it until filled.
  (define (draw-wall height)
    (let ((max-height (* board.block.height square-size)))
      (cond ((< height max-height)
             (draw-sprite wall (vec2 (* board.block.width square-size) height))
             (draw-wall (+ height 640))))))
  ; Clear the screen black to the right of the board.
  (draw-9-patch block-black (make-rect 0 0 width-px height-px))
  (draw-board board 0)
  (draw-wall 0)
  (let ((left_border (+ (* board.block.width square-size) 50 (inexact->exact (floor (* 6 square-size 0.05)))))
        (width (inexact->exact (floor (* 6 square-size 0.90))))
        (line-height (inexact->exact (floor (* height-px 0.05)))))
    (draw-sprite logo (vec2 left_border (- height-px 50)))
    (draw-text (string-append "Lines: " (number->string completed-lines)) (vec2 left_border (inexact->exact (floor (* height-px 0.75)))) #:font font-small #:color color-red)
    (draw-text (string-append "Level: " (number->string (truncate (/ completed-lines 3)))) (vec2 left_border (inexact->exact (floor (* height-px 0.65)))) #:font font-small #:color color-red)
    ; Draw the next piece on deck to be played as part of the status area.
    (let ((top_border (inexact->exact (floor (* height-px 0.45))))
          (left_border (+ (* (+ board.block.width 2) square-size) 50 (inexact->exact (floor (* 6 square-size 0.05)))))
          (center (floor (/ board.block.width 2)))
          (block (list-ref block-colors next-piece-type))
          (coords (copy-tree (list-ref starting-positions next-piece-type))))
      (for-each (lambda (coord)
                  (let ((x (+ left_border (* (- (car  coord) center) square-size)))
                        (y (+ top_border  (* (cadr coord) square-size))))
                    (draw-sprite block (vec2 x y))))
                coords)))
  (if (eq? game-state 'gameover)
    (let ((x (inexact->exact (floor (* width-px 0.05))))
          (y (inexact->exact (floor (* height-px 0.4375))))
          (line-y (inexact->exact (floor (* height-px 0.46)))))
      (draw-9-patch block-black (make-rect x y width-px (inexact->exact (floor (* height-px 0.125)))))
      ; Font placement is not positioned or scaled properly based on squale-size.
      (draw-text "The only winning move is not to play" (vec2 x line-y) #:font font-small #:color color-red #:scale (vec2 1.0 2.0)))))

; Move a piece from (x,y) -> (x+dx, y+dy). A move is placing black blocks over the current piece and adding a new piece
; in the updated coordinates.
(define (move-tetromino board dx dy)
  (let ((color (list-ref block-colors current-piece-type)))
    (add-board-piece board current-piece-coords block-black)
    (set! current-piece-coords (update-coords current-piece-coords dx dy))
    (add-board-piece board current-piece-coords color)))

; Remove all board rows that have no black blocks. Add new board rows at the top of the board by making a partial board.
(define (clear-lines tboard)
  (define (partial-row row)
    (if (> (length (filter (lambda (x) (eq? x block-black)) row)) 0)
      #t
      (begin (audio-play sound-lineclear) #f)))
  (let ((filtered-board (filter partial-row tboard)))
    (set! board (make-board-rows filtered-board board.block.width board.block.height))
    (- board.block.height (length filtered-board))))

(define tick.game 0)
(define tick.block 0)
(define completed-lines 0)
(define (update dt)
  (cond ((not (eq? game-state 'pause))
         (set! tick.game (+ tick.game 1))
         (if (> (- tick.game tick.block reduce-speed) (max 1 (- 15 (/ completed-lines 3))))
           (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- board.block.height 1))) current-piece-coords)) 0)))
             (set! tick.block tick.game)
             (if (not (or bottomed_out
                          (collision-detected-moving board current-piece-coords 0 1)))
               (move-tetromino board 0 1)
               (begin
                 (set! completed-lines (+ completed-lines (clear-lines board)))
                 (set! current-piece-type next-piece-type)
                 (set! next-piece-type (random 7))
                 (set! current-piece-rotation 0)
                 (add-new-piece board current-piece-type))))))))

(set-window-title! (current-window) "TETЯIS")
(set-window-size! (current-window) width-px height-px)
(display "
TETЯIS:

  usage: chickadee play tetris.scm [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.
")

; Command-line argument can set the level from 1-15.
(let ((arg (string->number (list-ref (program-arguments) (- (length (program-arguments)) 1)))))
  (if (and (not (eq? arg #f)) (number? arg))
    (set! completed-lines (* 3 (max 0 (min 15 arg))))))
