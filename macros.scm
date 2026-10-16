(import (scheme base)
        (scheme write)
        (gauche base))

(define-macro (with-it expr . body)
              `(let ((it ,expr))
                 ,@body))

(with-it (+ 2 3)
         (write it)
         (newline))

; unhygenic macros!!!
(let
  ((it 2))
  (with-it 3 (write it) (newline)))

; cleaner hygienic macro to simplify (let ((name value)) expression)
(define-syntax with
  (syntax-rules ()
    ((_ name value body ...)
     (let ((name value))
       body ...))))

(with it 3 (write it) (newline))

; still has the explicit name...
(let
  ((it 2))
  (with it 3 (write it) (newline)))

; but we can change it!
(let
  ((it 2))
  (with it/2 3 (write it) (newline)))
