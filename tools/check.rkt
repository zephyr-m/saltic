#lang racket

(require json
         "s-checker.rkt")

(define args (current-command-line-arguments))

(when (not (or (= (vector-length args) 1)
               (and (= (vector-length args) 2)
                    (equal? (vector-ref args 0) "--json"))))
  (eprintf "usage: racket tools/check.rkt [--json] <file.s>\n")
  (exit 2))

(define json-mode? (and (= (vector-length args) 2)
                        (equal? (vector-ref args 0) "--json")))
(define path (vector-ref args (if json-mode? 1 0)))

(define (write-json-result value)
  (write-json value)
  (newline))

(define (exn->jsexpr exn)
  (hash 'ok #f
        'diagnostics
        (list
         (hash 'level "error"
               'code "tool_error"
               'message (exn-message exn)))))

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (if json-mode?
                       (write-json-result (exn->jsexpr exn))
                       (eprintf "~a\n" (exn-message exn)))
                   (exit 1))])
  (define diagnostics
    (if json-mode?
        (check-s-file/details path)
        (check-s-file path)))
  (cond
    [json-mode?
     (write-json-result (diagnostics->jsexpr diagnostics))
     (unless (diagnostics-empty? diagnostics)
       (exit 1))]
    [(diagnostics-empty? diagnostics)
     (displayln "ok")]
    [else
     (print-diagnostics diagnostics (current-error-port))
     (exit 1)]))
