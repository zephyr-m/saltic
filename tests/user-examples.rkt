#lang racket

(require rackunit
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "../tools/s-parser.rkt")

(define-runtime-path user-dir "../examples/user")

(define user-files
  (sort
   (filter (lambda (path)
             (regexp-match? #rx"\\.s$" (path->string path)))
           (directory-list user-dir #:build? #t))
   string<?
   #:key path->string))

(check-false (empty? user-files))

(define (imports-std? ast)
  (match ast
    [`(program ,items ...)
     (for/or ([item items])
       (match item
         [`(use "std") #t]
         [_ #f]))]
    [_ #f]))

(define (collect-host-paths node)
  (match node
    [`(path "host" ,parts ...)
     (list (string-join (cons "host" parts) "."))]
    [(list items ...)
     (append-map collect-host-paths items)]
    [_ '()]))

(for ([file user-files])
  (define ast (ast->datum (parse-s-file file)))
  (check-true
   (imports-std? ast)
   (format "~a must import std" file))
  (check-equal?
   (remove-duplicates (collect-host-paths ast) string=?)
   '()
   (format "~a must use std.*, not host.*" file)))
