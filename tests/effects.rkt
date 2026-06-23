#lang racket

(require rackunit
         "../tools/s-effects.rkt")

(check-not-false (member "host.io.println" (effect-names)))
(check-not-false (member "std.io.println" (effect-names)))
(check-not-false (member "world.spawn" (effect-names)))
(check-not-false (member "visual.square_bipyramid" (effect-names)))
(check-not-false (member "ui.panel" (effect-names)))

(define output (effects->text))

(check-true (regexp-match? #rx"effect[ ]+owner[ ]+status[ ]+kind[ ]+decision" output))
(check-true (regexp-match? #rx"host\\.file\\.read[ ]+bootstrap[ ]+implemented[ ]+effect[ ]+bridge to std\\.file\\.read_text" output))
(check-true (regexp-match? #rx"visual\\.trace_text[ ]+visual[ ]+protocol-v0[ ]+pure[ ]+return visual trace" output))
(check-true (regexp-match? #rx"ui\\.trace_text[ ]+ui[ ]+protocol-v0[ ]+pure[ ]+return ui trace" output))
