#lang racket

(require rackunit
         "../tools/s-effects-check.rkt")

(check-not-exn check-effects-consistency)
(check-equal?
 (effects-consistency-report)
 "effects-check: ok\ninventory: 75\nruntime: 75\nchecker: 75\n")
