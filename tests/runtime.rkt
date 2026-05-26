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
        host.io.println(err)
        42
    }
    host.io.println(value)
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
    host.io.println(same)
    out none
}
S
      )))
 "#f\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string/args
      #<<S
skill main(name) {
    host.io.println("hello, ", name)
    out none
}
S
      (list "S"))))
 "hello, S\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string/args
      #<<S
skill main(path) {
    @text = host.file.read(path)
    @count = host.str.lines_count(text)
    host.io.println(path, ": ", count, " lines")
    out none
}
S
      (list (path->string basic-source)))))
 (format "~a: 39 lines\n" (path->string basic-source)))
