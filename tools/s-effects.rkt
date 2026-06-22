#lang racket

(require racket/string)

(provide effects
         effects->text
         effect-names)

(define effects
  '((host.io.println bootstrap implemented effect "bridge to std.io.println")
    (host.file.read bootstrap implemented effect "bridge to std.file.read_text")
    (host.str.lines_count bootstrap implemented pure "bridge to std.str.lines_count")
    (host.str.len bootstrap implemented pure "bridge to std.str.len")
    (host.str.join bootstrap implemented pure "bridge to std.str.join")
    (host.str.add bootstrap implemented pure "bridge to std.str.add")
    (host.str.eq bootstrap implemented pure "bridge to std.str.eq")
    (host.str.contains bootstrap implemented pure "bridge to std.str.contains")
    (host.str.trim bootstrap implemented pure "bridge to std.str.trim")
    (host.str.upper bootstrap implemented pure "bridge to std.str.upper")
    (host.str.lower bootstrap implemented pure "bridge to std.str.lower")
    (host.math.abs bootstrap implemented pure "bridge to std.num.abs")
    (host.math.min bootstrap implemented pure "bridge to std.num.min")
    (host.math.max bootstrap implemented pure "bridge to std.num.max")
    (host.math.round bootstrap implemented pure "bridge to std.num.round")
    (host.debug.show bootstrap implemented effect "debug-only")
    (std.io.println std stable-v0.1 effect "user-facing print")
    (std.file.read_text std stable-v0.1 effect "user-facing text file read")
    (std.str.lines_count std stable-v0.1 pure "user-facing string count")
    (std.str.len std stable-v0.1 pure "user-facing string length")
    (std.str.join std stable-v0.1 pure "user-facing string join")
    (std.str.add std stable-v0.1 pure "user-facing string concat")
    (std.str.eq std stable-v0.1 pure "user-facing string equality")
    (std.str.contains std stable-v0.1 pure "user-facing string contains")
    (std.str.trim std stable-v0.1 pure "user-facing string trim")
    (std.str.upper std stable-v0.1 pure "user-facing string uppercase")
    (std.str.lower std stable-v0.1 pure "user-facing string lowercase")
    (std.num.abs std stable-v0.1 pure "user-facing numeric abs")
    (std.num.min std stable-v0.1 pure "user-facing numeric min")
    (std.num.max std stable-v0.1 pure "user-facing numeric max")
    (std.num.round std stable-v0.1 pure "user-facing numeric round")
    (std.group.count std stable-v0.1 pure "Group count")
    (std.group.at std stable-v0.1 pure "Group indexed access")
    (world.spawn world protocol-v0 effect "world action trace")
    (world.place world protocol-v0 effect "world action trace")
    (world.move world protocol-v0 effect "world action trace")
    (world.trace world protocol-v0 effect "print world trace")
    (world.trace_text world protocol-v0 pure "return world trace")
    (world.state world protocol-v0 effect "print world state")
    (world.state_text world protocol-v0 pure "return world state")
    (world.replay world protocol-v0 pure "replay world trace")
    (visual.sheet visual protocol-v0 effect "visual trace")
    (visual.grid visual protocol-v0 effect "visual trace")
    (visual.square_bipyramid visual protocol-v0 effect "visual trace")
    (visual.rotate visual protocol-v0 effect "visual trace")
    (visual.present visual protocol-v0 effect "visual trace")
    (visual.trace visual protocol-v0 effect "print visual trace")
    (visual.trace_text visual protocol-v0 pure "return visual trace")))

(define (effect-names)
  (map (lambda (row) (symbol->string (first row))) effects))

(define (effects->text)
  (define rows
    (cons '("effect" "owner" "status" "kind" "decision")
          (for/list ([row effects])
            (match row
              [(list name owner status kind decision)
               (list (symbol->string name)
                     (symbol->string owner)
                     (symbol->string status)
                     (symbol->string kind)
                     decision)]))))
  (define widths
    (for/list ([index (in-range 5)])
      (apply max (map (lambda (row) (string-length (list-ref row index))) rows))))
  (string-append
   (string-join
    (for/list ([row rows])
      (string-join
       (for/list ([cell row]
                  [width widths]
                  [index (in-naturals)])
         (if (= index 4)
             cell
             (pad-right cell width)))
       "  "))
    "\n")
   "\n"))

(define (pad-right text width)
  (string-append text (make-string (- width (string-length text)) #\space)))
