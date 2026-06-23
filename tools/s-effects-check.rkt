#lang racket

(require racket/list
         racket/runtime-path
         racket/set
         racket/string
         "s-effects.rkt")

(provide check-effects-consistency
         effects-consistency-report)

(define-runtime-path runtime-source "s-runtime.rkt")
(define-runtime-path checker-source "s-checker.rkt")

(define (extract-effects path)
  (define names
    (for*/list ([line (in-list (file->lines path))]
                [name (in-list (extract-effects-from-line line))])
      name))
  (sort (remove-duplicates names string=?) string<?))

(define (extract-effects-from-line line)
  (define path-match (regexp-match #px"\\(path(.*)" line))
  (cond
    [(not path-match) '()]
    [else
     (define parts
       (regexp-match* #px"\"([^\"]+)\"" (second path-match) #:match-select cadr))
     (if (and (>= (length parts) 2)
              (member (first parts) '("host" "std" "world" "visual" "ui")))
         (list (string-join parts "."))
         '())]))

(define inventory-effects (sort (effect-names) string<?))
(define runtime-effects (extract-effects runtime-source))
(define checker-effects (extract-effects checker-source))

(define (check-effects-consistency)
  (define diagnostics (effects-consistency-diagnostics))
  (unless (null? diagnostics)
    (error 'effects-check "~a" (string-join diagnostics "\n"))))

(define (effects-consistency-report)
  (define diagnostics (effects-consistency-diagnostics))
  (if (null? diagnostics)
      (format "effects-check: ok\ninventory: ~a\nruntime: ~a\nchecker: ~a\n"
              (length inventory-effects)
              (length runtime-effects)
              (length checker-effects))
      (string-append "effects-check: failed\n"
                     (string-join diagnostics "\n")
                     "\n")))

(define (effects-consistency-diagnostics)
  (append
   (missing-lines "runtime missing inventory effect" inventory-effects runtime-effects)
   (missing-lines "runtime has unregistered effect" runtime-effects inventory-effects)
   (missing-lines "checker missing inventory effect" inventory-effects checker-effects)
   (missing-lines "checker has unregistered effect" checker-effects inventory-effects)))

(define (missing-lines label expected actual)
  (for/list ([name expected]
             #:unless (member name actual))
    (format "~a: ~a" label name)))
