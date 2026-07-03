#lang racket

(require rackunit
         racket/runtime-path
         "../tools/s-runtime.rkt")

(define-runtime-path basic-source "../examples/bootstrap/basic.s")
(define-runtime-path tiny-vm-source "../examples/bootstrap/s-vm-tiny.s")
(define-runtime-path step-ab-source "../examples/bootstrap/s-vm-step-ab.s")
(define-runtime-path step-c-source "../examples/bootstrap/s-vm-step-c.s")
(define-runtime-path step-d-source "../examples/bootstrap/s-vm-step-d.s")
(define-runtime-path step-drum-source "../examples/bootstrap/s-vm-step-drum.s")
(define-runtime-path step-switch-source "../examples/bootstrap/s-vm-step-switch.s")
(define-runtime-path step-rescue-source "../examples/bootstrap/s-vm-step-rescue.s")
(define-runtime-path step-call-source "../examples/bootstrap/s-vm-step-call.s")
(define-runtime-path step-boundary-source "../examples/bootstrap/s-vm-step-boundary.s")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file basic-source)))
 "ok\ntick\ntick\ntick\ntick\ntick\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file tiny-vm-source)))
 "tiny-vm result=10\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-ab-source)))
 "step-ab result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-c-source)))
 "step-c result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-d-source)))
 "step-d result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-drum-source)))
 "step-drum result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-switch-source)))
 "step-switch result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-rescue-source)))
 "step-rescue result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-call-source)))
 "step-call result=yes\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-file step-boundary-source)))
 "boundary result=42\nstep-boundary result=yes\n")

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
 "no\n")

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
 "yes\nyes\nno\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
program() {
    host.io.println(yes)
    host.io.println(no)
    out none
}
S
      )))
 "yes\nno\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
Point = Box {
    x = 0
    y = 0
}

program() {
    @p = Point {
        x = 5
    }
    host.io.println(p.x, ",", p.y)
    out none
}
S
      )))
 "5,0\n")

(check-equal?
 (s-value->jsexpr
  (run-s-string
   #<<S
Kind = enum {
    POINT,
}

Point = Box {
    kind = Kind.POINT
    x = 0
    y = 0
}

program() {
    out [
        Point { x = 5 y = 7 },
    ]
}
S
   ))
 (list (hash 'kind "POINT" 'x 5 'y 7)))

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
use core

Point = Box {
    x = 0
    y = 0
}

program() {
    @json = core.json.encode([
        Point { x = 5 y = 7 },
    ])
    core.io.println(json)
    out none
}
S
      )))
 "[{\"x\":5,\"y\":7}]\n")

(let ([temp (make-temporary-file "s-write-text-~a.txt")])
  (run-s-string/args
   #<<S
use core

program(path) {
    core.file.write_text(path, "written by S")
    out none
}
S
   (list (path->string temp)))
  (check-equal? (file->string temp) "written by S")
  (delete-file temp))

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
use core

program() {
    @items = ["a", "b", "c"]
    @index = 0
    drum (core.group.count(items)) {
        host.io.println(core.group.at(items, index))
        index = index + 1
    }
    out none
}
S
      )))
 "a\nb\nc\n")

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
use core

program() {
    core.io.println("hello, std")
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
use core

program() {
    core.io.println("lines=", core.str.lines_count("a\nb"))
    core.io.println("lines-empty=", core.str.lines_count(""))
    core.io.println("lines-one=", core.str.lines_count("a"))
    core.io.println("lines-trailing=", core.str.lines_count("a\n"))
    @line_group = core.str.lines("a\nb")
    @parts = core.str.split("expense 2026-06-22 12000 food", " ")
    core.io.println("len=", core.str.len("abc"))
    core.io.println("at=", core.str.at("abc", 1))
    core.io.println("slice=", core.str.slice("abcdef", 1, 4))
    core.io.println("join=", core.str.join("a", 1, "b"))
    core.io.println("add=", core.str.add("x", "y"))
    core.io.println("eq=", core.str.eq("s", "s"))
    core.io.println("empty=", core.str.is_empty(""))
    core.io.println("not-empty=", core.str.is_empty("s"))
    core.io.println("starts=", core.str.starts_with("runtime", "run"))
    core.io.println("starts-miss=", core.str.starts_with("runtime", "time"))
    core.io.println("ends=", core.str.ends_with("runtime", "time"))
    core.io.println("ends-miss=", core.str.ends_with("runtime", "run"))
    core.io.println("contains=", core.str.contains("runtime", "time"))
    core.io.println("contains-empty=", core.str.contains("runtime", ""))
    core.io.println("contains-miss=", core.str.contains("runtime", "room"))
    core.io.println("trim=", core.str.trim("  s  "))
    core.io.println("upper=", core.str.upper("s"))
    core.io.println("lower=", core.str.lower("S"))
    core.io.println("line0=", core.group.at(line_group, 0))
    core.io.println("part2=", core.group.at(parts, 2))
    core.io.println("parse=", core.num.parse("42"))
    core.io.println("abs=", core.num.abs(0 - 7))
    core.io.println("min=", core.num.min(3, 1, 2))
    core.io.println("max=", core.num.max(3, 1, 2))
    core.io.println("round=", core.num.round(1.6))
    out none
}
S
      )))
 "lines=2\nlines-empty=0\nlines-one=1\nlines-trailing=1\nlen=3\nat=b\nslice=bcd\njoin=a1b\nadd=xy\neq=yes\nempty=yes\nnot-empty=no\nstarts=yes\nstarts-miss=no\nends=yes\nends-miss=no\ncontains=yes\ncontains-empty=yes\ncontains-miss=no\ntrim=s\nupper=S\nlower=s\nline0=a\npart2=12000\nparse=42\nabs=7\nmin=1\nmax=3\nround=2.0\n")

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
use core

program() {
    @box = world.spawn("box")
    world.emit(box, "place", 10, 20)
    world.emit(box, "move", 5, 0)
    world.step()

    core.io.println(world.state_text())
    out none
}
S
      )))
 "#1 box at 15 20\n\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
use core

Op = enum {
    NOP,
    PUSH,
    ADD,
    RETURN,
}

Instr = Box {
    op = Op.NOP
    value = 0
}

skill run_tiny(bytecode) {
    @index = 0
    @stack0 = 0
    @stack1 = 0
    @sp = 0
    @result = 0
    @returned = no

    drum (core.group.count(bytecode)) {
        @instr = core.group.at(bytecode, index)

        (returned == no) {
            (instr.op == Op.PUSH) {
                (sp == 0) {
                    stack0 = instr.value
                }
                (sp == 1) {
                    stack1 = instr.value
                }
                sp = sp + 1
            }

            (instr.op == Op.ADD) {
                @sum = stack0 + stack1
                stack0 = sum
                sp = 1
            }

            (instr.op == Op.RETURN) {
                result = stack0
                returned = yes
            }
        }

        index = index + 1
    }

    out result
}

program() {
    @bytecode = [
        Instr { op = Op.PUSH value = 2 },
        Instr { op = Op.PUSH value = 3 },
        Instr { op = Op.ADD },
        Instr { op = Op.RETURN },
    ]

    @result = run_tiny(bytecode)
    core.io.println("tiny-vm result=", result)
    out result
}
S
      )))
 "tiny-vm result=5\n")

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
 "yes\n#1 box at 15 20\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
program() {
    @box = world.spawn("box")
    world.emit(box, "place", 10, 20)
    world.emit(box, "move", 5, 0)
    world.step()
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
Crystal = Box {
    name = "crystal"
    height = 4
    base = 2
    color = "cyan"
    spin = 1
}

program() {
    @crystal = Crystal {}
    visual.sheet("engineering")
    visual.grid(24)
    visual.square_bipyramid(crystal.name, crystal.height, crystal.base, crystal.color)
    visual.rotate(crystal.name, "y", crystal.spin)
    visual.present()
    visual.trace()
    out none
}
S
      )))
 "sheet engineering\ngrid 24\nshape square_bipyramid crystal height 4 base 2 color cyan\nmotion rotate crystal y 1\npresent\n")

(check-equal?
 (with-output-to-string
   (lambda ()
     (run-s-string
      #<<S
program() {
    ui.panel("family-ledger")
    ui.text("Family ledger")
    ui.field("amount", "Amount")
    ui.button("add", "Add")
    ui.value("free", 151000)
    ui.present()
    ui.trace()
    out none
}
S
      )))
 "panel family-ledger\ntext Family ledger\nfield amount label Amount\nbutton add label Add\nvalue free 151000\npresent\n")
