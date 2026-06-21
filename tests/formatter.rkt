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

(define box-source
  #<<S
Point=Box{x=0,y=0}
program(){@p=Point{x=5}out p.x}
S
  )

(define formatted-box
  (string-append
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
   "\n"))

(check-equal? (format-s-string box-source) formatted-box)

(define group-source
  #<<S
program(){@items=[1,2,3]out none}
S
  )

(define formatted-group
  (string-append
   #<<S
program() {
    @items = [
        1,
        2,
        3,
    ]
    out none
}
S
   "\n"))

(check-equal? (format-s-string group-source) formatted-group)

(define answer-source
  #<<S
program(){@ok=yes @stop=no out none}
S
  )

(define formatted-answer
  (string-append
   #<<S
program() {
    @ok = yes
    @stop = no
    out none
}
S
   "\n"))

(check-equal? (format-s-string answer-source) formatted-answer)
