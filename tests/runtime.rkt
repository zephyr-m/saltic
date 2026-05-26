#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-runtime.rkt")

(define-runtime-path basic-source "../examples/basic.s")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file basic-source)))
 "ok\ntick\ntick\ntick\ntick\ntick\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
skill fail() {
    out error.Boom
}

skill main() {
    @value = fail() rescue |err| {
        std.io.println(err)
        42
    }
    std.io.println(value)
    out none
}
S
      )))
 "error.Boom\n42\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
skill main() {
    @same = 1 == 2
    std.io.println(same)
    out none
}
S
      )))
 "#f\n")
