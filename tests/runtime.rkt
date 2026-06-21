#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-runtime.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
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
     (run-s-string
      #<<S
program() {
    host.io.println(47 > 30)
    host.io.println(12 < 30)
    host.io.println(12 > 30)
    out none
}
S
      )))
 "#t\n#t\n#f\n")

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
skill balance(income, expenses) {
    out income - expenses
}

program() {
    @income = 112000
    @expenses = 33200
    @total = balance(income, expenses)
    host.io.println("balance: ", total)
    out none
}
S
      )))
 "balance: 78800\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
use std

program() {
    std.io.println("hello, std")
    out none
}
S
      )))
 "hello, std\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
use std

program() {
    std.io.println("lines=", std.str.lines_count("a\nb"))
    std.io.println("len=", std.str.len("abc"))
    std.io.println("join=", std.str.join("a", 1, "b"))
    std.io.println("add=", std.str.add("x", "y"))
    std.io.println("eq=", std.str.eq("s", "s"))
    std.io.println("contains=", std.str.contains("runtime", "time"))
    std.io.println("trim=", std.str.trim("  s  "))
    std.io.println("upper=", std.str.upper("s"))
    std.io.println("lower=", std.str.lower("S"))
    std.io.println("abs=", std.num.abs(0 - 7))
    std.io.println("min=", std.num.min(3, 1, 2))
    std.io.println("max=", std.num.max(3, 1, 2))
    std.io.println("round=", std.num.round(1.6))
    out none
}
S
      )))
 "lines=2\nlen=3\njoin=a1b\nadd=xy\neq=#t\ncontains=#t\ntrim=s\nupper=S\nlower=s\nabs=7\nmin=1\nmax=3\nround=2.0\n")

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
