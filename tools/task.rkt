#lang racket

(require json
         racket/file
         racket/path
         racket/string
         "s-checker.rkt"
         "s-explainer.rkt"
         "s-runtime.rkt")

(define args (current-command-line-arguments))

(when (not (or (= (vector-length args) 1)
               (and (= (vector-length args) 2)
                    (equal? (vector-ref args 0) "--json"))))
  (eprintf "usage: racket tools/task.rkt [--json] <task-dir>\n")
  (exit 2))

(define json-mode? (and (= (vector-length args) 2)
                        (equal? (vector-ref args 0) "--json")))
(define task-dir (vector-ref args (if json-mode? 1 0)))
(define task-path (simplify-path (string->path task-dir)))
(define task-md (build-path task-path "task.md"))
(define solution (build-path task-path "solution.s"))
(define expected (build-path task-path "expected.txt"))

(define (write-json-result value)
  (write-json value)
  (newline))

(define (task-diagnostic code message)
  (hash 'level "error"
        'code code
        'message message))

(define (require-file path label)
  (unless (file-exists? path)
    (if json-mode?
        (write-json-result
         (hash 'ok #f
               'task (path->string task-path)
               'diagnostics
               (list (task-diagnostic "task_missing_file"
                                      (format "missing ~a: ~a" label path)))))
        (eprintf "task error: missing ~a: ~a\n" label path))
    (exit 2)))

(define (print-list title items)
  (printf "~a:\n" title)
  (if (null? items)
      (printf "  - none\n")
      (for ([item items])
        (printf "  - ~a\n" item))))

(require-file task-md "task.md")
(require-file solution "solution.s")

(define (run-task-json)
  (define diagnostics (check-s-file/details solution))
  (define check-result (diagnostics->jsexpr diagnostics))
  (if (not (diagnostics-empty? diagnostics))
      (begin
        (write-json-result
         (hash 'ok #f
               'task (path->string task-path)
               'check check-result))
        (exit 1))
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (write-json-result
                          (hash 'ok #f
                                'task (path->string task-path)
                                'check check-result
                                'run
                                (hash 'ok #f
                                      'diagnostics
                                      (list (task-diagnostic "task_run_error"
                                                             (exn-message exn))))))
                         (exit 1))])
        (define explanation (explanation->jsexpr (explain-s-file/details solution)))
        (define stdout
          (with-output-to-string
            (lambda ()
              (run-s-file solution))))
        (define expected-result
          (if (file-exists? expected)
              (let ([expected-text (file->string expected)])
                (hash 'present #t
                      'ok (string=? stdout expected-text)
                      'expected expected-text
                      'actual stdout))
              (hash 'present #f)))
        (define ok? (and (hash-ref check-result 'ok)
                         (hash-ref explanation 'ok)
                         (hash-ref expected-result 'ok #t)))
        (write-json-result
         (hash 'ok ok?
               'task (path->string task-path)
               'check check-result
               'explain explanation
               'run (hash 'ok #t 'stdout stdout)
               'expected expected-result))
        (unless ok?
          (exit 1)))))

(when json-mode?
  (run-task-json)
  (exit 0))

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
(print-list "core calls" (hash-ref calls 'core))
(print-list "host calls" (hash-ref calls 'host))
(print-list "world calls" (hash-ref calls 'world))
(print-list "visual calls" (hash-ref calls 'visual))
(print-list "ui calls" (hash-ref calls 'ui))

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
