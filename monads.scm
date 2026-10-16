;; Monoids in the category of Endofunctors!
(import (scheme base)
        (scheme write)
        (gauche base))

(define (just x)
  (list 'just x))

(define nothing
  '(nothing))

(define (just? x)
  (and (pair? x)
       (eq? (car x) 'just)))

(define (maybe-value x)
  (cadr x))

(define (maybe-return x)
  (just x))

(define (maybe-bind m f)
  (if (just? m)
      (f (maybe-value m))
      nothing))

(write (maybe-bind
         (just 3)
         (lambda (x)
           (just (* x 2)))))
(newline)

(write (maybe-bind
         nothing
         (lambda (x)
           (just (* x 2)))))
(newline)

(define (safe-div a b)
  (if (= b 0)
    nothing
    (just (/ a b))))

(write (maybe-bind
         (safe-div 10 2)
         (lambda (x)
           (safe-div x 5))))
(newline)

(write (maybe-bind
         (safe-div 10 0)
         (lambda (x)
           (safe-div x 5))))
(newline)
