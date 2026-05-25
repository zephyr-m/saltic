#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-parser.rkt")

(define-runtime-path basic-source "../examples/basic.s")

(define basic-ast (parse-s-file basic-source))
(define basic-datum (ast->datum basic-ast))

(check-match basic-datum
  `(program
     (const "MaxRetries" (number 3))
     (const "AppName" (string "S Language"))
     (enum "Status" "OK" "ERROR" "PENDING")
     . ,_))

(check-true
 (for/or ([item (cdr basic-datum)])
   (match item
     [`(skill "main" ,_ ,_) #t]
     [_ #f])))

(check-true
 (regexp-match?
  #rx"rescue"
  (format "~s" basic-datum)))

(check-true
 (regexp-match?
  #rx"switch"
  (format "~s" basic-datum)))
