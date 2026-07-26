#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-vm.rkt")

(define-runtime-path tiny-vm-path "../examples/bootstrap/s-vm-tiny.s")
(define-runtime-path step-ab-path "../examples/bootstrap/s-vm-step-ab.s")
(define-runtime-path step-c-path "../examples/bootstrap/s-vm-step-c.s")
(define-runtime-path step-d-path "../examples/bootstrap/s-vm-step-d.s")
(define-runtime-path step-drum-path "../examples/bootstrap/s-vm-step-drum.s")
(define-runtime-path step-switch-path "../examples/bootstrap/s-vm-step-switch.s")
(define-runtime-path step-rescue-path "../examples/bootstrap/s-vm-step-rescue.s")
(define-runtime-path step-call-path "../examples/bootstrap/s-vm-step-call.s")
(define-runtime-path step-boundary-path "../examples/bootstrap/s-vm-step-boundary.s")

(define source
  '(program
    (skill "add" ("a" "b")
           (block
            (out (binary "+" (path "a") (path "b")))))
    (entry ()
           (block
            (var "x" (call (path "add") (number 2) (number 3)))
            (expr (call (path "core" "io" "println") (string "x=") (path "x")))
            (out (path "x"))))))

(define program (compile-s-datum/vm source))

(check-equal?
 (vm-bytecode->text program)
 "function program()\n  0: (push 2)\n  1: (push 3)\n  2: (call \"add\" 2)\n  3: (store \"x\")\n  4: (push \"x=\")\n  5: (load \"x\")\n  6: (call \"core.io.println\" 2)\n  7: (pop)\n  8: (load \"x\")\n  9: (return)\n  10: (push-none)\n  11: (return)\nfunction add(a, b)\n  0: (load \"a\")\n  1: (load \"b\")\n  2: (add)\n  3: (return)\n  4: (push-none)\n  5: (return)\n")

(define result (run-s-datum/vm source))

(check-equal? (vm-run-result-value result) 5)
(check-equal? (vm-run-result-output result) "x=5\n")

(define core-result
  (run-s-datum/vm
   '(program
     (use "core")
     (entry ()
            (block
             (var "text" (call (path "core" "str" "add") (string "S") (string " VM")))
             (expr (call (path "core" "io" "println") (path "text")))
             (out (call (path "core" "str" "len") (path "text"))))))))

(check-equal? (vm-run-result-value core-result) 4)
(check-equal? (vm-run-result-output core-result) "S VM\n")

(define core-string-result
  (run-s-datum/vm
   '(program
     (use "core")
     (entry ()
            (block
             (expr (call (path "core" "io" "println")
                         (string "at=")
                         (call (path "core" "str" "at") (string "abc") (number 1))))
             (expr (call (path "core" "io" "println")
                         (string "slice=")
                         (call (path "core" "str" "slice") (string "abcdef") (number 1) (number 4))))
             (expr (call (path "core" "io" "println")
                         (string "contains=")
                         (call (path "core" "str" "contains") (string "runtime") (string "time"))))
             (expr (call (path "core" "io" "println")
                         (string "starts=")
                         (call (path "core" "str" "starts_with") (string "runtime") (string "run"))))
             (expr (call (path "core" "io" "println")
                         (string "ends=")
                         (call (path "core" "str" "ends_with") (string "runtime") (string "time"))))
             (expr (call (path "core" "io" "println")
                         (string "lines=")
                         (call (path "core" "str" "lines_count") (string "a\nb\n"))))
             (out (call (path "core" "str" "contains") (string "runtime") (string "room"))))))))

(check-equal? (vm-run-result-value core-string-result) #f)
(check-equal? (vm-run-result-output core-string-result) "at=b\nslice=bcd\ncontains=yes\nstarts=yes\nends=yes\nlines=2\n")

(define box-source
  '(program
    (box "Point"
         (field "x" (number 0))
         (field "y" (number 0)))
    (skill "make_point" ("x" "y")
           (block
            (out (box-new "Point"
                          (field "x" (path "x"))
                          (field "y" (path "y"))))))
    (entry ()
           (block
            (var "p" (call (path "make_point") (number 10) (number 20)))
            (expr (call (path "core" "io" "println") (string "x=") (path "p" "x")))
            (out (path "p" "y"))))))

(define box-program (compile-s-datum/vm box-source))
(define box-result (run-s-datum/vm box-source))

(check-true (regexp-match? #rx"\\(box-new \"Point\" \\(\"x\" \"y\"\\)\\)" (vm-bytecode->text box-program)))
(check-true (regexp-match? #rx"\\(field \"x\"\\)" (vm-bytecode->text box-program)))
(check-equal? (vm-run-result-value box-result) 20)
(check-equal? (vm-run-result-output box-result) "x=10\n")

(define group-source
  '(program
    (use "core")
    (entry ()
           (block
            (var "items" (group (number 1) (number 2) (number 3)))
            (var "index" (number 0))
            (var "sum" (number 0))
            (drum (call (path "core" "group" "count") (path "items"))
                  (block
                   (var "item" (call (path "core" "group" "at") (path "items") (path "index")))
                   (assign "sum" (binary "+" (path "sum") (path "item")))
                   (assign "index" (binary "+" (path "index") (number 1)))))
            (expr (call (path "core" "io" "println") (string "sum=") (path "sum")))
            (out (path "sum"))))))

(define group-program (compile-s-datum/vm group-source))
(define group-result (run-s-datum/vm group-source))

(check-true (regexp-match? #rx"\\(group 3\\)" (vm-bytecode->text group-program)))
(check-true (regexp-match? #rx"\\(drum \\(" (vm-bytecode->text group-program)))
(check-equal? (vm-run-result-value group-result) 6)
(check-equal? (vm-run-result-output group-result) "sum=6\n")

(define error-source
  '(program
    (entry ()
           (block
            (var "value" (binary "/" (number 10) (number 0)))
            (expr (call (path "core" "io" "println") (path "value")))
            (out (path "value"))))))

(define error-result (run-s-datum/vm error-source))

(check-true (vm-error-value? (vm-run-result-value error-result)))
(check-equal? (vm-error-value-name (vm-run-result-value error-result)) "DivisionByZero")
(check-equal? (vm-run-result-output error-result) "error.DivisionByZero\n")

(define rescue-source
  '(program
    (entry ()
           (block
            (var "value"
                 (rescue (binary "/" (number 10) (number 0))
                         "err"
                         (block
                          (expr (number 0)))))
            (expr (call (path "core" "io" "println") (string "value=") (path "value")))
            (out (path "value"))))))

(define rescue-program (compile-s-datum/vm rescue-source))
(define rescue-result (run-s-datum/vm rescue-source))

(check-true (regexp-match? #rx"\\(push-error \"Manual\"\\)"
                           (vm-bytecode->text
                            (compile-s-datum/vm
                             '(program
                               (entry ()
                                      (block
                                       (out (path "error" "Manual")))))))))
(check-true (regexp-match? #rx"\\(rescue \"err\"" (vm-bytecode->text rescue-program)))
(check-equal? (vm-run-result-value rescue-result) 0)
(check-equal? (vm-run-result-output rescue-result) "value=0\n")

(define switch-source
  '(program
    (use "core")
    (enum "Status" "OK" "ERROR" "PENDING")
    (entry ()
           (block
            (var "status" (path "Status" "OK"))
            (switch (path "status")
                    (case "OK" (call (path "core" "io" "println") (string "ok")))
                    (case "ERROR" (call (path "core" "io" "println") (string "error"))))
            (expr (call (path "core" "io" "println") (path "status")))
            (out (none))))))

(define switch-program (compile-s-datum/vm switch-source))
(define switch-result (run-s-datum/vm switch-source))

(check-true (regexp-match? #rx"\\(push-enum \"Status\" \"OK\"\\)" (vm-bytecode->text switch-program)))
(check-true (regexp-match? #rx"\\(switch \\(\\(case \"OK\"" (vm-bytecode->text switch-program)))
(check-equal? (vm-run-result-output switch-result) "ok\nStatus.OK\n")

(define if-source
  '(program
    (entry ()
           (block
            (var "value" (number 0))
            (if (answer "yes")
                (block
                 (assign "value" (number 7))))
            (if (answer "no")
                (block
                 (assign "value" (number 99))))
            (out (path "value"))))))

(define if-program (compile-s-datum/vm if-source))
(define if-result (run-s-datum/vm if-source))

(check-true (regexp-match? #rx"\\(if \\(" (vm-bytecode->text if-program)))
(check-equal? (vm-run-result-value if-result) 7)

(define tiny-vm-result
  (run-s-file/vm tiny-vm-path))

(check-equal? (vm-run-result-value tiny-vm-result) 10)
(check-equal? (vm-run-result-output tiny-vm-result) "tiny-vm result=10\n")

(define step-ab-result
  (run-s-file/vm step-ab-path))

(check-equal? (vm-run-result-value step-ab-result) #t)
(check-equal? (vm-run-result-output step-ab-result) "step-ab result=yes\n")

(define step-c-result
  (run-s-file/vm step-c-path))

(check-equal? (vm-run-result-value step-c-result) #t)
(check-equal? (vm-run-result-output step-c-result) "step-c result=yes\n")

(define step-d-result
  (run-s-file/vm step-d-path))

(check-equal? (vm-run-result-value step-d-result) #t)
(check-equal? (vm-run-result-output step-d-result) "step-d result=yes\n")

(define step-drum-result
  (run-s-file/vm step-drum-path))

(check-equal? (vm-run-result-value step-drum-result) #t)
(check-equal? (vm-run-result-output step-drum-result) "step-drum result=yes\n")

(define step-switch-result
  (run-s-file/vm step-switch-path))

(check-equal? (vm-run-result-value step-switch-result) #t)
(check-equal? (vm-run-result-output step-switch-result) "step-switch result=yes\n")

(define step-rescue-result
  (run-s-file/vm step-rescue-path))

(check-equal? (vm-run-result-value step-rescue-result) #t)
(check-equal? (vm-run-result-output step-rescue-result) "step-rescue result=yes\n")

(define step-call-result
  (run-s-file/vm step-call-path))

(check-equal? (vm-run-result-value step-call-result) #t)
(check-equal? (vm-run-result-output step-call-result) "step-call result=yes\n")

(define step-boundary-result
  (run-s-file/vm step-boundary-path))

(check-equal? (vm-run-result-value step-boundary-result) #t)
(check-equal? (vm-run-result-output step-boundary-result) "boundary result=42\nboundary count=2\nboundary picked=beta\nboundary visual=sheet boundary\npresent\n\nboundary world=spawn #1 box\nplace #1 1 2\n\nboundary trim=s\nboundary upper=S\nboundary lower=s\nstep-boundary result=yes\n")

(define error-switch-result
  (run-s-datum/vm
   '(program
     (use "core")
     (entry ()
            (block
             (var "value" (binary "/" (number 10) (number 0)))
             (switch (path "value")
                     (case "DivisionByZero"
                       (call (path "core" "io" "println") (string "zero"))))
             (out (none)))))))

(check-equal? (vm-run-result-output error-switch-result) "zero\n")

(define visual-source
  '(program
    (entry ()
           (block
            (expr (call (path "visual" "sheet") (string "engineering")))
            (expr (call (path "visual" "grid") (number 24)))
            (expr (call (path "visual" "square_bipyramid")
                        (string "crystal")
                        (number 4)
                        (number 2)
                        (string "cyan")))
            (expr (call (path "visual" "rotate")
                        (string "crystal")
                        (string "y")
                        (number 1)))
            (expr (call (path "visual" "present")))
            (expr (call (path "visual" "trace")))
            (out (call (path "visual" "trace_text")))))))

(define visual-result (run-s-datum/vm visual-source))
(define visual-trace
  "sheet engineering\ngrid 24\nshape square_bipyramid crystal height 4 base 2 color cyan\nmotion rotate crystal y 1\npresent\n")

(check-equal? (vm-run-result-value visual-result) visual-trace)
(check-equal? (vm-run-result-output visual-result) visual-trace)

(define world-source
  '(program
    (entry ()
           (block
            (var "box" (call (path "world" "spawn") (string "box")))
            (expr (call (path "world" "emit") (path "box") (string "place") (number 10) (number 20)))
            (expr (call (path "world" "emit") (path "box") (string "move") (number 5) (number 0)))
            (expr (call (path "world" "step")))
            (var "trace" (call (path "world" "trace_text")))
            (var "state" (call (path "world" "state_text")))
            (expr (call (path "core" "io" "println") (call (path "world" "replay") (path "trace"))))
            (out (path "state"))))))

(define world-result (run-s-datum/vm world-source))
(define world-trace "spawn #1 box\nplace #1 10 20\nmove #1 5 0\n")
(define world-state "#1 box at 15 20\n")

(check-equal? (vm-run-result-value world-result) world-state)
(check-equal? (vm-run-result-output world-result) (string-append world-state "\n"))

(define object-skill-call-result
  (run-s-datum/vm
   '(program
     (use "core")
     (entry ()
            (block
             (var "box" (call (path "world" "spawn") (string "box")))
             (expr (call (path "world" "emit") (path "box") (string "place") (number 10) (number 20)))
             (expr (call (path "world" "emit") (path "box") (string "move") (number 5) (number 0)))
             (expr (call (path "world" "step")))
             (expr (call (path "core" "io" "println") (call (path "world" "state_text"))))
             (out (none)))))))

(check-equal? (vm-run-result-output object-skill-call-result) "#1 box at 15 20\n\n")
