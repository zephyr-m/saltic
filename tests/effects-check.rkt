#lang racket

(require rackunit
         "../tools/s-effects-check.rkt")

(check-not-exn check-effects-consistency)
(check-equal?
 (effects-consistency-report)
 "effects-check: ok\ninventory: 74\nruntime: 74\nchecker: 74\n")
