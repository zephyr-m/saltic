#lang racket

(require racket/string
         "s-modules.rkt"
         "s-parser.rkt")

(provide run-s-file
         run-s-file/args
         run-s-string
         run-s-string/args
         run-s-datum
         run-s-datum/args
         s-none?
         s-error?
         s-enum?
         s-world-ref?)

(struct runtime (constants enums boxes skills entry world visual) #:transparent)
(struct world-state (next-id objects trace) #:transparent)
(struct world-object (kind x y) #:transparent)
(struct visual-state (trace) #:transparent)
(struct env (vars parent) #:transparent)
(struct s-none () #:transparent)
(struct s-error (name) #:transparent)
(struct s-enum (enum variant) #:transparent)
(struct s-box (name fields) #:transparent)
(struct s-group (items) #:transparent)
(struct s-world-ref (id) #:transparent)
(struct return-signal (value) #:transparent)

(define none-value (s-none))
(define missing-value (gensym 'missing))

(define (run-s-file path [out (current-output-port)])
  (run-s-file/args path '() out))

(define (run-s-file/args path program-args [out (current-output-port)])
  (run-s-datum/args (load-s-file-datum path) program-args out))

(define (run-s-string source [out (current-output-port)])
  (run-s-string/args source '() out))

(define (run-s-string/args source program-args [out (current-output-port)])
  (run-s-datum/args (ast->datum (parse-s-string source)) program-args out))

(define (run-s-datum ast [out (current-output-port)])
  (run-s-datum/args ast '() out))

(define (run-s-datum/args ast program-args [out (current-output-port)])
  (define rt (build-runtime ast))
  (unless (runtime-entry rt)
    (runtime-error "missing program entry"))
  (call-entry rt program-args out))

(define (build-runtime ast)
  (match ast
    [`(program ,items ...)
     (define constants (make-hash))
     (define enums (make-hash))
     (define boxes (make-hash))
     (define skills (make-hash))
     (define entry #f)
     (define world (make-world-state))
     (define visual (make-visual-state))
     (define rt (runtime constants enums boxes skills #f world visual))
     (for ([item items])
       (match item
         [`(const ,name ,value)
          (hash-set! constants name (eval-expr rt (make-root-env) value (current-output-port)))]
         [`(use ,_ ...) (void)]
         [`(box ,name ,fields ...)
          (hash-set! boxes name fields)]
         [`(enum ,name ,variants ...)
          (hash-set! enums name variants)]
         [`(entry ,params ,body)
          (set! entry (list params body))]
         [`(skill ,name ,params ,body)
          (hash-set! skills name (list params body))]
         [_ (runtime-error "unsupported top-level item: ~s" item)]))
     (runtime constants enums boxes skills entry world visual)]
    [_ (runtime-error "expected program AST")]))

(define (make-root-env)
  (env (make-hash) #f))

(define (make-world-state)
  (world-state (box 1) (make-hash) (box '())))

(define (make-visual-state)
  (visual-state (box '())))

(define (make-child-env parent)
  (env (make-hash) parent))

(define (env-define! scope name value)
  (hash-set! (env-vars scope) name value))

(define (env-find scope name)
  (cond
    [(not scope) #f]
    [(hash-has-key? (env-vars scope) name) scope]
    [else (env-find (env-parent scope) name)]))

(define (env-ref scope name)
  (define owner (env-find scope name))
  (if owner
      (hash-ref (env-vars owner) name)
      missing-value))

(define (env-set! scope name value)
  (define owner (env-find scope name))
  (unless owner
    (runtime-error "variable '~a' is not declared" name))
  (hash-set! (env-vars owner) name value))

(define (call-skill rt name args out)
  (match (hash-ref (runtime-skills rt) name #f)
    [(list params body)
     (unless (= (length params) (length args))
       (runtime-error "skill '~a' expected ~a args, got ~a"
                      name
                      (length params)
                      (length args)))
     (define scope (make-root-env))
     (for ([param params]
           [arg args])
       (env-define! scope param arg))
     (with-handlers ([return-signal?
                      (lambda (signal) (return-signal-value signal))])
       (eval-block rt scope body out)
       none-value)]
    [_ (runtime-error "unknown skill '~a'" name)]))

(define (call-entry rt args out)
  (match (runtime-entry rt)
    [(list params body)
     (unless (= (length params) (length args))
       (runtime-error "program expected ~a args, got ~a"
                      (length params)
                      (length args)))
     (define scope (make-root-env))
     (for ([param params]
           [arg args])
       (env-define! scope param arg))
     (with-handlers ([return-signal?
                      (lambda (signal) (return-signal-value signal))])
       (eval-block rt scope body out)
       none-value)]
    [_ (runtime-error "missing program entry")]))

(define (eval-block rt scope block out)
  (match block
    [`(block ,items ...)
     (define last-value none-value)
     (for ([item items])
       (set! last-value (eval-stmt rt scope item out)))
     last-value]
    [_ (runtime-error "expected block AST")]))

(define (eval-stmt rt scope stmt out)
  (match stmt
    [`(var ,name ,value)
     (define evaluated (eval-expr rt scope value out))
     (env-define! scope name evaluated)
     none-value]
    [`(assign ,name ,value)
     (env-set! scope name (eval-expr rt scope value out))
     none-value]
    [`(out ,value)
     (raise (return-signal (eval-expr rt scope value out)))]
    [`(expr ,value)
     (eval-expr rt scope value out)]
    [`(if ,test ,body)
     (if (truthy? (eval-expr rt scope test out))
         (eval-block rt (make-child-env scope) body out)
         none-value)]
    [`(switch ,value ,cases ...)
     (eval-switch rt scope (eval-expr rt scope value out) cases out)]
    [`(drum ,count ,body)
     (define n (eval-expr rt scope count out))
     (unless (and (number? n) (integer? n) (not (negative? n)))
       (runtime-error "drum count must be a non-negative integer"))
     (for ([_ (in-range n)])
       (eval-block rt (make-child-env scope) body out))
     none-value]
    [_ (runtime-error "unsupported statement: ~s" stmt)]))

(define (eval-switch rt scope value cases out)
  (let loop ([remaining cases])
    (match remaining
      ['() none-value]
      [(cons `(case ,tag ,body) rest)
       (if (case-matches? value tag)
           (eval-expr rt scope body out)
           (loop rest))]
      [_ (runtime-error "malformed switch case")])))

(define (eval-expr rt scope expr out)
  (match expr
    [`(number ,value) value]
    [`(string ,value) value]
    [`(answer "yes") #t]
    [`(answer "no") #f]
    [`(none) none-value]
    [`(enum-value ,name) (s-enum #f name)]
    [`(group ,items ...)
     (s-group
      (for/list ([item items])
        (eval-expr rt scope item out)))]
    [`(box-new ,name ,fields ...)
     (eval-box-new rt scope name fields out)]
    [`(path ,parts ...) (eval-path rt scope parts)]
    [`(call ,callee ,args ...)
     (define evaluated-args
       (for/list ([arg args])
         (eval-expr rt scope arg out)))
     (eval-call rt scope callee evaluated-args out)]
    [`(binary ,op ,left ,right)
     (eval-binary op
                  (eval-expr rt scope left out)
                  (eval-expr rt scope right out))]
    [`(rescue ,value ,err ,body)
     (define result (eval-expr rt scope value out))
     (if (s-error? result)
         (let ([rescue-scope (make-child-env scope)])
           (env-define! rescue-scope err result)
           (eval-block rt rescue-scope body out))
         result)]
    [_ (runtime-error "unsupported expression: ~s" expr)]))

(define (eval-path rt scope parts)
  (match parts
    [(list name)
     (cond
       [(not (eq? (env-ref scope name) missing-value))
        (env-ref scope name)]
       [(not (eq? (hash-ref (runtime-constants rt) name missing-value) missing-value))
        (hash-ref (runtime-constants rt) name)]
       [(hash-has-key? (runtime-skills rt) name) `(skill-ref ,name)]
       [(hash-has-key? (runtime-enums rt) name) `(enum-ref ,name)]
       [(equal? name "error") `(error-ref)]
       [else (runtime-error "unknown name '~a'" name)])]
    [(list enum-name variant)
     (cond
       [(hash-has-key? (runtime-enums rt) enum-name)
        (unless (member variant (hash-ref (runtime-enums rt) enum-name))
          (runtime-error "enum '~a' has no variant '~a'" enum-name variant))
        (s-enum enum-name variant)]
       [(equal? enum-name "error")
        (s-error variant)]
       [(not (eq? (env-ref scope enum-name) missing-value))
        (box-field-ref (env-ref scope enum-name) (list variant))]
       [else
        `(path ,@parts)])]
    [(list name fields ...)
     (cond
       [(member name '("host" "std" "world" "visual")) `(path ,@parts)]
       [(not (eq? (env-ref scope name) missing-value))
        (box-field-ref (env-ref scope name) fields)]
       [(not (eq? (hash-ref (runtime-constants rt) name missing-value) missing-value))
        (box-field-ref (hash-ref (runtime-constants rt) name) fields)]
       [else `(path ,@parts)])]
    [(list "host" _ ...) `(path ,@parts)]
    [(list "std" _ ...) `(path ,@parts)]
    [(list "world" _ ...) `(path ,@parts)]
    [(list "visual" _ ...) `(path ,@parts)]
    [_ `(path ,@parts)]))

(define (eval-box-new rt scope name fields out)
  (define defaults (hash-ref (runtime-boxes rt) name #f))
  (unless defaults
    (runtime-error "unknown Box '~a'" name))
  (define values (make-hash))
  (for ([field defaults])
    (match field
      [`(field ,field-name ,value)
       (hash-set! values field-name (eval-expr rt scope value out))]
      [_ (runtime-error "malformed Box field in '~a'" name)]))
  (for ([field fields])
    (match field
      [`(field ,field-name ,value)
       (unless (hash-has-key? values field-name)
         (runtime-error "Box '~a' has no field '~a'" name field-name))
       (hash-set! values field-name (eval-expr rt scope value out))]
      [_ (runtime-error "malformed Box literal field in '~a'" name)]))
  (s-box name values))

(define (box-field-ref value fields)
  (let loop ([current value] [remaining fields])
    (cond
      [(null? remaining) current]
      [(s-box? current)
       (define field-name (first remaining))
       (unless (hash-has-key? (s-box-fields current) field-name)
         (runtime-error "Box '~a' has no field '~a'" (s-box-name current) field-name))
       (loop (hash-ref (s-box-fields current) field-name) (rest remaining))]
      [else
       (runtime-error "cannot access field '~a' on ~a"
                      (first remaining)
                      (value->string current))])))

(define (eval-call rt scope callee args out)
  (match callee
    [`(path "host" "io" "println")
     (fprintf out "~a\n" (string-join (map value->string args) ""))
     none-value]
    [`(path "host" "file" "read")
     (expect-arg-count "host.file.read" args 1)
     (define path (first args))
     (unless (string? path)
       (runtime-error "host.file.read expects string path"))
     (file->string path)]
    [`(path "host" "str" "lines_count")
     (expect-arg-count "host.str.lines_count" args 1)
     (define text (first args))
     (unless (string? text)
       (runtime-error "host.str.lines_count expects string"))
     (count-lines text)]
    [`(path "host" "str" "len")
     (expect-arg-count "host.str.len" args 1)
     (define text (first args))
     (unless (string? text)
       (runtime-error "host.str.len expects string"))
     (string-length text)]
    [`(path "host" "str" "join")
     (string-join (map value->string args) "")]
    [`(path "host" "str" "add")
     (string-join (map value->string args) "")]
    [`(path "host" "str" "eq")
     (expect-arg-count "host.str.eq" args 2)
     (equal? (first args) (second args))]
    [`(path "host" "str" "contains")
     (expect-arg-count "host.str.contains" args 2)
     (define text (first args))
     (define needle (second args))
     (unless (and (string? text) (string? needle))
       (runtime-error "host.str.contains expects strings"))
     (not (not (string-contains? text needle)))]
    [`(path "host" "str" "trim")
     (expect-arg-count "host.str.trim" args 1)
     (define text (first args))
     (unless (string? text)
       (runtime-error "host.str.trim expects string"))
     (string-trim text)]
    [`(path "host" "str" "upper")
     (expect-arg-count "host.str.upper" args 1)
     (define text (first args))
     (unless (string? text)
       (runtime-error "host.str.upper expects string"))
     (string-upcase text)]
    [`(path "host" "str" "lower")
     (expect-arg-count "host.str.lower" args 1)
     (define text (first args))
     (unless (string? text)
       (runtime-error "host.str.lower expects string"))
     (string-downcase text)]
    [`(path "host" "math" "abs")
     (expect-arg-count "host.math.abs" args 1)
     (define value (first args))
     (unless (number? value)
       (runtime-error "host.math.abs expects number"))
     (abs value)]
    [`(path "host" "math" "min")
     (unless (andmap number? args)
       (runtime-error "host.math.min expects numbers"))
     (apply min args)]
    [`(path "host" "math" "max")
     (unless (andmap number? args)
       (runtime-error "host.math.max expects numbers"))
     (apply max args)]
    [`(path "host" "math" "round")
     (expect-arg-count "host.math.round" args 1)
     (define value (first args))
     (unless (number? value)
       (runtime-error "host.math.round expects number"))
     (round value)]
    [`(path "host" "debug" "show")
     (for ([arg args])
       (fprintf out "~s\n" arg))
     none-value]
    [`(path "std" "io" "println")
     (eval-call rt scope `(path "host" "io" "println") args out)]
    [`(path "std" "file" "read_text")
     (eval-call rt scope `(path "host" "file" "read") args out)]
    [`(path "std" "str" "lines_count")
     (eval-call rt scope `(path "host" "str" "lines_count") args out)]
    [`(path "std" "str" "len")
     (eval-call rt scope `(path "host" "str" "len") args out)]
    [`(path "std" "str" "join")
     (eval-call rt scope `(path "host" "str" "join") args out)]
    [`(path "std" "str" "add")
     (eval-call rt scope `(path "host" "str" "add") args out)]
    [`(path "std" "str" "eq")
     (eval-call rt scope `(path "host" "str" "eq") args out)]
    [`(path "std" "str" "contains")
     (eval-call rt scope `(path "host" "str" "contains") args out)]
    [`(path "std" "str" "trim")
     (eval-call rt scope `(path "host" "str" "trim") args out)]
    [`(path "std" "str" "upper")
     (eval-call rt scope `(path "host" "str" "upper") args out)]
    [`(path "std" "str" "lower")
     (eval-call rt scope `(path "host" "str" "lower") args out)]
    [`(path "std" "num" "abs")
     (eval-call rt scope `(path "host" "math" "abs") args out)]
    [`(path "std" "num" "min")
     (eval-call rt scope `(path "host" "math" "min") args out)]
    [`(path "std" "num" "max")
     (eval-call rt scope `(path "host" "math" "max") args out)]
    [`(path "std" "num" "round")
     (eval-call rt scope `(path "host" "math" "round") args out)]
    [`(path "std" "group" "count")
     (expect-arg-count "std.group.count" args 1)
     (define group (first args))
     (unless (s-group? group)
       (runtime-error "std.group.count expects Group"))
     (length (s-group-items group))]
    [`(path "std" "group" "at")
     (expect-arg-count "std.group.at" args 2)
     (define group (first args))
     (define index (second args))
     (unless (s-group? group)
       (runtime-error "std.group.at expects Group"))
     (unless (and (number? index) (integer? index))
       (runtime-error "std.group.at index must be integer"))
     (unless (and (<= 0 index) (< index (length (s-group-items group))))
       (runtime-error "std.group.at index out of range"))
     (list-ref (s-group-items group) index)]
    [`(path "world" "spawn")
     (expect-arg-count "world.spawn" args 1)
     (world-spawn! rt (first args))]
    [`(path "world" "place")
     (expect-arg-count "world.place" args 3)
     (world-place! rt (first args) (second args) (third args))
     none-value]
    [`(path "world" "move")
     (expect-arg-count "world.move" args 3)
     (world-move! rt (first args) (second args) (third args))
     none-value]
    [`(path "world" "trace")
     (fprintf out "~a" (world-trace-string rt))
     none-value]
    [`(path "world" "trace_text")
     (expect-arg-count "world.trace_text" args 0)
     (world-trace-string rt)]
    [`(path "world" "state")
     (fprintf out "~a" (world-state-string rt))
     none-value]
    [`(path "world" "state_text")
     (expect-arg-count "world.state_text" args 0)
     (world-state-string rt)]
    [`(path "world" "replay")
     (expect-arg-count "world.replay" args 1)
     (world-replay (first args))]
    [`(path "visual" "sheet")
     (expect-arg-count "visual.sheet" args 1)
     (define kind (first args))
     (unless (string? kind)
       (runtime-error "visual.sheet expects string kind"))
     (visual-add-trace! rt (format "sheet ~a" kind))
     none-value]
    [`(path "visual" "grid")
     (expect-arg-count "visual.grid" args 1)
     (define size (first args))
     (expect-number "visual.grid size" size)
     (visual-add-trace! rt (format "grid ~a" size))
     none-value]
    [`(path "visual" "square_bipyramid")
     (expect-arg-count "visual.square_bipyramid" args 4)
     (define name (first args))
     (define height (second args))
     (define base (third args))
     (define color (fourth args))
     (unless (string? name)
       (runtime-error "visual.square_bipyramid expects string name"))
     (expect-number "visual.square_bipyramid height" height)
     (expect-number "visual.square_bipyramid base" base)
     (unless (string? color)
       (runtime-error "visual.square_bipyramid expects string color"))
     (visual-add-trace! rt
                        (format "shape square_bipyramid ~a height ~a base ~a color ~a"
                                name
                                height
                                base
                                color))
     none-value]
    [`(path "visual" "rotate")
     (expect-arg-count "visual.rotate" args 3)
     (define name (first args))
     (define axis (second args))
     (define speed (third args))
     (unless (and (string? name) (string? axis))
       (runtime-error "visual.rotate expects string name and axis"))
     (expect-number "visual.rotate speed" speed)
     (visual-add-trace! rt (format "motion rotate ~a ~a ~a" name axis speed))
     none-value]
    [`(path "visual" "present")
     (expect-arg-count "visual.present" args 0)
     (visual-add-trace! rt "present")
     none-value]
    [`(path "visual" "trace")
     (fprintf out "~a" (visual-trace-string rt))
     none-value]
    [`(path "visual" "trace_text")
     (expect-arg-count "visual.trace_text" args 0)
     (visual-trace-string rt)]
    [`(path ,name)
     (call-skill rt name args out)]
    [_ (runtime-error "unsupported call target: ~s" callee)]))

(define (expect-arg-count name args expected)
  (unless (= (length args) expected)
    (runtime-error "~a expected ~a args, got ~a" name expected (length args))))

(define (count-lines text)
  (cond
    [(string=? text "") 0]
    [else
     (+ (for/sum ([ch (in-string text)]
                  #:when (char=? ch #\newline))
          1)
        (if (char=? (string-ref text (sub1 (string-length text))) #\newline)
            0
            1))]))

(define (world-spawn! rt kind)
  (unless (string? kind)
    (runtime-error "world.spawn expects string kind"))
  (define world (runtime-world rt))
  (define id (unbox (world-state-next-id world)))
  (set-box! (world-state-next-id world) (add1 id))
  (hash-set! (world-state-objects world) id (world-object kind 0 0))
  (world-add-trace! rt (format "spawn #~a ~a" id kind))
  (s-world-ref id))

(define (world-place! rt ref x y)
  (define object (world-object-ref rt ref))
  (expect-number "world.place x" x)
  (expect-number "world.place y" y)
  (hash-set! (world-state-objects (runtime-world rt))
             (s-world-ref-id ref)
             (world-object (world-object-kind object) x y))
  (world-add-trace! rt (format "place #~a ~a ~a" (s-world-ref-id ref) x y)))

(define (world-move! rt ref dx dy)
  (define object (world-object-ref rt ref))
  (expect-number "world.move dx" dx)
  (expect-number "world.move dy" dy)
  (define x (+ (world-object-x object) dx))
  (define y (+ (world-object-y object) dy))
  (hash-set! (world-state-objects (runtime-world rt))
             (s-world-ref-id ref)
             (world-object (world-object-kind object) x y))
  (world-add-trace! rt (format "move #~a ~a ~a" (s-world-ref-id ref) dx dy)))

(define (world-object-ref rt ref)
  (unless (s-world-ref? ref)
    (runtime-error "world operation expects object handle"))
  (define object (hash-ref (world-state-objects (runtime-world rt))
                           (s-world-ref-id ref)
                           #f))
  (unless object
    (runtime-error "world object #~a not found" (s-world-ref-id ref)))
  object)

(define (world-add-trace! rt line)
  (define trace (world-state-trace (runtime-world rt)))
  (set-box! trace (append (unbox trace) (list line))))

(define (world-trace-string rt)
  (define lines (unbox (world-state-trace (runtime-world rt))))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (visual-add-trace! rt line)
  (define trace (visual-state-trace (runtime-visual rt)))
  (set-box! trace (append (unbox trace) (list line))))

(define (visual-trace-string rt)
  (define lines (unbox (visual-state-trace (runtime-visual rt))))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (world-state-string rt)
  (world-state->string (runtime-world rt)))

(define (world-state->string world)
  (define objects (world-state-objects world))
  (define lines
    (for/list ([id (sort (hash-keys objects) <)])
      (define object (hash-ref objects id))
      (format "#~a ~a at ~a ~a"
              id
              (world-object-kind object)
              (world-object-x object)
              (world-object-y object))))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (world-replay trace-text)
  (unless (string? trace-text)
    (runtime-error "world.replay expects trace string"))
  (define world (make-world-state))
  (for ([line (in-list (filter non-empty-string? (string-split trace-text "\n")))])
    (world-apply-trace-line! world line))
  (world-state->string world))

(define (non-empty-string? value)
  (not (string=? value "")))

(define (world-apply-trace-line! world line)
  (define parts (string-split line))
  (match parts
    [(list "spawn" id-text kind)
     (define id (parse-world-id id-text line))
     (hash-set! (world-state-objects world) id (world-object kind 0 0))
     (set-box! (world-state-next-id world)
               (max (unbox (world-state-next-id world)) (add1 id)))]
    [(list "place" id-text x-text y-text)
     (define id (parse-world-id id-text line))
     (define object (hash-ref (world-state-objects world) id #f))
     (unless object
       (runtime-error "world.replay cannot place missing object #~a" id))
     (hash-set! (world-state-objects world)
                id
                (world-object (world-object-kind object)
                              (parse-trace-number x-text line)
                              (parse-trace-number y-text line)))]
    [(list "move" id-text dx-text dy-text)
     (define id (parse-world-id id-text line))
     (define object (hash-ref (world-state-objects world) id #f))
     (unless object
       (runtime-error "world.replay cannot move missing object #~a" id))
     (hash-set! (world-state-objects world)
                id
                (world-object (world-object-kind object)
                              (+ (world-object-x object) (parse-trace-number dx-text line))
                              (+ (world-object-y object) (parse-trace-number dy-text line))))]
    [_ (runtime-error "world.replay cannot parse trace line: ~a" line)]))

(define (parse-world-id text line)
  (unless (and (positive? (string-length text))
               (char=? (string-ref text 0) #\#))
    (runtime-error "world.replay expected object id in trace line: ~a" line))
  (define value (string->number (substring text 1)))
  (unless (and (integer? value) (positive? value))
    (runtime-error "world.replay expected positive object id in trace line: ~a" line))
  value)

(define (parse-trace-number text line)
  (define value (string->number text))
  (unless (number? value)
    (runtime-error "world.replay expected number in trace line: ~a" line))
  value)

(define (expect-number name value)
  (unless (number? value)
    (runtime-error "~a expects number" name)))

(define (eval-binary op left right)
  (match op
    ["+" (+ left right)]
    ["-" (- left right)]
    ["*" (* left right)]
    ["/"
     (if (zero? right)
         (s-error "DivisionByZero")
         (/ left right))]
    ["==" (value=? left right)]
    [">" (> left right)]
    ["<" (< left right)]
    [_ (runtime-error "unsupported operator '~a'" op)]))

(define (truthy? value)
  (not (eq? value #f)))

(define (case-matches? value tag)
  (cond
    [(s-enum? value) (equal? (s-enum-variant value) tag)]
    [(s-error? value) (equal? (s-error-name value) tag)]
    [else #f]))

(define (value=? left right)
  (cond
    [(and (s-none? left) (s-none? right)) #t]
    [(and (s-error? left) (s-error? right))
     (equal? (s-error-name left) (s-error-name right))]
    [(and (s-enum? left) (s-enum? right))
     (and (equal? (s-enum-enum left) (s-enum-enum right))
          (equal? (s-enum-variant left) (s-enum-variant right)))]
    [else (equal? left right)]))

(define (value->string value)
  (cond
    [(s-none? value) "none"]
    [(eq? value #t) "yes"]
    [(eq? value #f) "no"]
    [(s-error? value) (format "error.~a" (s-error-name value))]
    [(s-enum? value)
     (if (s-enum-enum value)
         (format "~a.~a" (s-enum-enum value) (s-enum-variant value))
         (format ".~a" (s-enum-variant value)))]
    [(s-box? value) (format "~a {...}" (s-box-name value))]
    [(s-group? value) (format "Group(~a)" (length (s-group-items value)))]
    [(s-world-ref? value) (format "#~a" (s-world-ref-id value))]
    [else (format "~a" value)]))

(define (runtime-error message . args)
  (apply error 'runtime message args))
