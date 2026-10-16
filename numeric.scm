(import (scheme base)
        (scheme write))

(define (exact-integer-sqrt/list n)
  (call-with-values
    (lambda () (exact-integer-sqrt n))
    list))

(write (+ (exact-integer-sqrt 782763574) (/ 1 4)))
(display " ")
(write (exact-integer-sqrt/list 782763574))
(newline)
