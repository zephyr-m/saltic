#lang racket

(require rackunit
         json
         racket/runtime-path
         "../tools/s-explainer.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
(define-runtime-path world-source "../examples/bootstrap/world-basic.s")
(define-runtime-path std-source "../examples/canonical/report-generator.core.s")
(define-runtime-path explain-tool "../tools/explain.rkt")

(define basic-explanation (explain-s-file basic-source))
(define world-explanation (explain-s-file world-source))
(define std-explanation (explain-s-file std-source))

(check-true (regexp-match? #rx"top-level: 2 constants, 1 enums, 2 skills, 1 program" basic-explanation))
(check-true (regexp-match? #rx"program\\(\\)" basic-explanation))
(check-true (regexp-match? #rx"add\\(a, b\\)" basic-explanation))
(check-true (regexp-match? #rx"host.io.println" basic-explanation))

(check-true (regexp-match? #rx"world.spawn" world-explanation))
(check-true (regexp-match? #rx"world.place" world-explanation))
(check-true (regexp-match? #rx"world.move" world-explanation))
(check-true (regexp-match? #rx"world.trace" world-explanation))

(check-true (regexp-match? #rx"imports:\n  - core" std-explanation))
(check-true (regexp-match? #rx"core.io.println" std-explanation))
(check-true (regexp-match? #rx"core.file.read_text" std-explanation))

(define std-details (explain-s-file/details std-source))

(check-equal? (hash-ref std-details 'imports) (list "core"))
(check-equal? (hash-ref std-details 'entry) "program(path, needle)")
(check-equal? (hash-ref (hash-ref std-details 'top-level) 'skills) 4)
(check-equal? (hash-ref (hash-ref std-details 'calls) 'host) '())
(check-not-false (member "core.io.println" (hash-ref (hash-ref std-details 'calls) 'core)))

(define visual-details
  (explain-s-string/details
   #<<S
program() {
    visual.sheet("engineering")
    visual.present()
    out none
}
S
   ))

(check-not-false (member "visual.sheet" (hash-ref (hash-ref visual-details 'calls) 'visual)))
(check-not-false (member "visual.present" (hash-ref (hash-ref visual-details 'calls) 'visual)))
(check-not-false (member "core.file.read_text" (hash-ref (hash-ref std-details 'calls) 'core)))

(define ui-details
  (explain-s-string/details
   #<<S
program() {
    ui.panel("family-ledger")
    ui.present()
    out none
}
S
   ))

(check-not-false (member "ui.panel" (hash-ref (hash-ref ui-details 'calls) 'ui)))
(check-not-false (member "ui.present" (hash-ref (hash-ref ui-details 'calls) 'ui)))

(define (explain-json-cli file)
  (define-values (proc out in err)
    (subprocess #f #f #f
                (find-executable-path "racket")
                (path->string explain-tool)
                "--json"
                (path->string file)))
  (close-output-port in)
  (define stdout-text (port->string out))
  (define stderr-text (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (values stdout-text stderr-text status))

(define-values (std-json std-err std-status)
  (explain-json-cli std-source))

(check-equal? std-status 0)
(check-equal? std-err "")

(define parsed-std-json (string->jsexpr std-json))
(check-equal? (hash-ref parsed-std-json 'ok) #t)
(check-equal? (hash-ref (hash-ref parsed-std-json 'explanation) 'imports) (list "core"))
(check-equal? (hash-ref (hash-ref parsed-std-json 'explanation) 'entry) "program(path, needle)")
