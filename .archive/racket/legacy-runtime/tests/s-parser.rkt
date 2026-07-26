#lang racket

(require rackunit
         racket/file
         racket/runtime-path
         racket/string
         "../racket/bootstrap/runtime.rkt")

(define-runtime-path parser-probe
  "../examples/bootstrap/s-parser-probe.s")

(define-runtime-path checker-probe
  "../examples/bootstrap/s-checker-probe.s")

(define-runtime-path checker-call-probe
  "../examples/bootstrap/s-checker-call-probe.s")

(define-runtime-path skill-probe
  "../examples/bootstrap/s-skill-probe.s")

(define-runtime-path module-probe
  "../examples/bootstrap/s-module-probe.s")

(define-runtime-path checker-arg-probe
  "../examples/bootstrap/s-checker-arg-probe.s")

(define-runtime-path checker-duplicate-probe
  "../examples/bootstrap/s-checker-duplicate-probe.s")

(define-runtime-path checker-call-contract-probe
  "../examples/bootstrap/s-checker-call-contract-probe.s")

(define-runtime-path parser-order-probe
  "../examples/bootstrap/s-parser-order-probe.s")

(define-runtime-path compiler-probe
  "../examples/bootstrap/s-compiler-probe.s")

(define-runtime-path emitter-probe
  "../examples/bootstrap/s-emitter-probe.s")

(define-runtime-path compiler-check-probe
  "../examples/bootstrap/s-compiler-check-probe.s")

(define-runtime-path runtime-ir-probe
  "../examples/bootstrap/s-runtime-ir-probe.s")

(define-runtime-path assignment-check-probe
  "../examples/bootstrap/s-assignment-check-probe.s")

(define-runtime-path compiler-compare-probe
  "../examples/bootstrap/s-compiler-compare-probe.s")

(define-runtime-path compiler-import-probe
  "../examples/bootstrap/s-compiler-import-probe.s")

(define-runtime-path compiler-trace-probe
  "../examples/bootstrap/s-compiler-trace-probe.s")

(define (run-probe body)
  (define path (make-temporary-file "s-parser-probe-~a.s"))
  (display-to-file
   (string-append
    "use s.make.compiler.lexer.scanner\n"
    "use s.make.compiler.syntax.parser\n\n"
    "program() {\n"
    "    @scanned = scanner_scan(\"program() { "
    body
    " }\", \"probe.s\")\n"
    "    @parsed = parser_parse_program(scanned.tokens, \"probe.s\")\n"
    "    core.io.println(\"body=\", core.group.count(parsed.ast.body))\n"
    "    out none\n"
    "}\n")
   path
   #:exists 'replace)
  (with-output-to-string (lambda () (run-s-file path))))

(define output
  (with-output-to-string
    (lambda ()
      (run-s-file parser-probe))))

(check-equal? output "ast=PROGRAM\nbody=2\ndiagnostics=0\n")

(define checker-output
  (with-output-to-string
    (lambda ()
      (run-s-file checker-probe))))

(check-equal? checker-output "diagnostics=1\nunknown_name\nlocation=1:17\n")

(define checker-call-output
  (with-output-to-string
    (lambda ()
      (run-s-file checker-call-probe))))

(check-equal? checker-call-output "diagnostics=0\n")

(define skill-output
  (with-output-to-string
    (lambda ()
      (run-s-file skill-probe))))

(check-equal? skill-output "SKILL\nadd\nparams=2\nbody=1\n")

(define module-output
  (with-output-to-string
    (lambda ()
      (run-s-file module-probe))))

(check-equal? module-output "PROGRAM\n1\n1\n0\n")

(define checker-arg-output
  (with-output-to-string
    (lambda ()
      (run-s-file checker-arg-probe))))

(check-equal? checker-arg-output "diagnostics=1\n")

(define checker-duplicate-output
  (with-output-to-string
    (lambda ()
      (run-s-file checker-duplicate-probe))))

(check-equal? checker-duplicate-output
              "diagnostics=2\nduplicate_parameter\nduplicate_skill\n")

(define checker-call-contract-output
  (with-output-to-string
    (lambda ()
      (run-s-file checker-call-contract-probe))))

(check-equal? checker-call-contract-output
              "diagnostics=2\nwrong_arity\nunknown_call\n")

(define parser-order-output
  (with-output-to-string
    (lambda ()
      (run-s-file parser-order-probe))))

(check-equal? parser-order-output
              "diagnostics=1\ndeclaration_after_program\n")

(define compiler-output
  (with-output-to-string
    (lambda ()
      (run-s-file compiler-probe))))

(check-equal? compiler-output
              "diagnostics=0\nir=2\nast=PROGRAM\nbroken=unknown_symbol\nbroken_ir=0\n")

(define emitter-output
  (with-output-to-string
    (lambda ()
      (run-s-file emitter-probe))))

(check-equal? emitter-output
              "diagnostics=0\ninstructions=2\nSKILL/add\nOUT/out\n")

(define compiler-check-output
  (with-output-to-string
    (lambda ()
      (run-s-file compiler-check-probe))))

(check-equal? compiler-check-output
              "diagnostics=1\ncode=unknown_name\nir=0\n")

(define runtime-ir-output
  (with-output-to-string
    (lambda ()
      (run-s-file runtime-ir-probe))))

(check-equal? runtime-ir-output
              "ok=yes\nvalue=7\nsteps=1\n")

(define assignment-check-output
  (with-output-to-string
    (lambda ()
      (run-s-file assignment-check-probe))))

(check-equal? assignment-check-output
              "parsed=PROGRAM\nbody=2\ndiagnostics=0\nfirst=ASSIGN/answer\nsecond=OUT/out\n")

(define compiler-compare-output
  (with-output-to-string
    (lambda ()
      (run-s-file compiler-compare-probe))))

(check-equal? compiler-compare-output
              "compiled=0\nstages=0/0/0\nstaged=0\ndirect=0\n")

(define compiler-import-output
  (with-output-to-string
    (lambda ()
      (run-s-file compiler-import-probe))))

(check-equal? compiler-import-output
              "compiled=1\ncheck_only=0\n")

(define compiler-trace-output
  (with-output-to-string
    (lambda ()
      (run-s-file compiler-trace-probe))))

(check-equal? compiler-trace-output
              "trace.length=36\ntrace.at=a\ntrace.answer=n\ntrace.diagnostics=0\n")

(check-equal? (run-probe "@value = 42") "body=1\n")
(check-equal? (run-probe "out value") "body=1\n")
(check-equal? (run-probe "out name()") "body=1\n")
(check-equal? (run-probe "out core.str.len(text)") "body=1\n")
