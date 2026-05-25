#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-checker.rkt")

(define-runtime-path basic-source "../examples/basic.s")

(check-equal? (check-s-file basic-source) '())

(check-equal?
 (check-s-string
  #<<S
skill main() {
    y = 20
    out none
}
S
  )
 (list "error: variable 'y' is not declared"))

(check-equal?
 (check-s-string
  #<<S
MaxRetries = 3
skill main() {
    MaxRetries = 4
    out none
}
S
  )
 (list "error: cannot assign to constant 'MaxRetries'"))

(check-equal?
 (check-s-string
  #<<S
skill main() {
    @x = 10
    x = "hello"
    out none
}
S
  )
 (list "error: cannot assign string to variable 'x' of type number"))

(check-equal?
 (check-s-datum
  '(program
    (out (none))))
 (list "error: 'out' can only be used inside skill"))
