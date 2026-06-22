#lang racket

(require "s-effects-check.rkt")

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (eprintf "~a\n" (exn-message exn))
                   (exit 1))])
  (display (effects-consistency-report))
  (check-effects-consistency))
