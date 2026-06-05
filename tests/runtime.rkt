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

program() {
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
program() {
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
program(name) {
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
program(path) {
    @text = host.file.read(path)
    @count = host.str.lines_count(text)
    host.io.println(path, ": ", count, " lines")
    out none
}
S
      (list (path->string basic-source)))))
 (format "~a: 39 lines\n" (path->string basic-source)))

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)
    world.trace()
    world.state()
    out none
}
S
      )))
 "spawn #1 box\nplace #1 10 20\nmove #1 5 0\n#1 box at 15 20\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
program() {
    @box = world.spawn("box")
    world.place(box, 10, 20)
    world.move(box, 5, 0)
    @trace = world.trace_text()
    @state = world.state_text()
    @replayed = world.replay(trace)
    host.io.println(state == replayed)
    host.io.println(host.str.trim(replayed))
    out none
}
S
      )))
 "#t\n#1 box at 15 20\n")
