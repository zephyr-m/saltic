#lang racket

(require "s-checker.rkt")

(define args (current-command-line-arguments))

(when (not (= (vector-length args) 1))
  (eprintf "usage: racket tools/check.rkt <file.s>\n")
  (exit 2))

(define path (vector-ref args 0))

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (eprintf "~a\n" (exn-message exn))
                   (exit 1))])
  (define diagnostics (check-s-file path))
  (if (diagnostics-empty? diagnostics)
      (displayln "ok")
      (begin
        (print-diagnostics diagnostics (current-error-port))
        (exit 1))))
