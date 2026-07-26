#lang racket

(require rackunit
         racket/runtime-path
         racket/string
         "../tools/s-runtime.rkt")

(define-runtime-path lexer-example
  "../examples/bootstrap/s-lexer-word.s")

(define-runtime-path lexer-diagnostics-example
  "../examples/bootstrap/s-lexer-diagnostics.s")

(define-runtime-path lexer-string-example
  "../examples/bootstrap/s-lexer-string-probe.s")

(define result
  (run-s-file lexer-example))

(check-true (s-none? result))

(define diagnostics-output
  (with-output-to-string
    (lambda ()
      (run-s-file lexer-diagnostics-example))))

(check-equal? diagnostics-output
              "diagnostics=1\n")

(define string-output
  (with-output-to-string
    (lambda ()
      (run-s-file lexer-string-example))))

(check-equal? string-output "ERROR_UNTERMINATED_STRING\n")
