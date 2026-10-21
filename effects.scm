(import (scheme base)
        (scheme write)
        (gauche base)
        (gauche dictionary)
        (control future)
        (srfi 18)
        (scheme time))

(define-class <effect> ()
              ())

;; Freer-monad-style representation: pure values or effect operations
;; paired with explicit result continuations. Continuations stay separate
;; from operations, so each effect needs no mapping operation.
(define-class <computation> ()
              ())

(define-class <pure> (<computation>)
              ((value :init-keyword :value)))

(define-class <effectful> (<computation>)
              ((effect :init-keyword :effect)
               (continuation :init-keyword :continuation)))

;; Build a computation that has already produced x.
(define (pure x)
  (make <pure> :value x))

;; Suspend effect until `run` finds its handler.
(define (perform effect)
  (make <effectful>
        :effect effect
        :continuation pure))

;; Sequence computations by applying f now for pure values, or later
;; through the stored continuation for suspended effects.
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

;; Each runtime maps an effect's exact class to its handler.
(define-method register-handler!
               ((runtime <runtime>) effect-class (handler <effect-handler>))
               (dict-put! (slot-ref runtime 'handlers)
                          effect-class
                          handler))

;; Resolve handlers by exact effect class; missing handlers raise an error.
(define-method find-handler
               ((runtime <runtime>) (effect <effect>))
               (or (dict-get (slot-ref runtime 'handlers)
                             (class-of effect)
                             #f)
                   (error "Unhandled effect:" effect)))

;; Interpret pure values directly; effectful computations delegate to
;; the selected handler and recursively interpret resumed computations.
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

;; The parallel effect handler runs child computations in Gauche futures,
;; then blocks on each result in input order. Failures do not guarantee
;; sibling cancellation or cleanup.
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

;; Sleep synchronously, then resume with the requested duration.
(define-method handle
               ((handler <sleep-handler>) (effect <sleep-effect>) resume)
               (thread-sleep! (slot-ref effect 'seconds))
               (resume (slot-ref effect 'seconds)))

;; Provide syntax for named sequential binds and `parallel` groups, binding
;; each group's results to its listed names in input order.
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
