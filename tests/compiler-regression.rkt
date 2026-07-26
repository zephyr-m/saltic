#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-runtime.rkt")

(define-runtime-path probe
  "../examples/bootstrap/s-compiler-compare-probe.s")

(check-equal?
 (with-output-to-string (lambda () (run-s-file probe)))
 "compiled=0\nstages=0/0/0\nstaged=0\ndirect=0\n")
