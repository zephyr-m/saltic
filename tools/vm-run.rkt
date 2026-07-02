#lang racket

(require "s-checker.rkt"
         "s-vm.rkt")

(define args (current-command-line-arguments))

(when (not (or (= (vector-length args) 1)
               (and (= (vector-length args) 2)
                    (equal? (vector-ref args 0) "--bytecode"))))
  (eprintf "usage: racket tools/vm-run.rkt [--bytecode] <file.s>\n")
  (exit 2))

(define bytecode-mode? (and (= (vector-length args) 2)
                            (equal? (vector-ref args 0) "--bytecode")))
(define path (vector-ref args (if bytecode-mode? 1 0)))

(with-handlers ([exn:fail?
                 (lambda (exn)
                   (eprintf "~a\n" (exn-message exn))
                   (exit 1))])
  (define diagnostics (check-s-file path))
  (unless (diagnostics-empty? diagnostics)
    (print-diagnostics diagnostics (current-error-port))
    (exit 1))
  (if bytecode-mode?
      (display (vm-bytecode->text (compile-s-file/vm path)))
      (display (vm-run-result-output (run-s-file/vm path)))))
