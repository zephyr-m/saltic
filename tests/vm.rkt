#lang racket

(require rackunit
         "../tools/s-vm.rkt")

(define source
  '(program
    (skill "add" ("a" "b")
           (block
            (out (binary "+" (path "a") (path "b")))))
    (entry ()
           (block
            (var "x" (call (path "add") (number 2) (number 3)))
            (expr (call (path "std" "io" "println") (string "x=") (path "x")))
            (out (path "x"))))))

(define program (compile-s-datum/vm source))

(check-equal?
 (vm-bytecode->text program)
 "function program()\n  0: (push 2)\n  1: (push 3)\n  2: (call \"add\" 2)\n  3: (store \"x\")\n  4: (push \"x=\")\n  5: (load \"x\")\n  6: (call \"std.io.println\" 2)\n  7: (pop)\n  8: (load \"x\")\n  9: (return)\n  10: (push-none)\n  11: (return)\nfunction add(a, b)\n  0: (load \"a\")\n  1: (load \"b\")\n  2: (add)\n  3: (return)\n  4: (push-none)\n  5: (return)\n")

(define result (run-s-datum/vm source))

(check-equal? (vm-run-result-value result) 5)
(check-equal? (vm-run-result-output result) "x=5\n")

(define std-result
  (run-s-datum/vm
   '(program
     (use "std")
     (entry ()
            (block
             (var "text" (call (path "std" "str" "add") (string "S") (string " VM")))
             (expr (call (path "std" "io" "println") (path "text")))
             (out (call (path "std" "str" "len") (path "text"))))))))

(check-equal? (vm-run-result-value std-result) 4)
(check-equal? (vm-run-result-output std-result) "S VM\n")

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
            (expr (call (path "std" "io" "println") (string "x=") (path "p" "x")))
            (out (path "p" "y"))))))

(define box-program (compile-s-datum/vm box-source))
(define box-result (run-s-datum/vm box-source))

(check-true (regexp-match? #rx"\\(box-new \"Point\" \\(\"x\" \"y\"\\)\\)" (vm-bytecode->text box-program)))
(check-true (regexp-match? #rx"\\(field \"x\"\\)" (vm-bytecode->text box-program)))
(check-equal? (vm-run-result-value box-result) 20)
(check-equal? (vm-run-result-output box-result) "x=10\n")

(define group-source
  '(program
    (use "std")
    (entry ()
           (block
            (var "items" (group (number 1) (number 2) (number 3)))
            (var "index" (number 0))
            (var "sum" (number 0))
            (drum (call (path "std" "group" "count") (path "items"))
                  (block
                   (var "item" (call (path "std" "group" "at") (path "items") (path "index")))
                   (assign "sum" (binary "+" (path "sum") (path "item")))
                   (assign "index" (binary "+" (path "index") (number 1)))))
            (expr (call (path "std" "io" "println") (string "sum=") (path "sum")))
            (out (path "sum"))))))

(define group-program (compile-s-datum/vm group-source))
(define group-result (run-s-datum/vm group-source))

(check-true (regexp-match? #rx"\\(group 3\\)" (vm-bytecode->text group-program)))
(check-true (regexp-match? #rx"\\(drum \\(" (vm-bytecode->text group-program)))
(check-equal? (vm-run-result-value group-result) 6)
(check-equal? (vm-run-result-output group-result) "sum=6\n")

(check-exn
 #rx"unsupported statement"
 (lambda ()
   (compile-s-datum/vm
    '(program
      (entry ()
             (block
              (switch (path "value")
                      (case "OK" (string "ok")))
              (out (none))))))))
