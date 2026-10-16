(import (scheme base)
        (scheme write)
        (gauche base))

;; All effect operations derive from this.
(define-class <effect> ()
              ())

;; A computation is either:
;;   - a completed value
;;   - a suspended effect + continuation
(define-class <computation> ()
              ())

(define-class <pure> (<computation>)
              ((value :init-keyword :value)))

(define-class <effectful> (<computation>)
              ((effect :init-keyword :effect)
               (continuation :init-keyword :continuation)))

(define (pure x)
  (make <pure> :value x))

(define (perform effect)
  (make <effectful>
        :effect effect
        :continuation pure))

;; our first effects, write and newline
(define-class <write-effect> (<effect>)
              (value :init-keyword :value))

(define-class <newline-effect> (<effect>)
              ())

; TODO: implement
