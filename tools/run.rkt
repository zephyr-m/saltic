#lang racket

(require "s-checker.rkt"
         "s-runtime.rkt")

(define args (current-command-line-arguments))

(when (< (vector-length args) 1)
  (eprintf "usage: racket tools/run.rkt <file.s> [args ...]\n")
  (exit 2))

(define path (vector-ref args 0))
(define program-args
  (for/list ([i (in-range 1 (vector-length args))])
    (vector-ref args i)))

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (eprintf "~a\n" (exn-message exn))
                   (exit 1))])
  (define diagnostics (check-s-file path))
  (if (diagnostics-empty? diagnostics)
      (void (run-s-file/args path program-args))
      (begin
        (print-diagnostics diagnostics (current-error-port))
        (exit 1))))
