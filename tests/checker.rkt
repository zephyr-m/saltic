#lang racket

(require rackunit
         json
         racket/runtime-path
         "../tools/s-checker.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
(define-runtime-path try-source "../examples/bootstrap/try.s")
(define-runtime-path check-tool "../tools/check.rkt")

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
 (check-s-string
  #<<S
program() {
    @safe = 47 > 30
    @bad = "x" > 30
    out none
}
S
  )
 (list "error: operator '>' expects numbers, got string and number"))

(check-equal?
 (check-s-string
  #<<S
Point = Box {
    x = 0
    y = 0
}

program() {
    @p = Point {
        x = 5
    }
    @bad = p.z
    out none
}
S
  )
 (list "10:12: error: Box 'Point' has no field 'z'"))

(check-equal?
 (check-s-string
  #<<S
Point = Box {
    x = 0
}

program() {
    @p = Point {
        x = "bad"
    }
    out none
}
S
  )
 (list "6:16: error: cannot assign string to field 'x' of Box 'Point' with type number"))

(check-equal?
 (check-s-string
  #<<S
use std

Point = Box {
    x = 0
}

program() {
    @items = [
        Point { x = 1 },
    ]
    @item = std.group.at(items, 0)
    @bad = item.z
    out none
}
S
  )
 (list "12:12: error: Box 'Point' has no field 'z'"))

(check-equal?
 (check-s-datum
  '(program
    (out (none))))
 (list "error: 'out' can only be used inside skill"))

(check-equal?
 (check-s-string
  #<<S
program() {
    std.io.println("missing import")
    out none
}
S
  )
 (list "2:5: error: module 'std' is not imported; add 'use std'"))

(check-equal?
 (diagnostics->jsexpr
  (check-s-string/details
   #<<S
program() {
    std.io.println("missing import")
    out none
}
S
   ))
 (hash 'ok #f
       'diagnostics
       (list
        (hash 'level "error"
              'code "std_not_imported"
              'message "module 'std' is not imported; add 'use std'"
              'line 2
              'col 5
              'hint "add `use std` at top level"))))

(define (check-json-cli source)
  (define temp (make-temporary-file "s-check-json-~a.s"))
  (call-with-output-file temp
    (lambda (out) (display source out))
    #:exists 'truncate)
  (define-values (proc out in err)
    (subprocess #f #f #f
                (find-executable-path "racket")
                (path->string check-tool)
                "--json"
                (path->string temp)))
  (close-output-port in)
  (define stdout-text (port->string out))
  (define stderr-text (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (delete-file temp)
  (values stdout-text stderr-text status))

(define-values (ok-json ok-err ok-status)
  (check-json-cli
   #<<S
use std

program() {
    std.io.println("ok")
    out none
}
S
   ))

(check-equal? ok-status 0)
(check-equal? ok-err "")
(check-equal? (string->jsexpr ok-json) (hasheq 'ok #t 'diagnostics '()))

(define-values (bad-json bad-err bad-status)
  (check-json-cli
   #<<S
program() {
    std.io.println("missing import")
    out none
}
S
   ))

(check-equal? bad-status 1)
(check-equal? bad-err "")
(check-equal?
 (string->jsexpr bad-json)
 (hasheq 'ok #f
         'diagnostics
         (list
          (hasheq 'level "error"
                  'code "std_not_imported"
                  'message "module 'std' is not imported; add 'use std'"
                  'line 2
                  'col 5
                  'hint "add `use std` at top level"))))

(check-equal?
 (check-s-string
  #<<S
use std

program() {
    std.io.println("ok")
    out none
}
S
  )
 '())
