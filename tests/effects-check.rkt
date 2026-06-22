#lang racket

(require rackunit
         "../tools/s-effects-check.rkt")

(check-not-exn check-effects-consistency)
(check-equal?
 (effects-consistency-report)
 "effects-check: ok\ninventory: 48\nruntime: 48\nchecker: 48\n")
