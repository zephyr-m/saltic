#lang racket

(require racket/file
         racket/path
         racket/string
         "s-checker.rkt"
         "s-explainer.rkt"
         "s-runtime.rkt")

(define args (current-command-line-arguments))

(when (not (= (vector-length args) 1))
  (eprintf "usage: racket tools/task.rkt <task-dir>\n")
  (exit 2))

(define task-dir (vector-ref args 0))
(define task-path (simplify-path (string->path task-dir)))
(define task-md (build-path task-path "task.md"))
(define solution (build-path task-path "solution.s"))
(define expected (build-path task-path "expected.txt"))

(define (require-file path label)
  (unless (file-exists? path)
    (eprintf "task error: missing ~a: ~a\n" label path)
    (exit 2)))

(define (print-list title items)
  (printf "~a:\n" title)
  (if (null? items)
      (printf "  - none\n")
      (for ([item items])
        (printf "  - ~a\n" item))))

(require-file task-md "task.md")
(require-file solution "solution.s")

(printf "task: ~a\n" task-path)

(define diagnostics (check-s-file solution))
(if (diagnostics-empty? diagnostics)
    (printf "check: ok\n")
    (begin
      (printf "check: failed\n")
      (print-diagnostics diagnostics)
      (exit 1)))

(define explanation (explain-s-file/details solution))
(define calls (hash-ref explanation 'calls))
(printf "entry: ~a\n" (or (hash-ref explanation 'entry) "none"))
(print-list "skills" (hash-ref explanation 'skills))
(print-list "std calls" (hash-ref calls 'std))
(print-list "host calls" (hash-ref calls 'host))
(print-list "world calls" (hash-ref calls 'world))

(define stdout
  (with-output-to-string
    (lambda ()
      (run-s-file solution))))

(printf "run: ok\n")
(printf "stdout:\n~a" stdout)

(when (file-exists? expected)
  (define expected-text (file->string expected))
  (if (string=? stdout expected-text)
      (printf "expected: ok\n")
      (begin
        (printf "expected: failed\n")
        (printf "expected stdout:\n~a" expected-text)
        (exit 1))))

(printf "task: ok\n")
