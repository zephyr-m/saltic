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
         vm-bytecode->text)

(struct vm-program (functions entry boxes) #:transparent)
(struct vm-function (name params code) #:transparent)
(struct vm-box-value (name fields) #:transparent)
(struct vm-group-value (items) #:transparent)
(struct vm-run-result (value output) #:transparent)
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
       (if (uses-std? items)
           (append (standard-vm-items) items)
           items))
     (define boxes (collect-boxes expanded-items))
     (define functions (make-hash))
     (define entry #f)
     (for ([item expanded-items])
       (match item
         [`(skill ,name ,params ,body)
          (hash-set! functions name (compile-function name params body boxes))]
         [`(entry ,params ,body)
          (set! entry (compile-function "program" params body boxes))]
         [_ (void)]))
     (unless entry
       (vm-error "missing program entry"))
     (vm-program functions entry boxes)]
    [_ (vm-error "expected program AST")]))

(define (collect-boxes items)
  (define boxes (make-hash))
  (for ([item items])
    (match item
      [`(box ,name ,fields ...)
       (hash-set! boxes name fields)]
      [_ (void)]))
  boxes)

(define (uses-std? items)
  (for/or ([item items])
    (match item
      [`(use "std") #t]
      [_ #f])))

(define (standard-vm-items)
  (apply append
         (for/list ([path (std-module-paths)])
           (match (load-s-file-datum path)
             [`(program ,items ...) items]
             [_ (vm-error "expected std module AST in ~a" path)]))))

(define (compile-function name params body boxes)
  (vm-function name params (append (compile-block body boxes) (list '(push-none) '(return)))))

(define (compile-block body boxes)
  (match body
    [`(block ,items ...)
     (append-map (lambda (item) (compile-stmt item boxes)) items)]
    [_ (vm-error "expected block AST")]))

(define (compile-stmt stmt boxes)
  (match stmt
    [`(var ,name ,value)
     (append (compile-expr value boxes) (list `(store ,name)))]
    [`(assign ,name ,value)
     (append (compile-expr value boxes) (list `(store ,name)))]
    [`(expr ,value)
     (append (compile-expr value boxes) (list '(pop)))]
    [`(out ,value)
     (append (compile-expr value boxes) (list '(return)))]
    [`(drum ,count ,body)
     (append (compile-expr count boxes)
             (list `(drum ,(compile-block body boxes))))]
    [_ (vm-error "VM v0 unsupported statement: ~s" stmt)]))

(define (compile-expr expr boxes)
  (match expr
    [`(number ,value) (list `(push ,value))]
    [`(string ,value) (list `(push ,value))]
    [`(answer ,value) (list `(push ,(equal? value "yes")))]
    [`(none) (list '(push-none))]
    [`(path ,name) (list `(load ,name))]
    [`(path ,name ,fields ...)
     (append (list `(load ,name))
             (for/list ([field fields])
               `(field ,field)))]
    [`(group ,items ...)
     (append (append-map (lambda (item) (compile-expr item boxes)) items)
             (list `(group ,(length items))))]
    [`(box-new ,name ,fields ...)
     (compile-box-new name fields boxes)]
    [`(call ,callee ,args ...)
     (append (append-map (lambda (arg) (compile-expr arg boxes)) args)
             (list `(call ,(callee->name callee) ,(length args))))]
    [`(binary ,op ,left ,right)
     (append (compile-expr left boxes)
             (compile-expr right boxes)
             (list (binary-op->instruction op)))]
    [_ (vm-error "VM v0 unsupported expression: ~s" expr)]))

(define (compile-box-new name fields boxes)
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
   (append-map (lambda (field-name) (compile-expr (hash-ref values field-name) boxes)) order)
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
  (define value
    (with-handlers ([return-value? return-value-value])
      (run-function program (vm-program-entry program) '() output)
      none-value))
  (vm-run-result value (get-output-string output)))

(define (run-function program fn args output)
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
      [`(div) (set! stack (binary-number stack /))]
      [`(eq) (set! stack (binary-value stack equal?))]
      [`(gt) (set! stack (binary-number stack >))]
      [`(lt) (set! stack (binary-number stack <))]
      [`(call ,name ,argc)
       (define-values (call-args stack*) (pop-args stack argc))
       (set! stack stack*)
       (define call-result (call-vm-function program name call-args output))
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
      [`(drum ,body-code)
       (define count (pop! stack))
       (set! stack (rest stack))
       (unless (and (number? count) (integer? count) (not (negative? count)))
         (vm-error "drum count must be a non-negative integer"))
       (for ([_ (in-range count)])
         (run-code! body-code))]
      [`(return)
       (raise (return-value (pop! stack)))]
      [_ (vm-error "unknown VM instruction: ~s" instruction)]))
  (let loop ()
    (when (>= (frame-ip current) (length (frame-code current)))
      (raise (return-value none-value)))
    (step!)
    (loop)))

(define (call-vm-function program name args output)
  (cond
    [(std-call-skill-name name)
     => (lambda (skill-name)
          (call-vm-function program skill-name args output))]
    [(equal? name "std.io.println")
     (fprintf output "~a\n" (string-join (map value->text args) ""))
     none-value]
    [(equal? name "std.group.count")
     (expect-vm-arg-count name args 1)
     (unless (vm-group-value? (first args))
       (vm-error "std.group.count expects Group"))
     (length (vm-group-value-items (first args)))]
    [(equal? name "std.group.at")
     (expect-vm-arg-count name args 2)
     (define group (first args))
     (define index (second args))
     (unless (vm-group-value? group)
       (vm-error "std.group.at expects Group"))
     (unless (and (number? index) (integer? index))
       (vm-error "std.group.at index must be integer"))
     (unless (and (<= 0 index) (< index (length (vm-group-value-items group))))
       (vm-error "std.group.at index out of range"))
     (list-ref (vm-group-value-items group) index)]
    [(equal? name "host.str.join")
     (string-join (map value->text args) "")]
    [(equal? name "host.str.len")
     (expect-vm-arg-count name args 1)
     (string-length (first args))]
    [(equal? name "host.math.abs")
     (expect-vm-arg-count name args 1)
     (abs (first args))]
    [(equal? name "host.math.round")
     (expect-vm-arg-count name args 1)
     (round (first args))]
    [(hash-has-key? (vm-program-functions program) name)
     (with-handlers ([return-value? return-value-value])
       (run-function program (hash-ref (vm-program-functions program) name) args output))]
    [else (vm-error "VM v0 unknown call '~a'" name)]))

(define (std-call-skill-name name)
  (match name
    ["std.str.add" "std_str_add"]
    ["std.str.len" "std_str_len"]
    ["std.num.abs" "std_num_abs"]
    ["std.num.round" "std_num_round"]
    [_ #f]))

(define (expect-vm-arg-count name args expected)
  (unless (= (length args) expected)
    (vm-error "~a expected ~a args, got ~a" name expected (length args))))

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

(define (binary-value stack proc)
  (define right (pop! stack))
  (define stack* (rest stack))
  (define left (pop! stack*))
  (cons (proc left right) (rest stack*)))

(define (value->text value)
  (cond
    [(eq? value none-value) "none"]
    [(eq? value #t) "yes"]
    [(eq? value #f) "no"]
    [(vm-box-value? value) (format "~a {...}" (vm-box-value-name value))]
    [(vm-group-value? value) (format "Group(~a)" (length (vm-group-value-items value)))]
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
