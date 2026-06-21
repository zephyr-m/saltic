#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-explainer.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
(define-runtime-path world-source "../examples/bootstrap/world-basic.s")
(define-runtime-path std-source "../examples/canonical/report-generator.std.s")

(define basic-explanation (explain-s-file basic-source))
(define world-explanation (explain-s-file world-source))
(define std-explanation (explain-s-file std-source))

(check-true (regexp-match? #rx"top-level: 2 constants, 1 enums, 2 skills, 1 program" basic-explanation))
(check-true (regexp-match? #rx"program\\(\\)" basic-explanation))
(check-true (regexp-match? #rx"add\\(a, b\\)" basic-explanation))
(check-true (regexp-match? #rx"host.io.println" basic-explanation))

(check-true (regexp-match? #rx"world.spawn" world-explanation))
(check-true (regexp-match? #rx"world.place" world-explanation))
(check-true (regexp-match? #rx"world.move" world-explanation))
(check-true (regexp-match? #rx"world.trace" world-explanation))

(check-true (regexp-match? #rx"imports:\n  - std" std-explanation))
(check-true (regexp-match? #rx"std.io.println" std-explanation))
(check-true (regexp-match? #rx"std.file.read_text" std-explanation))
