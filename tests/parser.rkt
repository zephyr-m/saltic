#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-parser.rkt")

(define-runtime-path basic-source "../examples/basic.s")
(define-runtime-path try-source "../examples/try.s")

(define basic-ast (parse-s-file basic-source))
(define basic-datum (ast->datum basic-ast))
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
