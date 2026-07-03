#lang racket

(require rackunit
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "../tools/s-parser.rkt")

(define-runtime-path canonical-dir "../examples/canonical")

(define canonical-core-files
  (sort
   (filter (lambda (path)
             (regexp-match? #rx"\\.core\\.s$" (path->string path)))
           (directory-list canonical-dir #:build? #t))
   string<?
   #:key path->string))

(check-false (empty? canonical-core-files))

(define (collect-host-paths node)
  (match node
    [`(path "host" ,parts ...)
     (list (string-join (cons "host" parts) "."))]
    [(list items ...)
     (append-map collect-host-paths items)]
    [_ '()]))

(for ([file canonical-core-files])
  (define ast (ast->datum (parse-s-file file)))
  (check-equal?
   (remove-duplicates (collect-host-paths ast) string=?)
   '()
   (format "~a must use core.*, not host.*" file)))
