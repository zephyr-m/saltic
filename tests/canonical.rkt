#lang racket

(require rackunit
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "../tools/s-parser.rkt")

(define-runtime-path canonical-dir "../examples/canonical")

(define canonical-std-files
  (sort
   (filter (lambda (path)
             (regexp-match? #rx"\\.std\\.s$" (path->string path)))
           (directory-list canonical-dir #:build? #t))
   string<?
   #:key path->string))

(check-false (empty? canonical-std-files))

(define (collect-host-paths node)
  (match node
    [`(path "host" ,parts ...)
     (list (string-join (cons "host" parts) "."))]
    [(list items ...)
     (append-map collect-host-paths items)]
    [_ '()]))

(for ([file canonical-std-files])
  (define ast (ast->datum (parse-s-file file)))
  (check-equal?
   (remove-duplicates (collect-host-paths ast) string=?)
   '()
   (format "~a must use std.*, not host.*" file)))
