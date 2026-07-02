#lang racket

(require rackunit
         "../tools/s-effects-check.rkt")

(check-not-exn check-effects-consistency)
(check-equal?
 (effects-consistency-report)
 "effects-check: ok\ninventory: 65\nruntime: 65\nchecker: 65\n")
