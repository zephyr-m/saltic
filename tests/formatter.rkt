#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-formatter.rkt"
         "../tools/s-parser.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")

(define messy-source
  #<<S
MaxRetries=3
Status=enum{OK,ERROR,}
program(){
@x=10
(x==10){host.io.println("ok")}
drum(2){host.io.println("tick")}
out none
}
S
  )

(define formatted-messy
  (string-append
   #<<S
MaxRetries = 3

Status = enum {
    OK,
    ERROR,
}

program() {
    @x = 10
    (x == 10) {
        host.io.println("ok")
    }
    drum (2) {
        host.io.println("tick")
    }
    out none
}
S
   "\n"))

(check-equal? (format-s-string messy-source) formatted-messy)

(check-equal?
 (format-s-string (format-s-string messy-source))
 formatted-messy)

(check-equal?
 (ast->datum (parse-s-string (format-s-file basic-source)))
 (ast->datum (parse-s-file basic-source)))
