#!/usr/bin/env -S sbcl --load ${HOME}/quicklisp/setup.lisp --script
; Author: Adam Rogoyski (adam@rogoyski.com).
; Public domain software.
;
; A tetris game.

(ql:quickload "sdl2")
(ql:quickload "sdl2-image")
(ql:quickload "sdl2-mixer")
(ql:quickload "sdl2-ttf")
(ql:quickload "iterate")
(use-package :iterate)
(setf *random-state* (make-random-state t))

(defun floorv (v)
  (values (floor v)))

(defconstant *num-tetrominos* 7)
(defconstant *block-size* 64)
(defconstant *width* 10)
(defconstant *height* 20)
(defconstant *width-px* (+ (* *width* *block-size*) 50 (* 6 *block-size*)))
(defconstant *height-px* (* *height* *block-size*))
(defconstant *framerate* 60)
(defconstant *ms-per-frame* (floorv (/ 1000 *framerate*)))

; Starting position of each type of tetromino. Each tetromino is 4 (x,y) coordinates.
(defconstant *starting-positions*
  (make-array (list *num-tetrominos* 4 2) :element-type 'integer :initial-contents
    '(((-1 0) (-1 1) (0 1) (1 1))    ; Leftward L piece.
      ((-1 1) ( 0 1) (0 0) (1 0))    ; Rightward Z piece.
      ((-2 0) (-1 0) (0 0) (1 0))    ; Long straight piece.
      ((-1 1) ( 0 1) (0 0) (1 1))    ; Bump in middle piece.
      ((-1 1) ( 0 1) (1 1) (1 0))    ; L piece.
      ((-1 0) ( 0 0) (0 1) (1 1))    ; Z piece.
      ((-1 0) (-1 1) (0 0) (0 1))))) ; Square piece.

; Array of rotations for each tetromino to move from orientation x -> (x + 1) % 4.
; Each rotation is an array of 4 rotations -- one for each orientation of a tetromino.
; For each rotation, there is an array of 4 (int x, int y) coordinate diffs for each block of the tetromino.
; The coordinate diffs map each block to its new location.
; Thus: [block][orientation][component][x|y] to map the 4 components of each block in each orientation.
(defconstant *rotations*
  (make-array (list *num-tetrominos* 4 4 2) :element-type 'integer :initial-contents
      ; Leftward L piece.
    '((((0 2)   (1 1)    (0 0)  (-1 -1))
       ((2 0)   (1 -1)   (0 0)  (-1 1))
       ((0 -2)  (-1 -1)  (0 0)  (1 1))
       ((-2 0)  (-1 1)   (0 0)  (1 -1)))
      ; Rightward Z piece. Orientation symmetry: 0==2 and 1==3.
      (((1 0)   (0 1)   (-1 0)  (-2 1))
       ((-1 0)  (0 -1)  (1 0)   (2 -1))
       ((1 0)   (0 1)   (-1 0)  (-2 1))
       ((-1 0)  (0 -1)  (1 0)   (2 -1)))
      ; Long straight piece. Orientation symmetry: 0==2 and 1==3.
      (((2 -2)  (1 -1)  (0 0)  (-1 1))
       ((-2 2)  (-1 1)  (0 0)  (1 -1))
       ((2 -2)  (1 -1)  (0 0)  (-1 1))
       ((-2 2)  (-1 1)  (0 0)  (1 -1)))
      ; Bump in middle piece.
      (((1 1)    (0 0)  (-1 1)   (-1 -1))
       ((1 -1)   (0 0)  (1 1)    (-1 1))
       ((-1 -1)  (0 0)  (1 -1)   (1 1))
       ((-1 1)   (0 0)  (-1 -1)  (1 -1)))
      ; L Piece.
      (((1 1)    (0 0)  (-1 -1)  (-2 0))
       ((1 -1)   (0 0)  (-1 1)   (0 2))
       ((-1 -1)  (0 0)  (1 1)    (2 0))
       ((-1 1)   (0 0)  (1 -1)   (0 -2)))
      ; Z piece. Orientation symmetry: 0==2 and 1==3.
      (((1 0)   (0 1)   (-1 0)  (-2 1))
       ((-1 0)  (0 -1)  (1 0)   (2 -1))
       ((1 0)   (0 1)   (-1 0)  (-2 1))
       ((-1 0)  (0 -1)  (1 0)   (2 -1)))
      ; Square piece. Orientation symmetry: 0==1==2==3.
      (((0 0)  (0 0)  (0 0)  (0 0))
       ((0 0)  (0 0)  (0 0)  (0 0))
       ((0 0)  (0 0)  (0 0)  (0 0))
       ((0 0)  (0 0)  (0 0)  (0 0))))))

(write-string "
TETЯIS: 

  usage: tetris.lisp [level 1-15]

  F1  - Korobeiniki (gameboy song A).
  F2  - Bach french suite No 3 in b minor BWV 814 Menuet (gameboy song B).
  F3  - Russion song (gameboy song C).
  ESC - Quit.
  p   - Pause.

  Up - Rotate.
  Down - Lower.
  Space - Drop completely.

")

(defparameter *completed-lines* 0)
(if (>= (list-length *posix-argv*) 2)
  (setf *completed-lines* (* (min 15 (max 0 (parse-integer (cadr *posix-argv*)))) 3)))

(sdl2-ttf:init)
(defconstant *font* (sdl2-ttf:open-font "fonts/Montserrat-Regular.ttf" (* 24 (floorv (/ *block-size* 32)))))

(sdl2-image:init '(:png))
(sdl2-mixer:init)
(sdl2-mixer:open-audio 22050 :s16sys 1 1024)
(sdl2-mixer:allocate-channels 1)
(defconstant *music-bwv814menuet* (sdl2-mixer:load-wav "sound/bwv814menuet.wav"))
(defconstant *music-korobeiniki* (sdl2-mixer:load-wav "sound/korobeiniki.wav"))
(defconstant *music-russiansong* (sdl2-mixer:load-wav "sound/russiansong.wav"))
(defconstant *music-gameover* (sdl2-mixer:load-wav "sound/gameover.wav"))
(defconstant loop-music-forever -1)

(defun play-music (song loops &key (channel 0))
  (sdl2-mixer:halt-channel -1)
  (sdl2-mixer:play-channel channel song loops))

(defun draw-board (renderer board blocks)
  (iter (for x from 0 to (1- *width*))
    (iter (for y from 0 to (1- *height*))
      (sdl2:render-copy renderer (elt blocks (aref board y x)) :dest-rect (sdl2:make-rect (* x *block-size*) (* y *block-size*) *block-size* *block-size*)))))

(defun draw-text (renderer text x y w h)
  (let* ((lines-texture (let* ((surface (sdl2-ttf:render-text-solid *font* text 255 0 0 255))
                               (texture (sdl2:create-texture-from-surface renderer surface)))
                              (sdl2:free-surface surface)
                              texture)))
        (sdl2:render-copy renderer lines-texture :dest-rect (sdl2:make-rect x y w h))
        (sdl2:destroy-texture lines-texture)))

(defun draw-status (renderer wall logo next-piece blocks)
  ; Wall extends from top to bottom, separating the board from the status area.
  (sdl2:render-copy renderer wall :dest-rect (sdl2:make-rect (* *width* *block-size*) 0 50 (* *height* *block-size*)))

  (let ((left-border (+ (* *width* *block-size*) 50 (floorv (* 6 *block-size* 0.05))))
        (width (floorv (* 6 *block-size* 0.90))))
    ; The logo sits at the top right of the screen right of the wall.
    (sdl2:render-copy renderer logo :dest-rect (sdl2:make-rect left-border 0 width (floorv (* *height-px* 0.20))))
    ; Write the number of completed lines and current game level.
    (draw-text renderer (format NIL "Lines: ~D" *completed-lines*) left-border (floorv (* *height-px* 0.25)) width (floorv (* *height-px* 0.05)))
    (draw-text renderer (format NIL "Level: ~D" (floorv (/ *completed-lines* 3))) left-border (floorv (* *height-px* 0.35)) width (floorv (* *height-px* 0.05))))
    ; Draw the next tetromino piece.
    (iter (for i from 0 to 3)
      (let* ((top-border (floorv (* *height-px* 0.45)))
             (left-border (+ (* (+ *width* 2) *block-size*) 50 (floorv (* 6 *block-size* 0.05))))
             (x (+ left-border (* (aref *starting-positions* next-piece i 0) *block-size*)))
             (y (+ top-border (* (aref *starting-positions* next-piece i 1) *block-size*))))
        (sdl2:render-copy renderer (aref blocks (1+ next-piece)) :dest-rect (sdl2:make-rect x y *block-size* *block-size*)))))

(defun draw-gameover (renderer blocks)
  (sdl2:render-copy renderer (aref blocks 0) :dest-rect (sdl2:make-rect 0 (floorv (* *height-px* 0.4375)) *width-px* (floorv (* *height-px* 0.125))))
  (draw-text renderer "The only winning move is not to play" (floorv (* *width-px* 0.05)) (floorv (* *height-px* 0.4375)) (floorv (* *width-px* 0.90)) (floorv (* *height-px* 0.125))))

(defun draw (renderer board blocks wall logo next-piece status)
  (draw-board renderer board blocks)
  (draw-status renderer wall logo next-piece blocks)
  (if (eq status 'GAMEOVER)
    (draw-gameover renderer blocks)))

(defun add-board-piece (board piece coords)
  (let ((center (floorv (/ *width* 2)))
        (collision NIL))
    (iter (for i from 0 to 3)
      (let ((x (+ center (aref *starting-positions* piece i 0)))
            (y (aref *starting-positions* piece i 1)))
        (if (/= 0 (aref board y x))
          (progn
            (setf collision T)
            (terminate))
          (progn
            (setf (aref board y x) (1+ piece))
            (setf (aref coords i 0) x)
            (setf (aref coords i 1) y)))))
    collision))

(defun move-tetromino (dx dy board coords piece)
  ; Clear the board where the piece currently is.
  (iter (for i from 0 to 3)
    (let ((x (aref coords i 0))
          (y (aref coords i 1)))
      (setf (aref board y x) 0)))
  ; Update the current piece's coordinates and fill the board in the new coordinates.
  (iter (for i from 0 to 3)
    (setf (aref coords i 0) (+ (aref coords i 0) dx))
    (setf (aref coords i 1) (+ (aref coords i 1) dy))
    (setf (aref board (aref coords i 1) (aref coords i 0)) (1+ piece))))

(defun set-coords (board coords piece)
  (iter (for i from 0 to 3)
    (setf (aref board (aref coords i 1) (aref coords i 0)) piece)))

(defun collision-detected (dx dy board coords piece)
  (let ((collision NIL))
    (set-coords board coords 0)
    (iter (for i from 0 to 3)
      (let ((x (aref coords i 0))
            (y (aref coords i 1)))
        (when (or (< (+ x dx) 0)
                  (>= (+ x dx) *width*)
                  (>= (+ y dy) *height*)
                  (/= (aref board (+ y dy) (+ x dx)) 0))
          (setf collision T)
          (terminate))))
    (set-coords board coords (1+ piece))
    collision))

(defun rotate (board coords piece orientation)
  (let ((new-coords (make-array '(4 2) :element-type 'integer))
        (collision NIL))
    (iter (for i from 0 to 3)
      (setf (aref new-coords i 0) (+ (aref coords i 0) (aref *rotations* piece orientation i 0)))
      (setf (aref new-coords i 1) (+ (aref coords i 1) (aref *rotations* piece orientation i 1))))
    ; Clear the board where the piece currently is to not detect self collision.
    (set-coords board coords 0)
    (iter (for i from 0 to 3)
      (let ((x (aref new-coords i 0))
            (y (aref new-coords i 1)))
        ; Collision is hitting the left wall, right wall, top, bottom, or a non-black block.
        (when (or (< x 0) (>= x *width*) (< y 0) (>= y *height*) (/= (aref board y x) 0))
          (setf collision T) (terminate))))
    (cond
      (collision (progn
                   (set-coords board coords (1+ piece))
                   (values NIL orientation)))
      (T (progn
           (iter (for i from 0 to 3)
             (setf (aref coords i 0) (aref new-coords i 0))
             (setf (aref coords i 1) (aref new-coords i 1))
             (setf (aref board (aref new-coords i 1) (aref new-coords i 0)) (1+ piece)))
           (values T (mod (1+ orientation) 4)))))))

; Clear completed (filled) rows.
; Start from the bottom of the board, copying each row with holes to a new board.
(defun clear-board (board)
  (let ((rows-deleted 0)
        (new-board (make-array (list *height* *width*) :element-type 'integer :initial-element 0)))
    (iter (for row from (1- *height*) downto 0)
      (let ((has-hole NIL))
        (iter (for x from 0 to (1- *width*))
          (if has-hole (terminate))
          (if (= 0 (aref board row x))
            (setf has-hole T)))
        (if has-hole
          (iter (for x from 0 to (1- *width*))
            (setf (aref new-board (+ row rows-deleted) x) (aref board row x)))
          (setf rows-deleted (1+ rows-deleted)))))
    (setf *completed-lines* (+ rows-deleted *completed-lines*))
    new-board))

(sdl2:with-init (:everything)
  (sdl2:with-window (win :title "TETЯIS" :h *height-px* :w *width-px* :flags '(:shown))
    (sdl2:with-renderer (renderer win :flags '(:accelerated))
      (let* ((logo         (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/logo.png")))
             (wall         (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/wall.png")))
             (block-black  (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_black.png")))
             (block-blue   (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_blue.png")))
             (block-cyan   (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_cyan.png")))
             (block-green  (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_green.png")))
             (block-orange (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_orange.png")))
             (block-purple (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_purple.png")))
             (block-red    (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_red.png")))
             (block-yellow (sdl2:create-texture-from-surface renderer (sdl2-image:load-image "graphics/block_yellow.png")))
             (blocks (vector block-black block-blue block-cyan block-green block-orange block-purple block-red block-yellow))
             (board (make-array (list *height* *width*) :element-type 'integer :initial-element 0))
             (current-coords (make-array '(4 2) :element-type 'integer :initial-element 0))
             (current-piece (random *num-tetrominos*))
             (next-piece (random *num-tetrominos*))
             (current-orientation 0)
             (changed NIL)
             (last-frame-ms (sdl2:get-ticks))
             (game-ticks 0)
             (drop-ticks 0)
             (status 'PLAY))
        (add-board-piece board current-piece current-coords)
        (draw renderer board blocks wall logo next-piece status)
        (play-music *music-korobeiniki* loop-music-forever)
        (sdl2:with-event-loop (:method :poll)
          (:quit () t)
          (:keydown (:keysym keysym)
            (case (sdl2:scancode keysym)
              ((:SCANCODE-Q) (sdl2:push-event :quit))
              ((:SCANCODE-X) (sdl2:push-event :quit))
              ((:SCANCODE-P) (if (eq status 'PAUSE) (setf status 'PLAY) (setf status 'PAUSE)))
              ((:SCANCODE-R) (if (eq status 'PAUSE) (setf status 'PLAY) (setf status 'PAUSE)))
              ((:SCANCODE-F1) (if (not (eq status 'GAMEOVER)) (play-music *music-korobeiniki* loop-music-forever)))
              ((:SCANCODE-F2) (if (not (eq status 'GAMEOVER)) (play-music *music-bwv814menuet* loop-music-forever)))
              ((:SCANCODE-F3) (if (not (eq status 'GAMEOVER)) (play-music *music-russiansong* loop-music-forever)))
              ((:SCANCODE-RIGHT)
                (when (and (eq status 'PLAY) (not (collision-detected 1 0 board current-coords current-piece)))
                  (move-tetromino 1 0 board current-coords current-piece)
                  (setf changed T)))
              ((:SCANCODE-LEFT)
                (when (and (eq status 'PLAY) (not (collision-detected -1 0 board current-coords current-piece)))
                  (move-tetromino -1 0 board current-coords current-piece)
                  (setf changed T)))
              ((:SCANCODE-DOWN)
                (when (and (eq status 'PLAY) (not (collision-detected 0 1 board current-coords current-piece)))
                  (move-tetromino 0 1 board current-coords current-piece)
                  (setf changed T)))
              ((:SCANCODE-SPACE)
                (loop while (and (eq status 'PLAY) (not (collision-detected 0 1 board current-coords current-piece)))
                   do (move-tetromino 0 1 board current-coords current-piece)
                      (setf changed T)))
              ((:SCANCODE-UP) 
                (if (eq status 'PLAY)
                  (multiple-value-setq (changed current-orientation) (rotate board current-coords current-piece current-orientation))))))
          (:keyup (:keysym keysym)
           (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-escape)
             (sdl2:push-event :quit)))
          (:idle ()
            (when (and (eq status 'PLAY)
                       (>= game-ticks (+ drop-ticks (max (- 15 (floorv (/ *completed-lines* 3))) 1))))
              (setf changed T)
              (setf drop-ticks game-ticks)              
              (if (not (collision-detected 0 1 board current-coords current-piece))
                (move-tetromino 0 1 board current-coords current-piece)
                (progn
                  (setf board (clear-board board))
                  (setf current-orientation 0)
                  (setf current-piece next-piece)
                  (setf next-piece (random *num-tetrominos*))
                  (when (add-board-piece board current-piece current-coords)
                    (setf status 'GAMEOVER)
                    (play-music *music-gameover* 0)))))
            (when changed
              (sdl2:render-clear renderer)
              (draw renderer board blocks wall logo next-piece status)
              (sdl2:render-present renderer)
              (setf changed NIL))
            (let ((now-ms (sdl2:get-ticks)))
              (when (>= (- now-ms last-frame-ms) *ms-per-frame*)
                (setf game-ticks (1+ game-ticks))
                (setf last-frame-ms now-ms)))
            (sdl2:delay 1)))))))
