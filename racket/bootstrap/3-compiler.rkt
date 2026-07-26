#lang racket

(require racket/string
         "1-parser.rkt")

(provide (struct-out vm-program)
         (struct-out vm-function)
         compile-s-file/vm
         compile-s-datum/vm
         vm-program-bytecode
         vm-bytecode->text)

(struct vm-program (functions entry boxes enums) #:transparent)
(struct vm-function (name params code) #:transparent)

(define (compile-s-file/vm path)
  (compile-s-datum/vm (load-s-file-datum path)))

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
  (apply error 'compiler message args))

