#lang racket

(require racket/class
         racket/draw
         racket/list
         racket/match
         racket/string
         "s-runtime.rkt")

(define width 800)
(define height 480)
(define png-path #f)
(define fb-path #f)
(define source-path #f)
(define program-args '())

(define args (vector->list (current-command-line-arguments)))

(let loop ([remaining args])
  (match remaining
    ['() (void)]
    [(list "--png" path rest ...)
     (set! png-path path)
     (loop rest)]
    [(list "--fb" path rest ...)
     (set! fb-path path)
     (loop rest)]
    [(list "--size" size rest ...)
     (match (regexp-match #rx"^([0-9]+)x([0-9]+)$" size)
       [(list _ w h)
        (set! width (string->number w))
        (set! height (string->number h))]
       [_ (error 'ui-framebuffer "expected --size WIDTHxHEIGHT, got ~a" size)])
     (loop rest)]
    [(list path rest ...)
     (set! source-path path)
     (set! program-args rest)]))

(unless source-path
  (error 'ui-framebuffer
         "usage: racket tools/ui-framebuffer.rkt [--png out.png] [--fb /dev/fb0] [--size 800x480] program.s [args ...]"))

(unless (or png-path fb-path)
  (set! png-path "/tmp/s-ui-framebuffer.png"))

(define trace
  (with-output-to-string
    (lambda ()
      (run-s-file/args source-path program-args))))

(define commands
  (filter non-empty-string? (string-split trace "\n")))

(define (line-kind line)
  (match (string-split line)
    [(list kind _ ...) kind]
    [_ ""]))

(define title
  (for/or ([line (in-list commands)])
    (and (equal? (line-kind line) "text")
         (string-trim (substring line (string-length "text"))))))

(define values
  (for/list ([line (in-list commands)]
             #:when (equal? (line-kind line) "value"))
    (match (string-split line)
      [(list "value" name value ...)
       (cons name (string-join value " "))]
      [_ (cons "unknown" "")])))

(define fields
  (for/list ([line (in-list commands)]
             #:when (equal? (line-kind line) "field"))
    (match (regexp-match #rx"^field ([^ ]+) label (.+)$" line)
      [(list _ name label) (cons name label)]
      [_ (cons "field" "")])))

(define buttons
  (for/list ([line (in-list commands)]
             #:when (equal? (line-kind line) "button"))
    (match (regexp-match #rx"^button ([^ ]+) label (.+)$" line)
      [(list _ name label) (cons name label)]
      [_ (cons "button" "")])))

(define bitmap (make-bitmap width height))
(define dc (new bitmap-dc% [bitmap bitmap]))

(define bg (make-object color% 12 16 20))
(define panel-bg (make-object color% 22 28 34))
(define panel-border (make-object color% 0 210 220))
(define muted (make-object color% 135 150 160))
(define text-color (make-object color% 235 245 245))
(define accent (make-object color% 0 220 180))
(define danger (make-object color% 255 90 100))

(send dc set-background bg)
(send dc clear)
(send dc set-smoothing 'smoothed)

(define margin 36)
(define panel-x margin)
(define panel-y margin)
(define panel-w (- width (* 2 margin)))
(define panel-h (- height (* 2 margin)))

(send dc set-pen panel-border 2 'solid)
(send dc set-brush panel-bg 'solid)
(send dc draw-rounded-rectangle panel-x panel-y panel-w panel-h 8)

(send dc set-font (make-object font% 24 'default 'normal 'bold))
(send dc set-text-foreground text-color)
(send dc draw-text (or title "S UI") (+ panel-x 28) (+ panel-y 24))

(send dc set-font (make-object font% 12 'modern 'normal 'normal))
(send dc set-text-foreground muted)
(send dc draw-text "S-native UI trace -> framebuffer backend" (+ panel-x 30) (+ panel-y 60))

(define field-y (+ panel-y 104))
(send dc set-font (make-object font% 13 'default 'normal 'normal))
(for ([field (in-list fields)]
      [index (in-naturals)])
  (define x (+ panel-x 28 (* index 180)))
  (send dc set-text-foreground muted)
  (send dc draw-text (cdr field) x field-y)
  (send dc set-pen (make-object color% 70 82 94) 1 'solid)
  (send dc set-brush (make-object color% 12 18 24) 'solid)
  (send dc draw-rounded-rectangle x (+ field-y 24) 150 38 4))

(for ([button (in-list buttons)]
      [index (in-naturals)])
  (define x (+ panel-x 28 (* index 160)))
  (define y (+ field-y 86))
  (send dc set-pen accent 1 'solid)
  (send dc set-brush (make-object color% 0 70 68) 'solid)
  (send dc draw-rounded-rectangle x y 118 38 4)
  (send dc set-text-foreground text-color)
  (send dc draw-text (cdr button) (+ x 34) (+ y 10)))

(define values-y (+ panel-y 238))
(send dc set-font (make-object font% 14 'default 'normal 'normal))
(for ([entry (in-list values)]
      [index (in-naturals)])
  (define col (modulo index 2))
  (define row (quotient index 2))
  (define x (+ panel-x 28 (* col 320)))
  (define y (+ values-y (* row 62)))
  (send dc set-pen (make-object color% 42 54 64) 1 'solid)
  (send dc set-brush (make-object color% 15 22 28) 'solid)
  (send dc draw-rounded-rectangle x y 280 46 4)
  (send dc set-text-foreground muted)
  (send dc draw-text (car entry) (+ x 14) (+ y 7))
  (send dc set-font (make-object font% 15 'default 'normal 'bold))
  (send dc set-text-foreground
        (if (and (equal? (car entry) "status")
                 (not (equal? (cdr entry) "alive")))
            danger
            accent))
  (send dc draw-text (cdr entry) (+ x 150) (+ y 7))
  (send dc set-font (make-object font% 14 'default 'normal 'normal)))

(send dc set-bitmap #f)

(when png-path
  (send bitmap save-file png-path 'png)
  (printf "png: ~a\n" png-path))

(define (bitmap->fb-bytes bitmap width height bpp stride)
  (define argb (make-bytes (* width height 4)))
  (send bitmap get-argb-pixels 0 0 width height argb)
  (define bytes-per-pixel (/ bpp 8))
  (define row-bytes (* width bytes-per-pixel))
  (define fb-stride (or stride row-bytes))
  (when (< fb-stride row-bytes)
    (error 'ui-framebuffer "framebuffer stride ~a is smaller than row bytes ~a" fb-stride row-bytes))
  (match bpp
    [32
     (define out (make-bytes (* fb-stride height)))
     (for* ([y (in-range height)]
            [x (in-range width)])
       (define ai (* (+ (* y width) x) 4))
       (define oi (+ (* y fb-stride) (* x 4)))
       (bytes-set! out oi (bytes-ref argb (+ ai 3)))
       (bytes-set! out (+ oi 1) (bytes-ref argb (+ ai 2)))
       (bytes-set! out (+ oi 2) (bytes-ref argb (+ ai 1)))
       (bytes-set! out (+ oi 3) 0))
     out]
    [24
     (define out (make-bytes (* fb-stride height)))
     (for* ([y (in-range height)]
            [x (in-range width)])
       (define ai (* (+ (* y width) x) 4))
       (define oi (+ (* y fb-stride) (* x 3)))
       (bytes-set! out oi (bytes-ref argb (+ ai 3)))
       (bytes-set! out (+ oi 1) (bytes-ref argb (+ ai 2)))
       (bytes-set! out (+ oi 2) (bytes-ref argb (+ ai 1))))
     out]
    [_ (error 'ui-framebuffer "unsupported framebuffer bpp: ~a" bpp)]))

(define (read-number path fallback)
  (with-handlers ([exn:fail? (lambda (_) fallback)])
    (string->number (string-trim (file->string path)))))

(when fb-path
  (unless (file-exists? fb-path)
    (error 'ui-framebuffer "framebuffer device does not exist: ~a" fb-path))
  (define bpp (read-number "/sys/class/graphics/fb0/bits_per_pixel" 32))
  (define stride (read-number "/sys/class/graphics/fb0/stride" #f))
  (define raw (bitmap->fb-bytes bitmap width height bpp stride))
  (call-with-output-file fb-path
    (lambda (out) (write-bytes raw out))
    #:exists 'update)
  (printf "fb: ~a\n" fb-path))
