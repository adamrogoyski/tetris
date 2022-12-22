(use-modules (srfi srfi-64))
(load "tetris.scm")

(test-begin "t1")
(test-assert (= 6 (foo 3)))
(test-end "t1")
