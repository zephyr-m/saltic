#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-parser.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
(define-runtime-path try-source "../examples/bootstrap/try.s")

(define basic-ast (parse-s-file basic-source))
(define basic-datum (ast->datum basic-ast))
(define basic-loc-datum (ast->datum/loc basic-ast))
(define try-datum (ast->datum (parse-s-file try-source)))

(check-match basic-datum
  `(program
     (const "MaxRetries" (number 3))
     (const "AppName" (string "S Language"))
     (enum "Status" "OK" "ERROR" "PENDING")
     . ,_))

(check-true
 (for/or ([item (cdr basic-datum)])
   (match item
     [`(entry ,_ ,_) #t]
     [_ #f])))

(check-true
 (for/or ([item (cdr basic-datum)])
   (match item
     [`(skill "add" ,_ ,_) #t]
     [_ #f])))

(check-true
 (regexp-match?
  #rx"rescue"
  (format "~s" basic-datum)))

(check-true
 (regexp-match?
  #rx"switch"
  (format "~s" basic-datum)))

(check-true
 (regexp-match?
  #rx"Status"
  (format "~s" try-datum)))

(check-match basic-loc-datum
  `(program
     (loc 1 1 (const "MaxRetries" (loc 1 14 (number 3))))
     . ,_))

(check-match
 (ast->datum
  (parse-s-string
   #<<S
use std

program() {
    std.io.println("ok")
    out none
}
S
   ))
 `(program
   (use "std")
   (entry () ,_)))

(check-equal?
 (ast->datum
  (parse-s-string
   #<<S
program() {
    @safe = 47 > 30
    @low = 12 < 30
    out none
}
S
   ))
 '(program
   (entry ()
          (block
           (var "safe" (binary ">" (number 47) (number 30)))
           (var "low" (binary "<" (number 12) (number 30)))
           (out (none))))))

(check-equal?
 (ast->datum
  (parse-s-string
   #<<S
Point = Box {
    x = 0
    y = 0
}

program() {
    @p = Point {
        x = 5
    }
    out p.x
}
S
   ))
 '(program
   (box "Point" (field "x" (number 0)) (field "y" (number 0)))
   (entry ()
          (block
           (var "p" (box-new "Point" (field "x" (number 5))))
           (out (path "p" "x"))))))

(check-equal?
 (ast->datum
  (parse-s-string
   #<<S
program() {
    @items = [1, 2, 3]
    out none
}
S
   ))
 '(program
   (entry ()
          (block
           (var "items" (group (number 1) (number 2) (number 3)))
           (out (none))))))
