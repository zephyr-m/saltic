#lang racket

(require "s-machine-trace.rkt")

(define args (current-command-line-arguments))

(when (not (= (vector-length args) 1))
  (eprintf "usage: racket tools/machine-trace.rkt <file.s>\n")
  (exit 2))

(define path (vector-ref args 0))

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (eprintf "~a\n" (exn-message exn))
                   (exit 1))])
  (display (machine-trace-file path)))
