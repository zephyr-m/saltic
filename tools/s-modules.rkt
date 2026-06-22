#lang racket

(require racket/list
         racket/path
         racket/string
         "s-parser.rkt")

(provide load-s-file-datum
         load-s-file-datum/loc)

(define (load-s-file-datum path)
  (expand-file path ast->datum))

(define (load-s-file-datum/loc path)
  (expand-file path ast->datum/loc))

(define (expand-file path ast->datum-proc)
  (define normalized (simplify-path path))
  (define included (make-hash))
  (define items (expand-file-items normalized ast->datum-proc '() included))
  `(program ,@items))

(define (expand-file-items path ast->datum-proc stack included)
  (define normalized (simplify-path path))
  (when (member normalized stack equal?)
    (error 'modules "cyclic import involving ~a" normalized))
  (if (hash-has-key? included normalized)
      '()
      (begin
        (hash-set! included normalized #t)
        (let ([ast (ast->datum-proc (parse-s-file normalized))])
          (match ast
            [`(program ,items ...)
             (apply append
                    (for/list ([item items])
                      (match (strip-loc item)
                        [`(use "std") (list item)]
                        [`(use ,parts ...)
                         (append
                          (list item)
                          (expand-file-items (resolve-module-path normalized parts)
                                             ast->datum-proc
                                             (cons normalized stack)
                                             included))]
                        [_ (list item)])))]
            [_ (error 'modules "expected program AST in ~a" normalized)])))))

(define (strip-loc item)
  (match item
    [`(loc ,_ ,_ ,inner) inner]
    [_ item]))

(define (resolve-module-path source-path parts)
  (define base (or (path-only source-path) (current-directory)))
  (define relative
    (apply build-path
           (append (map string->path (drop-right parts 1))
                   (list (string->path (format "~a.s" (last parts)))))))
  (define resolved (simplify-path (build-path base relative)))
  (unless (file-exists? resolved)
    (error 'modules "module '~a' not found at ~a"
           (string-join parts ".")
           resolved))
  resolved)
