(import (scheme base)
        (scheme write)
        (gauche base)
        (gauche dictionary)
        (control future)
        (srfi 18)
        (scheme time))

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

(define-method bind ((c <pure>) f)
               (f (slot-ref c 'value)))

(define-method bind ((c <effectful>) f)
               (make <effectful>
                     :effect (slot-ref c 'effect)
                     :continuation
                     (lambda (value)
                       (bind ((slot-ref c 'continuation) value) f))))

(define-class <effect-handler> () ())

(define-class <runtime> ()
              ((handlers :init-form (make-hash-table 'eq?))))

(define-method register-handler!
               ((runtime <runtime>) effect-class (handler <effect-handler>))
               (dict-put! (slot-ref runtime 'handlers)
                          effect-class
                          handler))

(define-method find-handler
               ((runtime <runtime>) (effect <effect>))
               (or (dict-get (slot-ref runtime 'handlers)
                             (class-of effect)
                             #f)
                   (error "Unhandled effect:" effect)))

(define-method run ((c <pure>) (runtime <runtime>))
               (slot-ref c 'value))

(define-method run ((c <effectful>) (runtime <runtime>))
               (let ((effect (slot-ref c 'effect))
                     (k (slot-ref c 'continuation)))
                 (handle (find-handler runtime effect)
                         effect
                         (lambda (value)
                           (run (k value) runtime)))))

;; our first effects, write and newline
(define-class <write-effect> (<effect>)
              ((value :init-keyword :value)))

(define-class <newline-effect> (<effect>)
              ())

(define-class <io-handler> (<effect-handler>)
              ((port :init-keyword :port
                     :init-form (current-output-port))))

(define-method handle
               ((handler <io-handler>) (effect <write-effect>) resume)
               (display (slot-ref effect 'value)
                      (slot-ref handler 'port))
               (resume '()))

(define-method handle
               ((handler <io-handler>) (effect <newline-effect>) resume)
               (newline (slot-ref handler 'port))
               (resume '()))

;; Parallel effects!
(define-class <parallel-effect> (<effect>)
              ((computations :init-keyword :computations)))

(define-class <parallel-handler> (<effect-handler>)
              ((runtime :init-keyword :runtime)))

(define-method handle
               ((handler <parallel-handler>) (effect <parallel-effect>) resume)
               (let* ((runtime (slot-ref handler 'runtime))
                      (futures
                        (map (lambda (computation)
                               (make-future
                                 (lambda ()
                                   (run computation runtime))))
                             (slot-ref effect 'computations))))
                 (resume (map future-get futures))))


;; Let's test parallel execution out by sleeping
(define-class <sleep-effect> (<effect>)
              ((seconds :init-keyword :seconds)))

(define-class <sleep-handler> (<effect-handler>) ())

(define-method handle
               ((handler <sleep-handler>) (effect <sleep-effect>) resume)
               (thread-sleep! (slot-ref effect 'seconds))
               (resume (slot-ref effect 'seconds)))

;; A macro to make it nicer to use effects
(define-syntax effect-do
  (syntax-rules (<- parallel)
    ;; Parallel sugar
    ((_ (parallel (name <- expr) ...) rest ...)
     (bind
       (perform
         (make <parallel-effect>
               :computations
               (list expr ...)))
       (lambda (results)
         (apply
           (lambda (name ...)
             (effect-do rest ...))
           results))))
    ;; Sequential case
    ((_ (name <- expr) rest ...)
     (bind expr
           (lambda (name)
             (effect-do rest ...))))
    ;; Base case: return the final expression unchanged
    ((_ final)
     final)
    ;; Empty case: missing final computation
    ((_)
     (syntax-error "effect-do: Did you forget a final expression, such as (pure '())?"))
    ;; Catch-all error case
    ((_ . invalid)
     (syntax-error "Invalid effect-do syntax:" (effect-do . invalid)))))

(let ((runtime (make <runtime>))
      (io (make <io-handler>))
      (computation
        (effect-do
          (message <- (pure "Hello from effect-do!"))
          (_ <- (perform (make <write-effect> :value message)))
          (_ <- (perform (make <newline-effect>)))
          (pure '()))))
  (register-handler! runtime <write-effect> io)
  (register-handler! runtime <newline-effect> io)
  (run computation runtime))

(let ((runtime (make <runtime>))
      (io (make <io-handler>))
      (sleep (make <sleep-handler>))
      (computation
        (effect-do
          (parallel
            (a <- (perform (make <sleep-effect> :seconds 3)))
            (b <- (perform (make <sleep-effect> :seconds 1)))
            (c <- (perform (make <sleep-effect> :seconds 2))))
          (_ <- (perform (make <write-effect> :value (list a b c))))
          (_ <- (perform (make <newline-effect>)))
          (pure '()))))
  (register-handler! runtime <write-effect> io)
  (register-handler! runtime <newline-effect> io)
  (register-handler! runtime <sleep-effect> sleep)
  (register-handler!
    runtime
    <parallel-effect>
    (make <parallel-handler> :runtime runtime))
  (run computation runtime))
