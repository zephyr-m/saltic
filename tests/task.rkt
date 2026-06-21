#lang racket

(require json
         rackunit
         racket/runtime-path)

(define-runtime-path task-tool "../tools/task.rkt")
(define-runtime-path finance-task "../tasks/001-finance-balance")
(define-runtime-path energy-task "../tasks/002-energy-day")
(define-runtime-path energy-week-task "../tasks/003-energy-week")
(define-runtime-path render-frame-task "../tasks/004-render-frame")

(define (task-json-cli task-dir)
  (define-values (proc out in err)
    (subprocess #f #f #f
                (find-executable-path "racket")
                (path->string task-tool)
                "--json"
                (path->string task-dir)))
  (close-output-port in)
  (define stdout-text (port->string out))
  (define stderr-text (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (values stdout-text stderr-text status))

(define (check-task task expected-stdout)
  (define-values (stdout stderr status)
    (task-json-cli task))
  (check-equal? status 0)
  (check-equal? stderr "")
  (define result (string->jsexpr stdout))
  (check-equal? (hash-ref result 'ok) #t)
  (check-equal? (hash-ref (hash-ref result 'check) 'ok) #t)
  (check-equal? (hash-ref (hash-ref result 'run) 'stdout) expected-stdout)
  (check-equal? (hash-ref (hash-ref result 'expected) 'ok) #t)
  (check-equal?
   (hash-ref (hash-ref (hash-ref result 'explain) 'explanation) 'entry)
   "program()"))

(check-task finance-task "balance: 78800\n")
(check-task energy-task "end: 5700 Wh\ncharge: 95/2 %\nstatus: SAFE\n")
(check-task energy-week-task "day 1: 8200 Wh\nday 2: 7400 Wh\nday 3: 6600 Wh\nfinal charge: 55 %\nstatus: SAFE\n")
(check-task render-frame-task "frame: 20x10\ncamera: 0,0\nPLAYER visible at 5,4\nLIGHT visible at 2,2\nWALL hidden at 10,4\n")
