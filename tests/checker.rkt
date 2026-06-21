#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-checker.rkt")

(define-runtime-path basic-source "../examples/basic.s")
(define-runtime-path try-source "../examples/try.s")

(check-equal? (check-s-file basic-source) '())
(check-equal? (check-s-file try-source) '())

(check-equal?
 (check-s-string
  #<<S
program() {
    y = 20
    out none
}
S
  )
 (list "2:5: error: variable 'y' is not declared"))

(check-equal?
 (check-s-string
  #<<S
MaxRetries = 3
program() {
    MaxRetries = 4
    out none
}
S
  )
 (list "3:5: error: cannot assign to constant 'MaxRetries'"))

(check-equal?
 (check-s-string
  #<<S
program() {
    @x = 10
    x = "hello"
    out none
}
S
  )
 (list "3:5: error: cannot assign string to variable 'x' of type number"))

(check-equal?
 (check-s-string
  #<<S
program() {
    host.io.println(missing)
    out none
}
S
  )
 (list "2:21: error: unknown name 'missing'"))

(check-equal?
 (check-s-datum
  '(program
    (out (none))))
 (list "error: 'out' can only be used inside skill"))
