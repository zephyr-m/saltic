#lang racket

(require racket/date
         racket/draw
         racket/gui/base
         racket/list
         racket/match
         racket/string
         "s-runtime.rkt")

(define source-path "examples/apps/family-ledger/ui.s")
(define ledger-path "examples/apps/family-ledger/ledger.txt")

(define width 820)
(define height 520)

(define selected-kind "expense")
(define active-field #f)
(define amount-text "")
(define label-text "")
(define status-text "ready")
(define ledger-values (make-hash))
(define hitboxes (make-hash))

(define bg (make-object color% 8 11 15))
(define board-bg (make-object color% 18 24 31))
(define board-line (make-object color% 0 210 220))
(define muted (make-object color% 135 150 160))
(define text-color (make-object color% 235 245 245))
(define field-bg (make-object color% 10 16 22))
(define field-line (make-object color% 58 72 86))
(define accent (make-object color% 0 220 180))
(define accent-dark (make-object color% 0 72 68))
(define danger (make-object color% 255 90 100))

(define (ledger-trace)
  (with-output-to-string
    (lambda ()
      (run-s-file/args source-path (list ledger-path)))))

(define (trace-values trace)
  (for/hash ([line (in-list (filter non-empty-string? (string-split trace "\n")))]
             #:when (string-prefix? line "value "))
    (match (string-split line)
      [(list "value" name value ...)
       (values name (string-join value " "))]
      [_ (values "unknown" "")])))

(define (refresh-values!)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (set! status-text (format "error: ~a" (exn-message exn))))])
    (set! ledger-values (trace-values (ledger-trace)))
    (set! status-text "ready")))

(define (today-text)
  (define now (seconds->date (current-seconds)))
  (format "~a-~a-~a"
          (date-year now)
          (~r (date-month now) #:min-width 2 #:pad-string "0")
          (~r (date-day now) #:min-width 2 #:pad-string "0")))

(define (append-entry!)
  (define clean-amount (string-trim amount-text))
  (define clean-label (string-trim label-text))
  (cond
    [(or (string=? clean-amount "")
         (not (string->number clean-amount)))
     (set! status-text "amount must be a number")]
    [else
     (define final-label
       (if (string=? clean-label "") "entry" (string-replace clean-label " " "_")))
     (call-with-output-file ledger-path
       (lambda (out)
         (fprintf out "~a ~a ~a ~a\n" selected-kind (today-text) clean-amount final-label))
       #:exists 'append)
     (set! amount-text "")
     (set! label-text "")
     (refresh-values!)]))

(define (inside? x y box)
  (match box
    [(list bx by bw bh)
     (and (<= bx x (+ bx bw))
          (<= by y (+ by bh)))]
    [_ #f]))

(define (remember! id x y w h)
  (hash-set! hitboxes id (list x y w h)))

(define (draw-text* dc text x y color font)
  (send dc set-font font)
  (send dc set-text-foreground color)
  (send dc draw-text text x y))

(define (draw-box dc x y w h #:active? [active? #f])
  (send dc set-pen (if active? accent field-line) (if active? 2 1) 'solid)
  (send dc set-brush field-bg 'solid)
  (send dc draw-rounded-rectangle x y w h 6))

(define (draw-kind dc x y label active?)
  (send dc set-pen (if active? accent field-line) 1 'solid)
  (send dc set-brush (if active? accent-dark field-bg) 'solid)
  (send dc draw-rounded-rectangle x y 104 34 6)
  (draw-text* dc label (+ x 18) (+ y 8) text-color (make-object font% 12 'default)))

(define (draw-ledger-board dc)
  (hash-clear! hitboxes)
  (send dc set-background bg)
  (send dc clear)
  (send dc set-smoothing 'smoothed)

  (define board-x 34)
  (define board-y 30)
  (define board-w (- width 68))
  (define board-h (- height 60))

  (send dc set-pen board-line 2 'solid)
  (send dc set-brush board-bg 'solid)
  (send dc draw-rounded-rectangle board-x board-y board-w board-h 10)

  (draw-text* dc "Ledger Board" 64 64 text-color (make-object font% 28 'default 'normal 'bold))
  (draw-text* dc "interactive surface inside S world" 66 100 muted (make-object font% 12 'modern))

  (define kind-y 142)
  (draw-text* dc "kind" 66 kind-y muted (make-object font% 12 'default))
  (for ([kind (in-list '("income" "expense" "debt"))]
        [index (in-naturals)])
    (define x (+ 66 (* index 118)))
    (define y (+ kind-y 24))
    (remember! (string->symbol (format "kind:~a" kind)) x y 104 34)
    (draw-kind dc x y kind (equal? selected-kind kind)))

  (define field-y 228)
  (draw-text* dc "amount" 66 field-y muted (make-object font% 12 'default))
  (draw-box dc 66 (+ field-y 24) 180 42 #:active? (equal? active-field 'amount))
  (remember! 'amount 66 (+ field-y 24) 180 42)
  (draw-text* dc amount-text 82 (+ field-y 36) text-color (make-object font% 15 'default))

  (draw-text* dc "label" 276 field-y muted (make-object font% 12 'default))
  (draw-box dc 276 (+ field-y 24) 220 42 #:active? (equal? active-field 'label))
  (remember! 'label 276 (+ field-y 24) 220 42)
  (draw-text* dc label-text 292 (+ field-y 36) text-color (make-object font% 15 'default))

  (send dc set-pen accent 1 'solid)
  (send dc set-brush accent-dark 'solid)
  (send dc draw-rounded-rectangle 526 (+ field-y 24) 116 42 6)
  (remember! 'add 526 (+ field-y 24) 116 42)
  (draw-text* dc "Add" 564 (+ field-y 36) text-color (make-object font% 15 'default 'normal 'bold))

  (define value-y 330)
  (for ([name (in-list '("income" "expenses" "debt" "free" "status"))]
        [index (in-naturals)])
    (define col (modulo index 2))
    (define row (quotient index 2))
    (define x (+ 66 (* col 322)))
    (define y (+ value-y (* row 58)))
    (define value (hash-ref ledger-values name "0"))
    (send dc set-pen (make-object color% 42 54 64) 1 'solid)
    (send dc set-brush (make-object color% 12 18 24) 'solid)
    (send dc draw-rounded-rectangle x y 278 42 6)
    (draw-text* dc name (+ x 14) (+ y 11) muted (make-object font% 13 'default))
    (draw-text* dc value (+ x 142) (+ y 10)
                (if (and (equal? name "status") (not (equal? value "alive"))) danger accent)
                (make-object font% 14 'default 'normal 'bold)))

  (draw-text* dc status-text 66 (- height 52) muted (make-object font% 12 'modern)))

(define ledger-canvas%
  (class canvas%
    (inherit get-dc refresh focus)
    (define/override (on-paint)
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (set! status-text (format "paint error: ~a" (exn-message exn))))])
        (draw-ledger-board (get-dc))))
    (define/override (on-event event)
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (set! status-text (format "event error: ~a" (exn-message exn)))
                         (refresh))])
        (when (equal? (send event get-event-type) 'left-down)
          (define x (send event get-x))
          (define y (send event get-y))
          (focus)
          (cond
            [(inside? x y (hash-ref hitboxes 'amount #f))
             (set! active-field 'amount)]
            [(inside? x y (hash-ref hitboxes 'label #f))
             (set! active-field 'label)]
            [(inside? x y (hash-ref hitboxes 'add #f))
             (append-entry!)]
            [else
             (for ([kind (in-list '("income" "expense" "debt"))])
               (define id (string->symbol (format "kind:~a" kind)))
               (when (inside? x y (hash-ref hitboxes id #f))
                 (set! selected-kind kind)))])
          (refresh))))
    (define/override (on-char event)
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (set! status-text (format "key error: ~a" (exn-message exn)))
                         (refresh))])
        (define key (send event get-key-code))
        (cond
          [(equal? key 'backspace)
           (cond
             [(and (equal? active-field 'amount) (positive? (string-length amount-text)))
              (set! amount-text (substring amount-text 0 (sub1 (string-length amount-text))))]
             [(and (equal? active-field 'label) (positive? (string-length label-text)))
              (set! label-text (substring label-text 0 (sub1 (string-length label-text))))])]
          [(equal? key 'return)
           (append-entry!)]
          [(char? key)
           (cond
             [(equal? active-field 'amount)
              (when (or (char-numeric? key) (equal? key #\-))
                (set! amount-text (string-append amount-text (string key))))]
             [(equal? active-field 'label)
              (when (or (char-alphabetic? key)
                        (char-numeric? key)
                        (member key '(#\space #\_ #\-)))
                (set! label-text (string-append label-text (string key))))])])
        (refresh)))
    (super-new)))

(refresh-values!)

(define frame
  (new frame%
       [label "S World Ledger"]
       [width width]
       [height height]))

(define canvas
  (new ledger-canvas%
       [parent frame]
       [style '(border)]))

(send frame show #t)
