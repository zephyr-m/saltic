#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-machine-trace.rkt")

(define-runtime-path visual-task "../tasks/011-visual-observation-protocol/solution.s")

(check-equal?
 (machine-trace-file visual-task)
 "step 1: enter program()\nstep 2: bind crystal = Crystal {}\nstep 3: call observe_crystal(crystal)\nstep 4: enter observe_crystal(crystal)\nstep 5: effect visual.sheet(\"engineering\")\nstep 6: effect visual.grid(24)\nstep 7: effect visual.square_bipyramid(crystal.name, crystal.height, crystal.base, crystal.color)\nstep 8: effect visual.rotate(crystal.name, \"y\", crystal.spin)\nstep 9: effect visual.present()\nstep 10: return none\nstep 11: effect visual.trace()\nstep 12: return none\nstep 13: halt\n")
