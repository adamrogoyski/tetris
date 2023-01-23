#lang racket/gui
(require racket/gui/base)
(require racket/format)

(define width 10)
(define height 20)
(define block-size 32)
(define width-px (+ (* width block-size) 60 (* 6 block-size)))
(define height-px (* height block-size))
(define status-left (+ (* width block-size) 60))
(define black (make-color 0 0 0))

(define block-black (make-object bitmap% 32 32))
(define block-blue (make-object bitmap% 32 32))
(define block-cyan (make-object bitmap% 32 32))
(define block-green (make-object bitmap% 32 32))
(define block-orange (make-object bitmap% 32 32))
(define block-purple (make-object bitmap% 32 32))
(define block-red (make-object bitmap% 32 32))
(define block-yellow (make-object bitmap% 32 32))
(define logo (make-object bitmap% 99 44))
(define wall (make-object bitmap% 50 640))
(define block-colors (list block-blue block-cyan block-green block-orange block-purple block-red block-yellow))
(send block-black load-file "graphics/block_black.png")
(send block-blue load-file "graphics/block_blue.png")
(send block-cyan load-file "graphics/block_cyan.png")
(send block-green load-file "graphics/block_green.png")
(send block-orange load-file "graphics/block_orange.png")
(send block-purple load-file "graphics/block_purple.png")
(send block-red load-file "graphics/block_red.png")
(send block-yellow load-file "graphics/block_yellow.png")
(send logo load-file "graphics/logo.png")
(send wall load-file "graphics/wall.png")

; Racket's gui library can only play sounds. It cannot stop them.
; A music thread randomly selects music until the game has ended.
(define music (list "sound/bwv814menuet.wav" "sound/korobeiniki.wav" "sound/russiansong.wav"))
(define music-thread (thread (lambda ()
                               (let loop ()
                                 (play-sound (list-ref music (random 3)) #f)
                                 (loop)))))

; One of ('play 'pause 'gameover).
(define game-state 'play)

; Create a vector (rows) of vectors (columns) representing the play board.
; The height parameter is used to creat partial boards for appending to do line clearing.
(define (make-board width height)
  (let ((board (make-vector height)))
    (for ([i height])
      (vector-set! board i (make-vector width))
      (vector-fill! (vector-ref board i) block-black))
    board))

(define board (make-board width height))
(define completed-lines 0)
(define reduce-speed 0)  ; Increment to lower the block drop speed.
(define next-piece-type (random 7))
(define current-piece-type (random 7))
(define current-piece-coords #f)
(define current-piece-rotation 0)
(define starting-positions
  (let ((center (floor (/ width 2))))
    (list
     (list (list (- center 1) 0) (list (- center 1) 1) (list center 1) (list (+ center 1) 1) ) ; Leftward L piece.
     (list (list (- center 1) 1) (list center 1) (list center 0) (list (+ center 1) 0) )       ; Rightward Z piece.
     (list (list (- center 2) 0) (list (- center 1) 0) (list center 0) (list (+ center 1) 0) ) ; Long straight piece.
     (list (list (- center 1) 1) (list center 1) (list center 0) (list (+ center 1) 1) )       ; Bump in middle piece.
     (list (list (- center 1) 1) (list center 1) (list (+ center 1) 1) (list (+ center 1) 0) ) ; L piece.
     (list (list (- center 1) 0) (list center 0) (list center 1) (list (+ center 1) 1) )       ; Z piece.
     (list (list (- center 1) 0) (list (- center 1) 1) (list center 0) (list center 1) )       ; Square piece.
     )))

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
             (< x width)
             (< y height)
             (within-bounds (cdr coords))))))

; End the game by changing game state, restricting input, stopping updates, and announcing game over.
(define (game-over)
  (set! game-state 'gameover)
  (display "Game Over\n")
  (kill-thread music-thread))

; Make a deep copy of a list.
(define (copy-tree lis)
  (define (atom? x)
    (and (not (null? x))
         (not (pair? x))))
  (cond ([atom? lis]
         lis)
        ([eq? lis '()]
         '())
        (else
         (cons (copy-tree (car lis))
               (copy-tree (cdr lis))))))

; Make a deep copy of a vector.
(define (vector-deep-copy v)
  (let ([nv (make-vector height)])
    (for ([i height])
      (vector-set! nv i (make-vector width))
      (vector-copy! (vector-ref nv i) 0 (vector-ref v i)))
    nv))

; Determine if the coordinates collide with any non-black blocks on the board.
(define (collision-detected board coords)
  (define (collision coord)
    (let* ((row (cadr coord))
           (column (car coord))
           (board-value (vector-ref (vector-ref board row) column)))
      (if (eq? board-value block-black)
          #f
          #t)))
  (not (eq? '() (filter collision coords))))

; Detect if move the specified coords by dx,dy would lead to a collision on the board with non-black pieces.
; Since the piece is moving, clear it from a copy of the board so it won't collide with itself.
(define (collision-detected-moving board_ coords dx dy)
  (define tboard (vector-deep-copy board_))
  (add-board-piece tboard coords block-black)
  (collision-detected tboard (update-coords coords dx dy)))

; Place all 4 pieces of a block on the board by setting the piece's color at its coordinates.
(define (add-board-piece board coords color)
  (for-each (lambda (coord)
              (let ([column (car coord)]
                    [row (cadr coord)])
                (vector-set! (vector-ref board row) column color)))
            coords))

; Add a new piece to the board. If the new piece collides, the game is over.
(define (add-new-piece board current-piece-type)
  (let ([coords (list-ref starting-positions current-piece-type)]
        [color (list-ref block-colors current-piece-type)])
    (set! current-piece-coords (copy-tree coords))
    (let ((game-over-condition (collision-detected board coords)))
      (if game-over-condition
          (game-over)
          (add-board-piece board coords color)))))
 

; Add the initial tetromino to the board.
(add-new-piece board current-piece-type)

; Draw the board, with each element of the board being the block bitmap to display.
(define (draw-board board dc)
  (for ([rownum height])
    (for ([colnum width])
      (let* ([y (* rownum block-size)]
             [x (* colnum block-size)]
             [row (vector-ref board rownum)]
             [elem (vector-ref row colnum)])
        (send dc draw-bitmap elem x y)))))

; Return new coordinates (x,y) -> (x+dx, y+dy).
(define (update-coords coords dx dy)
  (map (lambda (coord)
         (let ((x (car coord))
               (y (cadr coord)))
           (list (+ x dx) (+ y dy))))
       coords))

; Move a piece from (x,y) -> (x+dx, y+dy). A move is placing black blocks over the current piece and adding a new piece
; in the updated coordinates.
(define (move-tetromino board dx dy)
  (let ((color (list-ref block-colors current-piece-type)))
    (add-board-piece board current-piece-coords block-black)
    (set! current-piece-coords (update-coords current-piece-coords dx dy))
    (add-board-piece board current-piece-coords color)))

; Rotate the current piece if possible. Remove it from a temporary board, rotate its coordinates, and if it is within
; the board bounds and not colliding with another piece, commit the rotation to the board.
(define (try-rotation board current-piece-type)
  (let ((tboard (vector-deep-copy board))
        (tcoords (copy-tree current-piece-coords))
        (rotation (list-ref (list-ref rotations current-piece-type) current-piece-rotation))
        (color (list-ref block-colors current-piece-type)))
    (add-board-piece tboard current-piece-coords block-black)
    (set! tcoords (for/list ([coord tcoords]
                             [crot rotation])
                    (list (+ (car coord) (car crot))
                          (+ (cadr coord) (cadr crot)))))
    (cond ((within-bounds tcoords)
           (cond ((not (collision-detected tboard tcoords))
                  (add-board-piece board current-piece-coords block-black)
                  (add-board-piece board tcoords color)
                  (set! current-piece-rotation (modulo (+ current-piece-rotation 1) 4))
                  (set! current-piece-coords tcoords)))))))

; Remove all board rows that have no black blocks. Add new board rows at the top of the board by making a partial board.
(define (clear-lines tboard)
  (define (partial-row row)
    (if (> (vector-length (vector-filter (lambda (x) (eq? x block-black)) row)) 0)
        #t
        (begin #f)))
  (let* ([filtered-board (vector-filter partial-row tboard)]
         [cleared-lines (- height (vector-length filtered-board))])
    (set! board (vector-append (make-board width cleared-lines) filtered-board))
    (- height (vector-length filtered-board))))

(define frame (new frame%
                   [label "Tetris"]
                   [width width-px]
                   [height height-px]))
(define cv%
  (class canvas% 
    (define/override (on-char key-event)
      (let ([key (send key-event get-key-code)]
            [updated #f])
        (cond
          [(or (equal? key 'escape) (equal? key #\q))
           (exit)]
          [(and (not (eq? game-state 'gameover)) (equal? key #\p))
           (if (eq? game-state 'play)
               (set! game-state 'pause)
               (set! game-state 'play))])
        (if (eq? game-state 'play)
            (cond
              [(equal? key 'up)
               (try-rotation board current-piece-type)
               (set! updated #t)]
              [(equal? key 'left)
               (let ((collided-left-wall (> (length (filter-map (lambda (x) (= (car x) 0)) current-piece-coords)) 0)))
                 (cond ((not (or collided-left-wall
                                 (collision-detected-moving board current-piece-coords -1 0)))
                        (move-tetromino board -1 0)
                        (set! updated #t))))]
              [(equal? key 'right)
               (let ((collided-right-wall (> (length (filter-map (lambda (x) (= (car x) (- width 1))) current-piece-coords)) 0)))
                 (cond ((not (or collided-right-wall
                                 (collision-detected-moving board current-piece-coords 1 0)))
                        (move-tetromino board 1 0)
                        (set! updated #t))))]
              [(equal? key 'down)
               (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- height 1))) current-piece-coords)) 0)))
                 (cond ((not (or bottomed_out
                                 (collision-detected-moving board current-piece-coords 0 1)))
                        (move-tetromino board 0 1)
                        (set! updated #t))))]
              [(equal? key #\space)
               (letrec ((down-iter (lambda ()
                                     (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- height 1))) current-piece-coords)) 0)))
                                       (cond ((not (or bottomed_out
                                                       (collision-detected-moving board current-piece-coords 0 1)))
                                              (move-tetromino board 0 1)
                                              (set! updated #t)
                                              (down-iter)))))))
                 (down-iter))])
            #f)
        (if updated (send game-canvas refresh-now) #f)))
    (super-new)))

(define game-canvas (new cv% [parent frame]
                         [paint-callback
                          (lambda (canvas dc)
                            (send dc set-text-foreground "red")
                            (send dc set-background black)
                            (send dc clear)
                            (draw-board board dc)
                            (send dc draw-bitmap wall (* width block-size) 0)
                            (send dc draw-bitmap logo status-left 0)
                            (let* ([text-lines (make-bitmap (inexact->exact (floor (* 6 block-size 0.90))) (inexact->exact (floor (* height-px 0.10))))]
                                   [tdc (new bitmap-dc% [bitmap text-lines])])
                              (send tdc set-text-foreground "red")
                              (send tdc set-brush "red" 'opaque)
                              (send tdc draw-text (string-append "Lines: " (~v completed-lines)) 0 0)
                              (send dc draw-bitmap text-lines status-left (* height-px 0.25) ))
                            (let* ([text-lines (make-bitmap (inexact->exact (floor (* 6 block-size 0.90))) (inexact->exact (floor (* height-px 0.10))))]
                                   [tdc (new bitmap-dc% [bitmap text-lines])])
                              (send tdc set-text-foreground "red")
                              (send tdc set-brush "red" 'opaque)
                              (send tdc draw-text (string-append "Level: " (~v (inexact->exact (floor (/ completed-lines 3))))) 0 0)
                              (send dc draw-bitmap text-lines status-left (* height-px 0.35)))
                            ; Draw the next piece on deck to be played as part of the status area.
                            (let ((top_border (inexact->exact (floor (* height-px 0.45))))
                                  (left_border (+ (* (+ width 2) block-size) 50 (inexact->exact (floor (* 6 block-size 0.05)))))
                                  (center (floor (/ width 2)))
                                  (block (list-ref block-colors next-piece-type))
                                  (coords (copy-tree (list-ref starting-positions next-piece-type))))
                              (for ([coord coords])
        
                                (let ((x (+ left_border (* (- (car  coord) center) block-size)))
                                      (y (+ top_border  (* (cadr coord) block-size))))
                                  (send dc draw-bitmap block x y)))
                              )
                            (if (eq? game-state 'gameover)
                                (let* ([text-lines (make-bitmap width-px (inexact->exact (floor (* height-px 0.125))))]
                                       [tdc (new bitmap-dc% [bitmap text-lines])])
                                  (send dc set-brush black 'solid)
                                  (send dc draw-rectangle
                                        0 (inexact->exact (floor (* height-px 0.4375)))
                                        (- width-px 1) (inexact->exact (floor (* height-px 0.125)))) 
                                  (send tdc set-text-foreground "red")
                                  (send tdc set-brush "red" 'opaque)
                                  (send tdc draw-text "The only winning move is not to play" 0 0)
                                  (send dc draw-bitmap text-lines 100 (* height-px 0.49) ))
                                #f))]))
(send frame show #t)
(send game-canvas refresh-now)

(define tick.game 0)
(define tick.block 0)
; Every frame (60 frames per second is 16ms per from), check if the piece should be dropped.
(define drop-timer
  (new timer%
       (interval 16)
       (notify-callback
        (lambda ()
          (let ([changed #f])
            (cond ([eq? game-state 'gameover]
                   (send drop-timer stop))
                  ([eq? game-state 'pause]
                   #f)
                  (else
                   (set! tick.game (+ 1 tick.game))
                   (if (> (- tick.game tick.block reduce-speed) (max 1 (- 15 (/ completed-lines 3))))
                       (let ((bottomed_out (> (length (filter-map (lambda (x) (= (cadr x) (- height 1))) current-piece-coords)) 0)))
                         (set! tick.block tick.game)
                         (set! changed #t)
                         (if (not (or bottomed_out
                                      (collision-detected-moving board current-piece-coords 0 1)))
                             (move-tetromino board 0 1)
                             (begin
                               (set! completed-lines (+ completed-lines (clear-lines board)))
                               (set! current-piece-type next-piece-type)
                               (set! next-piece-type (random 7))
                               (set! current-piece-rotation 0)
                               (add-new-piece board current-piece-type))))
                       #f)))
            (if changed (send game-canvas refresh-now) #f))))))