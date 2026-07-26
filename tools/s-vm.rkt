#lang racket

(require racket/string
         "s-modules.rkt")

(provide compile-s-file/vm
         compile-s-datum/vm
         run-s-file/vm
         run-s-datum/vm
         vm-program-bytecode
         vm-run-result-value
         vm-run-result-output
         vm-error-value?
         vm-error-value-name
         vm-bytecode->text)

(struct vm-program (functions entry boxes enums) #:transparent)
(struct vm-function (name params code) #:transparent)
(struct vm-box-value (name fields) #:transparent)
(struct vm-group-value (items) #:transparent)
(struct vm-error-value (name) #:transparent)
(struct vm-enum-value (enum variant) #:transparent)
(struct vm-world-ref (id) #:transparent)
(struct vm-world-object (kind x y) #:transparent)
(struct vm-run-result (value output) #:transparent)
(struct vm-state (visual-trace world-next-id world-objects world-trace world-events) #:transparent)
(struct frame (name params code env ip) #:transparent #:mutable)
(struct return-value (value) #:transparent)

(define none-value 'none)

(define (compile-s-file/vm path)
  (compile-s-datum/vm (load-s-file-datum path)))

(define (run-s-file/vm path)
  (run-s-datum/vm (load-s-file-datum path)))

(define (compile-s-datum/vm ast)
  (match ast
    [`(program ,items ...)
     (define expanded-items
       (if (uses-core? items)
           (append (standard-vm-items) items)
           items))
     (define boxes (collect-boxes expanded-items))
     (define enums (collect-enums expanded-items))
     (define functions (make-hash))
     (define entry #f)
     (for ([item expanded-items])
       (match item
         [`(skill ,name ,params ,body)
          (hash-set! functions name (compile-function name params body boxes enums))]
         [`(entry ,params ,body)
          (set! entry (compile-function "program" params body boxes enums))]
         [_ (void)]))
     (unless entry
       (vm-error "missing program entry"))
     (vm-program functions entry boxes enums)]
    [_ (vm-error "expected program AST")]))

(define (collect-boxes items)
  (define boxes (make-hash))
  (for ([item items])
    (match item
      [`(box ,name ,fields ...)
       (hash-set! boxes name fields)]
      [_ (void)]))
  boxes)

(define (collect-enums items)
  (define enums (make-hash))
  (for ([item items])
    (match item
      [`(enum ,name ,variants ...)
       (hash-set! enums name variants)]
      [_ (void)]))
  enums)

(define (uses-core? items)
  (for/or ([item items])
    (match item
      [(or `(use "core") `(use "core")) #t]
      [_ #f])))

(define (standard-vm-items)
  (apply append
         (for/list ([path (core-module-paths)])
           (match (load-s-file-datum path)
             [`(program ,items ...) items]
             [_ (vm-error "expected core module AST in ~a" path)]))))

(define (compile-function name params body boxes enums)
  (vm-function name params (append (compile-block body boxes enums) (list '(push-none) '(return)))))

(define (compile-block body boxes enums)
  (match body
    [`(block ,items ...)
     (append-map (lambda (item) (compile-stmt item boxes enums)) items)]
    [_ (vm-error "expected block AST")]))

(define (compile-block-value body boxes enums)
  (match body
    [`(block) (list '(push-none))]
    [`(block ,items ...)
     (define prefix (drop-right items 1))
     (define last-item (last items))
     (append
      (append-map (lambda (item) (compile-stmt item boxes enums)) prefix)
      (match last-item
        [`(expr ,value) (compile-expr value boxes enums)]
        [`(out ,value) (append (compile-expr value boxes enums) (list '(return)))]
        [`(switch ,value ,cases ...)
         (compile-switch value cases boxes enums)]
        [_ (append (compile-stmt last-item boxes enums) (list '(push-none)))]))]
    [_ (vm-error "expected block AST")]))

(define (compile-stmt stmt boxes enums)
  (match stmt
    [`(var ,name ,value)
     (append (compile-expr value boxes enums) (list `(store ,name)))]
    [`(assign ,name ,value)
     (append (compile-expr value boxes enums) (list `(store ,name)))]
    [`(expr ,value)
     (append (compile-expr value boxes enums) (list '(pop)))]
    [`(out ,value)
     (append (compile-expr value boxes enums) (list '(return)))]
    [`(if ,test ,body)
     (append (compile-expr test boxes enums)
             (list `(if ,(compile-block body boxes enums))))]
    [`(drum ,count ,body)
     (append (compile-expr count boxes enums)
             (list `(drum ,(compile-block body boxes enums))))]
    [`(switch ,value ,cases ...)
     (append (compile-switch value cases boxes enums) (list '(pop)))]
    [_ (vm-error "VM v0 unsupported statement: ~s" stmt)]))

(define (compile-expr expr boxes enums)
  (match expr
    [`(number ,value) (list `(push ,value))]
    [`(string ,value) (list `(push ,value))]
    [`(answer ,value) (list `(push ,(equal? value "yes")))]
    [`(none) (list '(push-none))]
    [`(enum-value ,name) (list `(push-enum #f ,name))]
    [`(path "error" ,name) (list `(push-error ,name))]
    [`(path ,enum-name ,variant)
     #:when (and (hash-has-key? enums enum-name)
                 (member variant (hash-ref enums enum-name)))
     (list `(push-enum ,enum-name ,variant))]
    [`(path ,name) (list `(load ,name))]
    [`(path ,name ,fields ...)
     (append (list `(load ,name))
             (for/list ([field fields])
               `(field ,field)))]
    [`(group ,items ...)
     (append (append-map (lambda (item) (compile-expr item boxes enums)) items)
             (list `(group ,(length items))))]
    [`(box-new ,name ,fields ...)
     (compile-box-new name fields boxes enums)]
    [`(call ,callee ,args ...)
     (append (append-map (lambda (arg) (compile-expr arg boxes enums)) args)
             (list `(call ,(callee->name callee) ,(length args))))]
    [`(binary ,op ,left ,right)
     (append (compile-expr left boxes enums)
             (compile-expr right boxes enums)
             (list (binary-op->instruction op)))]
    [`(rescue ,value ,err ,body)
     (append (compile-expr value boxes enums)
             (list `(rescue ,err ,(compile-block-value body boxes enums))))]
    [_ (vm-error "VM v0 unsupported expression: ~s" expr)]))

(define (compile-switch value cases boxes enums)
  (append
   (compile-expr value boxes enums)
   (list
    `(switch
      ,(for/list ([case cases])
         (match case
           [`(case ,tag ,case-value)
            `(case ,tag ,(compile-expr case-value boxes enums))]
           [_ (vm-error "malformed switch case: ~s" case)]))))))

(define (compile-box-new name fields boxes enums)
  (define defaults (hash-ref boxes name #f))
  (unless defaults
    (vm-error "unknown Box '~a'" name))
  (define values (make-hash))
  (define order '())
  (for ([field defaults])
    (match field
      [`(field ,field-name ,value)
       (set! order (append order (list field-name)))
       (hash-set! values field-name value)]
      [_ (vm-error "malformed Box field in '~a'" name)]))
  (for ([field fields])
    (match field
      [`(field ,field-name ,value)
       (unless (hash-has-key? values field-name)
         (vm-error "Box '~a' has no field '~a'" name field-name))
       (hash-set! values field-name value)]
      [_ (vm-error "malformed Box literal field in '~a'" name)]))
  (append
   (append-map (lambda (field-name) (compile-expr (hash-ref values field-name) boxes enums)) order)
   (list `(box-new ,name ,order))))

(define (callee->name callee)
  (match callee
    [`(path ,parts ...) (string-join parts ".")]
    [_ (vm-error "VM v0 unsupported callee: ~s" callee)]))

(define (binary-op->instruction op)
  (match op
    ["+" '(add)]
    ["-" '(sub)]
    ["*" '(mul)]
    ["/" '(div)]
    ["==" '(eq)]
    [">" '(gt)]
    ["<" '(lt)]
    [_ (vm-error "VM v0 unsupported operator: ~a" op)]))

(define (run-s-datum/vm ast)
  (run-vm (compile-s-datum/vm ast)))

(define (run-vm program)
  (define output (open-output-string))
  (define state (vm-state (box '()) (box 1) (make-hash) (box '()) (box '())))
  (define value
    (with-handlers ([return-value? return-value-value])
      (run-function program (vm-program-entry program) '() output state)
      none-value))
  (vm-run-result value (get-output-string output)))

(define (run-function program fn args output state)
  (unless (= (length args) (length (vm-function-params fn)))
    (vm-error "~a expected ~a args, got ~a"
              (vm-function-name fn)
              (length (vm-function-params fn))
              (length args)))
  (define env (make-hash))
  (for ([param (vm-function-params fn)]
        [arg args])
    (hash-set! env param arg))
  (define current (frame (vm-function-name fn) (vm-function-params fn) (vm-function-code fn) env 0))
  (define stack '())
  (define (run-code! code)
    (define saved-code (frame-code current))
    (define saved-ip (frame-ip current))
    (set-frame-code! current code)
    (set-frame-ip! current 0)
    (let loop ()
      (when (< (frame-ip current) (length (frame-code current)))
        (step!)
        (loop)))
    (set-frame-code! current saved-code)
    (set-frame-ip! current saved-ip))
  (define (step!)
    (define instruction (list-ref (frame-code current) (frame-ip current)))
    (set-frame-ip! current (add1 (frame-ip current)))
    (match instruction
      [`(push ,value)
       (set! stack (cons value stack))]
      [`(push-error ,name)
       (set! stack (cons (vm-error-value name) stack))]
      [`(push-enum ,enum ,variant)
       (set! stack (cons (vm-enum-value enum variant) stack))]
      [`(push-none)
       (set! stack (cons none-value stack))]
      [`(load ,name)
       (unless (hash-has-key? (frame-env current) name)
         (vm-error "unknown variable '~a'" name))
       (set! stack (cons (hash-ref (frame-env current) name) stack))]
      [`(store ,name)
       (define value (pop! stack))
       (set! stack (rest stack))
       (hash-set! (frame-env current) name value)]
      [`(pop)
       (pop! stack)
       (set! stack (rest stack))]
      [`(add) (set! stack (binary-number stack +))]
      [`(sub) (set! stack (binary-number stack -))]
      [`(mul) (set! stack (binary-number stack *))]
      [`(div) (set! stack (binary-div stack))]
      [`(eq) (set! stack (binary-value stack equal?))]
      [`(gt) (set! stack (binary-number stack >))]
      [`(lt) (set! stack (binary-number stack <))]
      [`(call ,name ,argc)
       (define-values (call-args stack*) (pop-args stack argc))
       (set! stack stack*)
       (define call-result (call-vm-function program name call-args output state))
       (set! stack (cons call-result stack))]
      [`(group ,count)
       (define-values (items stack*) (pop-args stack count))
       (set! stack stack*)
       (set! stack (cons (vm-group-value items) stack))]
      [`(box-new ,name ,fields)
       (define-values (field-values stack*) (pop-args stack (length fields)))
       (set! stack stack*)
       (set! stack (cons (vm-box-value name (for/hash ([field fields]
                                                       [value field-values])
                                             (values field value)))
                         stack))]
      [`(field ,name)
       (define value (pop! stack))
       (set! stack (rest stack))
       (unless (vm-box-value? value)
         (vm-error "cannot access field '~a' on ~a" name (value->text value)))
       (unless (hash-has-key? (vm-box-value-fields value) name)
         (vm-error "Box '~a' has no field '~a'" (vm-box-value-name value) name))
       (set! stack (cons (hash-ref (vm-box-value-fields value) name) stack))]
      [`(if ,body-code)
       (define test (pop! stack))
       (set! stack (rest stack))
       (when (truthy? test)
         (run-code! body-code))]
      [`(drum ,body-code)
       (define count (pop! stack))
       (set! stack (rest stack))
       (unless (and (number? count) (integer? count) (not (negative? count)))
         (vm-error "drum count must be a non-negative integer"))
       (for ([_ (in-range count)])
         (run-code! body-code))]
      [`(rescue ,err ,body-code)
       (define value (pop! stack))
       (set! stack (rest stack))
       (if (vm-error-value? value)
           (let ([had-existing? (hash-has-key? (frame-env current) err)]
                 [existing (hash-ref (frame-env current) err #f)])
             (hash-set! (frame-env current) err value)
             (run-code! body-code)
             (if had-existing?
                 (hash-set! (frame-env current) err existing)
                 (hash-remove! (frame-env current) err)))
           (set! stack (cons value stack)))]
      [`(switch ,cases)
       (define value (pop! stack))
       (set! stack (rest stack))
       (define selected
         (for/first ([case cases]
                     #:when (match case
                              [`(case ,tag ,_body-code) (vm-case-matches? value tag)]
                              [_ (vm-error "malformed switch case: ~s" case)]))
           case))
       (if selected
           (match selected
             [`(case ,_tag ,body-code)
              (run-code! body-code)]
             [_ (vm-error "malformed switch case: ~s" selected)])
           (set! stack (cons none-value stack)))]
      [`(return)
       (raise (return-value (pop! stack)))]
      [_ (vm-error "unknown VM instruction: ~s" instruction)]))
  (let loop ()
    (when (>= (frame-ip current) (length (frame-code current)))
      (raise (return-value none-value)))
    (step!)
    (loop)))

(define (call-vm-function program name args output state)
  (cond
    [(core-call-skill-name name)
     => (lambda (skill-name)
          (call-vm-function program skill-name args output state))]
    [(equal? name "core.io.println")
     (fprintf output "~a\n" (string-join (map value->text args) ""))
     none-value]
    [(equal? name "core.io.show")
     (fprintf output "~a\n" (string-join (map value->text args) ""))
     none-value]
    [(equal? name "core.group.count")
     (expect-vm-arg-count name args 1)
     (unless (vm-group-value? (first args))
       (vm-error "core.group.count expects Group"))
     (length (vm-group-value-items (first args)))]
    [(equal? name "core.group.at")
     (expect-vm-arg-count name args 2)
     (define group (first args))
     (define index (second args))
     (unless (vm-group-value? group)
       (vm-error "core.group.at expects Group"))
     (unless (and (number? index) (integer? index))
       (vm-error "core.group.at index must be integer"))
     (unless (and (<= 0 index) (< index (length (vm-group-value-items group))))
       (vm-error "core.group.at index out of range"))
     (list-ref (vm-group-value-items group) index)]
    [(equal? name "core.group.append")
     (expect-vm-arg-count name args 2)
     (define group (first args))
     (define value (second args))
     (unless (vm-group-value? group)
       (vm-error "core.group.append expects Group"))
     (vm-group-value (append (vm-group-value-items group) (list value)))]
    [(equal? name "host.str.join")
     (string-join (map value->text args) "")]
    [(equal? name "host.str.len")
     (expect-vm-arg-count name args 1)
     (string-length (first args))]
    [(equal? name "host.str.at")
     (expect-vm-arg-count name args 2)
     (define text (first args))
     (define index (second args))
     (unless (string? text)
       (vm-error "host.str.at expects string"))
     (unless (and (number? index) (integer? index))
       (vm-error "host.str.at index must be integer"))
     (unless (and (<= 0 index) (< index (string-length text)))
       (vm-error "host.str.at index out of range"))
     (string (string-ref text index))]
    [(equal? name "host.str.slice")
     (expect-vm-arg-count name args 3)
     (define text (first args))
     (define start (second args))
     (define end (third args))
     (unless (string? text)
       (vm-error "host.str.slice expects string"))
     (unless (and (number? start) (integer? start)
                  (number? end) (integer? end))
       (vm-error "host.str.slice indexes must be integers"))
     (unless (and (<= 0 start) (<= start end) (<= end (string-length text)))
       (vm-error "host.str.slice range out of bounds"))
     (substring text start end)]
    [(equal? name "host.str.eq")
     (expect-vm-arg-count name args 2)
     (equal? (first args) (second args))]
    [(equal? name "host.math.abs")
     (expect-vm-arg-count name args 1)
     (abs (first args))]
    [(equal? name "host.math.round")
     (expect-vm-arg-count name args 1)
     (round (first args))]
    [(equal? name "world.spawn")
     (expect-vm-arg-count name args 1)
     (world-spawn! state (first args))]
    [(equal? name "world.emit")
     (world-emit! state args)
     none-value]
    [(equal? name "world.step")
     (expect-vm-arg-count name args 0)
     (world-step! state)
     none-value]
    [(equal? name "world.trace")
     (expect-vm-arg-count name args 0)
     (fprintf output "~a" (world-trace-string state))
     none-value]
    [(equal? name "world.trace_text")
     (expect-vm-arg-count name args 0)
     (world-trace-string state)]
    [(equal? name "world.state")
     (expect-vm-arg-count name args 0)
     (fprintf output "~a" (world-state-string state))
     none-value]
    [(equal? name "world.state_text")
     (expect-vm-arg-count name args 0)
     (world-state-string state)]
    [(equal? name "world.replay")
     (expect-vm-arg-count name args 1)
     (world-replay (first args))]
    [(equal? name "visual.sheet")
     (expect-vm-arg-count name args 1)
     (define kind (first args))
     (unless (string? kind)
       (vm-error "visual.sheet expects string kind"))
     (visual-add-trace! state (format "sheet ~a" kind))
     none-value]
    [(equal? name "visual.grid")
     (expect-vm-arg-count name args 1)
     (define size (first args))
     (expect-vm-number "visual.grid size" size)
     (visual-add-trace! state (format "grid ~a" size))
     none-value]
    [(equal? name "visual.square_bipyramid")
     (expect-vm-arg-count name args 4)
     (define shape-name (first args))
     (define height (second args))
     (define base (third args))
     (define color (fourth args))
     (unless (string? shape-name)
       (vm-error "visual.square_bipyramid expects string name"))
     (expect-vm-number "visual.square_bipyramid height" height)
     (expect-vm-number "visual.square_bipyramid base" base)
     (unless (string? color)
       (vm-error "visual.square_bipyramid expects string color"))
     (visual-add-trace! state
                        (format "shape square_bipyramid ~a height ~a base ~a color ~a"
                                shape-name
                                height
                                base
                                color))
     none-value]
    [(equal? name "visual.rotate")
     (expect-vm-arg-count name args 3)
     (define shape-name (first args))
     (define axis (second args))
     (define speed (third args))
     (unless (and (string? shape-name) (string? axis))
       (vm-error "visual.rotate expects string name and axis"))
     (expect-vm-number "visual.rotate speed" speed)
     (visual-add-trace! state (format "motion rotate ~a ~a ~a" shape-name axis speed))
     none-value]
    [(equal? name "visual.present")
     (expect-vm-arg-count name args 0)
     (visual-add-trace! state "present")
     none-value]
    [(equal? name "visual.trace")
     (expect-vm-arg-count name args 0)
     (fprintf output "~a" (visual-trace-string state))
     none-value]
    [(equal? name "visual.trace_text")
     (expect-vm-arg-count name args 0)
     (visual-trace-string state)]
    [(hash-has-key? (vm-program-functions program) name)
     (with-handlers ([return-value? return-value-value])
       (run-function program (hash-ref (vm-program-functions program) name) args output state))]
    [else (vm-error "VM v0 unknown call '~a'" name)]))

(define (core-call-skill-name name)
  (match name
    ["core.str.lines_count" "core_str_lines_count"]
    ["core.str.lines" "core_str_lines"]
    ["core.str.add" "core_str_add"]
    ["core.str.len" "core_str_len"]
    ["core.str.at" "core_str_at"]
    ["core.str.slice" "core_str_slice"]
    ["core.str.eq" "core_str_eq"]
    ["core.str.is_empty" "core_str_is_empty"]
    ["core.str.starts_with" "core_str_starts_with"]
    ["core.str.ends_with" "core_str_ends_with"]
    ["core.str.contains" "core_str_contains"]
    ["core.str.split" "core_str_split"]
    ["core.str.trim" "core_str_trim"]
    ["core.str.upper" "core_str_upper"]
    ["core.str.lower" "core_str_lower"]
    ["core.group.add" "core_group_add"]
    ["core.group.size" "core_group_size"]
    ["core.group.item" "core_group_item"]
    ["core.group.empty" "core_group_empty"]
    ["core.num.abs" "core_num_abs"]
    ["core.num.round" "core_num_round"]
    [_ #f]))

(define (expect-vm-arg-count name args expected)
  (unless (= (length args) expected)
    (vm-error "~a expected ~a args, got ~a" name expected (length args))))

(define (expect-vm-number name value)
  (unless (number? value)
    (vm-error "~a expects number" name)))

(define (visual-add-trace! state line)
  (define trace (vm-state-visual-trace state))
  (set-box! trace (append (unbox trace) (list line))))

(define (visual-trace-string state)
  (define lines (unbox (vm-state-visual-trace state)))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (world-spawn! state kind)
  (unless (string? kind)
    (vm-error "world.spawn expects string kind"))
  (define id (unbox (vm-state-world-next-id state)))
  (set-box! (vm-state-world-next-id state) (add1 id))
  (hash-set! (vm-state-world-objects state) id (vm-world-object kind 0 0))
  (world-add-trace! state (format "spawn #~a ~a" id kind))
  (vm-world-ref id))

(define (world-emit! state args)
  (when (< (length args) 2)
    (vm-error "world.emit expects target and skill name"))
  (define target (first args))
  (define skill (second args))
  (unless (vm-world-ref? target)
    (vm-error "world.emit expects object handle target"))
  (unless (string? skill)
    (vm-error "world.emit expects string skill name"))
  (define events (vm-state-world-events state))
  (set-box! events (append (unbox events) (list (list* target skill (drop args 2))))))

(define (world-step! state)
  (define events (vm-state-world-events state))
  (define queued (unbox events))
  (set-box! events '())
  (for ([event queued])
    (match event
      [(list ref "place" x y)
       (world-place! state ref x y)]
      [(list ref "move" dx dy)
       (world-move! state ref dx dy)]
      [(list _ skill _ ...)
       (vm-error "world.step cannot apply skill '~a'" skill)])))

(define (world-place! state ref x y)
  (define object (world-object-ref state ref))
  (expect-vm-number "world.place x" x)
  (expect-vm-number "world.place y" y)
  (hash-set! (vm-state-world-objects state)
             (vm-world-ref-id ref)
             (vm-world-object (vm-world-object-kind object) x y))
  (world-add-trace! state (format "place #~a ~a ~a" (vm-world-ref-id ref) x y)))

(define (world-move! state ref dx dy)
  (define object (world-object-ref state ref))
  (expect-vm-number "world.move dx" dx)
  (expect-vm-number "world.move dy" dy)
  (define x (+ (vm-world-object-x object) dx))
  (define y (+ (vm-world-object-y object) dy))
  (hash-set! (vm-state-world-objects state)
             (vm-world-ref-id ref)
             (vm-world-object (vm-world-object-kind object) x y))
  (world-add-trace! state (format "move #~a ~a ~a" (vm-world-ref-id ref) dx dy)))

(define (world-object-ref state ref)
  (unless (vm-world-ref? ref)
    (vm-error "world operation expects object handle"))
  (define object (hash-ref (vm-state-world-objects state) (vm-world-ref-id ref) #f))
  (unless object
    (vm-error "world object #~a not found" (vm-world-ref-id ref)))
  object)

(define (world-add-trace! state line)
  (define trace (vm-state-world-trace state))
  (set-box! trace (append (unbox trace) (list line))))

(define (world-trace-string state)
  (define lines (unbox (vm-state-world-trace state)))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (world-state-string state)
  (world-state->string (vm-state-world-objects state)))

(define (world-state->string objects)
  (define lines
    (for/list ([id (sort (hash-keys objects) <)])
      (define object (hash-ref objects id))
      (format "#~a ~a at ~a ~a"
              id
              (vm-world-object-kind object)
              (vm-world-object-x object)
              (vm-world-object-y object))))
  (if (null? lines)
      ""
      (string-append (string-join lines "\n") "\n")))

(define (world-replay trace-text)
  (unless (string? trace-text)
    (vm-error "world.replay expects trace string"))
  (define objects (make-hash))
  (for ([line (in-list (filter non-empty-string? (string-split trace-text "\n")))])
    (world-apply-trace-line! objects line))
  (world-state->string objects))

(define (world-apply-trace-line! objects line)
  (define parts (string-split line))
  (match parts
    [(list "spawn" id-text kind)
     (define id (parse-world-id id-text line))
     (hash-set! objects id (vm-world-object kind 0 0))]
    [(list "place" id-text x-text y-text)
     (define id (parse-world-id id-text line))
     (define object (hash-ref objects id #f))
     (unless object
       (vm-error "world.replay cannot place missing object #~a" id))
     (hash-set! objects
                id
                (vm-world-object (vm-world-object-kind object)
                                 (parse-trace-number x-text line)
                                 (parse-trace-number y-text line)))]
    [(list "move" id-text dx-text dy-text)
     (define id (parse-world-id id-text line))
     (define object (hash-ref objects id #f))
     (unless object
       (vm-error "world.replay cannot move missing object #~a" id))
     (hash-set! objects
                id
                (vm-world-object (vm-world-object-kind object)
                                 (+ (vm-world-object-x object) (parse-trace-number dx-text line))
                                 (+ (vm-world-object-y object) (parse-trace-number dy-text line))))]
    [_ (vm-error "world.replay cannot parse trace line: ~a" line)]))

(define (parse-world-id text line)
  (unless (and (positive? (string-length text))
               (char=? (string-ref text 0) #\#))
    (vm-error "world.replay expected object id in trace line: ~a" line))
  (define value (string->number (substring text 1)))
  (unless (and (integer? value) (positive? value))
    (vm-error "world.replay expected positive object id in trace line: ~a" line))
  value)

(define (parse-trace-number text line)
  (define value (string->number text))
  (unless (number? value)
    (vm-error "world.replay expected number in trace line: ~a" line))
  value)

(define (non-empty-string? value)
  (not (string=? value "")))

(define (pop! stack)
  (when (null? stack)
    (vm-error "stack underflow"))
  (first stack))

(define (pop-args stack argc)
  (when (< (length stack) argc)
    (vm-error "stack underflow while reading call args"))
  (define reversed (take stack argc))
  (values (reverse reversed) (drop stack argc)))

(define (binary-number stack proc)
  (define right (pop! stack))
  (define stack* (rest stack))
  (define left (pop! stack*))
  (unless (and (number? left) (number? right))
    (vm-error "numeric operation expects numbers"))
  (cons (proc left right) (rest stack*)))

(define (binary-div stack)
  (define right (pop! stack))
  (define stack* (rest stack))
  (define left (pop! stack*))
  (unless (and (number? left) (number? right))
    (vm-error "numeric operation expects numbers"))
  (cons (if (zero? right)
            (vm-error-value "DivisionByZero")
            (/ left right))
        (rest stack*)))

(define (binary-value stack proc)
  (define right (pop! stack))
  (define stack* (rest stack))
  (define left (pop! stack*))
  (cons (proc left right) (rest stack*)))

(define (vm-case-matches? value tag)
  (cond
    [(vm-enum-value? value) (equal? (vm-enum-value-variant value) tag)]
    [(vm-error-value? value) (equal? (vm-error-value-name value) tag)]
    [else #f]))

(define (truthy? value)
  (not (eq? value #f)))

(define (value->text value)
  (cond
    [(eq? value none-value) "none"]
    [(eq? value #t) "yes"]
    [(eq? value #f) "no"]
    [(vm-box-value? value) (format "~a {...}" (vm-box-value-name value))]
    [(vm-group-value? value) (format "Group(~a)" (length (vm-group-value-items value)))]
    [(vm-error-value? value) (format "error.~a" (vm-error-value-name value))]
    [(vm-enum-value? value)
     (if (vm-enum-value-enum value)
         (format "~a.~a" (vm-enum-value-enum value) (vm-enum-value-variant value))
         (format ".~a" (vm-enum-value-variant value)))]
    [(vm-world-ref? value) (format "#~a" (vm-world-ref-id value))]
    [else (format "~a" value)]))

(define (vm-program-bytecode program)
  (append
   (list (function->bytecode (vm-program-entry program)))
   (for/list ([name (sort (hash-keys (vm-program-functions program)) string<?)])
     (function->bytecode (hash-ref (vm-program-functions program) name)))))

(define (function->bytecode fn)
  `(function ,(vm-function-name fn) ,(vm-function-params fn) ,(vm-function-code fn)))

(define (vm-bytecode->text program)
  (define lines
    (append-map
     (lambda (fn-data)
       (match fn-data
         [`(function ,name ,params ,code)
          (append
           (list (format "function ~a(~a)" name (string-join params ", ")))
           (for/list ([instruction code]
                      [index (in-naturals)])
             (format "  ~a: ~s" index instruction)))]))
     (vm-program-bytecode program)))
  (string-append (string-join lines "\n") "\n"))

(define (vm-error message . args)
  (apply error 's-vm message args))
