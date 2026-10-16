(import (scheme base)
        (scheme write)
        (srfi 18)
        (data queue))

(define q (make-mtqueue))

(define worker
  (make-thread
   (lambda ()
     (enqueue/wait! q '(hello from worker))
     123)))

(thread-start! worker)

(write (dequeue/wait! q))
(newline)

(write (thread-join! worker))
(newline)
