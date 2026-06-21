#lang racket

(require "s-parser.rkt")

(provide check-s-file
         check-s-string
         check-s-datum
         diagnostics-empty?
         print-diagnostics)

(struct scope (vars parent) #:transparent)
(struct result (type diagnostics) #:transparent)

(define (check-s-file path)
  (check-s-datum (ast->datum/loc (parse-s-file path))))

(define (check-s-string source)
  (check-s-datum (ast->datum/loc (parse-s-string source))))

(define (diagnostics-empty? diagnostics)
  (null? diagnostics))

(define (print-diagnostics diagnostics [out (current-output-port)])
  (for ([diagnostic diagnostics])
    (fprintf out "~a\n" diagnostic)))

(define (check-s-datum ast)
  (match ast
    [`(program ,items ...)
     (define-values (globals diagnostics) (collect-globals items))
     (append diagnostics
             (apply append
                    (for/list ([item items])
                      (check-top-level item globals))))]
    [_ (list "error: expected program AST")]))

(define (collect-globals items)
  (define constants (make-hash))
  (define enums (make-hash))
  (define skills (make-hash))
  (define imports (make-hash))
  (define entry #f)
  (define diagnostics '())
  (define (define-global! table kind name value)
    (if (or (hash-has-key? constants name)
            (hash-has-key? enums name)
            (hash-has-key? skills name))
        (set! diagnostics
              (cons (format "error: duplicate top-level name '~a'" name) diagnostics))
        (hash-set! table name value)))
  (for ([item items])
    (match (strip-loc item)
      [`(use ,parts ...)
       (hash-set! imports parts #t)]
      [`(const ,name ,value)
       (define-global! constants 'const name (infer-literalish-type value))]
      [`(enum ,name ,variants ...)
       (define-global! enums 'enum name variants)]
      [`(entry ,params ,body)
       (if entry
           (set! diagnostics (cons "error: duplicate program entry" diagnostics))
           (set! entry (list params body)))]
      [`(skill ,name ,params ,body)
       (define-global! skills 'skill name params)]
      [_ (void)]))
  (values (hash 'constants constants
                'enums enums
                'skills skills
                'imports imports
                'entry entry)
          (reverse diagnostics)))

(define (check-top-level item globals)
  (match (strip-loc item)
    [`(use ,parts ...)
     (check-use parts (node-loc item))]
    [`(const ,_ ,value)
     (result-diagnostics (infer-expr value (make-root-scope) globals))]
    [`(enum ,_ ,_ ...) '()]
    [`(entry ,params ,body)
     (check-skill params body globals)]
    [`(skill ,_ ,params ,body)
     (check-skill params body globals)]
    [`(out ,_)
     (list "error: 'out' can only be used inside skill")]
    [_ '()]))

(define (check-use parts loc)
  (match parts
    [(list "std") '()]
    [_ (list (diagnostic loc "unsupported module '~a'" (string-join parts ".")))]))

(define (check-skill params body globals)
  (define root (make-root-scope))
  (define diagnostics '())
  (for ([param params])
    (if (scope-has-local? root param)
        (set! diagnostics (cons (format "error: duplicate parameter '~a'" param) diagnostics))
        (scope-define! root param 'unknown)))
  (append (reverse diagnostics)
          (check-block body root globals #t)))

(define (make-root-scope)
  (scope (make-hash) #f))

(define (make-child-scope parent)
  (scope (make-hash) parent))

(define (scope-has-local? env name)
  (hash-has-key? (scope-vars env) name))

(define (scope-define! env name type)
  (hash-set! (scope-vars env) name type))

(define (scope-find env name)
  (cond
    [(not env) #f]
    [(hash-has-key? (scope-vars env) name) env]
    [else (scope-find (scope-parent env) name)]))

(define (scope-ref env name)
  (define owner (scope-find env name))
  (and owner (hash-ref (scope-vars owner) name)))

(define (scope-set! env name type)
  (define owner (scope-find env name))
  (when owner
    (hash-set! (scope-vars owner) name type))
  owner)

(define (check-block block env globals in-skill?)
  (match (strip-loc block)
    [`(block ,items ...)
     (define diagnostics '())
     (for ([item items])
       (set! diagnostics
             (append diagnostics (check-stmt item env globals in-skill?))))
     diagnostics]
    [_ (list "error: expected block AST")]))

(define (check-stmt stmt env globals in-skill?)
  (define stmt-loc (node-loc stmt))
  (match (strip-loc stmt)
    [`(var ,name ,value)
     (define inferred (infer-expr value env globals))
     (append
      (result-diagnostics inferred)
      (cond
        [(scope-has-local? env name)
         (list (diagnostic stmt-loc "variable '~a' is already declared in this scope" name))]
        [(top-level-name? globals name)
         (list (diagnostic stmt-loc "variable '~a' conflicts with top-level name" name))]
        [else
         (scope-define! env name (result-type inferred))
         '()]))]
    [`(assign ,name ,value)
     (define inferred (infer-expr value env globals))
     (append
      (result-diagnostics inferred)
      (cond
        [(hash-has-key? (hash-ref globals 'constants) name)
         (list (diagnostic stmt-loc "cannot assign to constant '~a'" name))]
        [(top-level-name? globals name)
         (list (diagnostic stmt-loc "cannot assign to top-level name '~a'" name))]
        [else
         (define old-type (scope-ref env name))
         (cond
           [(not old-type)
            (list (diagnostic stmt-loc "variable '~a' is not declared" name))]
           [(type-compatible? old-type (result-type inferred))
            (scope-set! env name (merge-type old-type (result-type inferred)))
            '()]
           [else
            (list (diagnostic stmt-loc
                              "cannot assign ~a to variable '~a' of type ~a"
                              (type->string (result-type inferred))
                              name
                              (type->string old-type)))])]))]
    [`(out ,value)
     (append
      (if in-skill? '() (list "error: 'out' can only be used inside skill"))
      (result-diagnostics (infer-expr value env globals)))]
    [`(expr ,value)
     (result-diagnostics (infer-expr value env globals))]
    [`(if ,test ,body)
     (append
      (result-diagnostics (infer-expr test env globals))
      (check-block body (make-child-scope env) globals in-skill?))]
    [`(switch ,value ,cases ...)
     (append
      (result-diagnostics (infer-expr value env globals))
      (apply append
             (for/list ([case cases])
               (match (strip-loc case)
                 [`(case ,_ ,case-value)
                  (result-diagnostics (infer-expr case-value env globals))]
                 [_ (list "error: malformed switch case")]))))]
    [`(drum ,count ,body)
     (append
      (result-diagnostics (infer-expr count env globals))
      (check-block body (make-child-scope env) globals in-skill?))]
    [_ (list (format "error: unsupported statement ~s" stmt))]))

(define (infer-expr expr env globals)
  (define expr-loc (node-loc expr))
  (match (strip-loc expr)
    [`(number ,_) (result 'number '())]
    [`(string ,_) (result 'string '())]
    [`(none) (result 'none '())]
    [`(enum-value ,_) (result 'enum-value '())]
    [`(path ,parts ...)
     (infer-path parts env globals expr-loc)]
    [`(call ,callee ,args ...)
     (define callee-result (infer-expr callee env globals))
     (define arg-results (map (lambda (arg) (infer-expr arg env globals)) args))
     (result (infer-call-type callee globals)
             (append (result-diagnostics callee-result)
                     (apply append (map result-diagnostics arg-results))))]
    [`(binary ,op ,left ,right)
     (define left-result (infer-expr left env globals))
     (define right-result (infer-expr right env globals))
     (define diagnostics
       (append (result-diagnostics left-result)
               (result-diagnostics right-result)
               (check-binary-types op (result-type left-result) (result-type right-result))))
     (result (if (equal? op "==") 'bool (binary-result-type op))
             diagnostics)]
    [`(rescue ,value ,err ,body)
     (define value-result (infer-expr value env globals))
     (define rescue-scope (make-child-scope env))
     (scope-define! rescue-scope err 'error)
     (define body-result (infer-block-value body rescue-scope globals))
     (result (merge-type (result-type value-result) (result-type body-result))
             (append (result-diagnostics value-result)
                     (result-diagnostics body-result)))]
    [_ (result 'unknown (list (diagnostic expr-loc "unsupported expression ~s" (strip-loc expr))))]))

(define (infer-path parts env globals [loc #f])
  (match parts
    [(list name)
     (cond
       [(scope-ref env name) => (lambda (type) (result type '()))]
       [(hash-has-key? (hash-ref globals 'constants) name)
        (result (hash-ref (hash-ref globals 'constants) name) '())]
       [(hash-has-key? (hash-ref globals 'skills) name)
        (result 'function '())]
       [(hash-has-key? (hash-ref globals 'enums) name)
        (result 'enum-type '())]
       [(equal? name "error")
        (result 'error '())]
       [else
        (result 'unknown (list (diagnostic loc "unknown name '~a'" name)))])]
    [(list enum-name variant)
     (cond
       [(hash-has-key? (hash-ref globals 'enums) enum-name)
        (define variants (hash-ref (hash-ref globals 'enums) enum-name))
        (if (member variant variants)
            (result `(enum ,enum-name) '())
            (result 'unknown
                    (list (diagnostic loc
                                      "enum '~a' has no variant '~a'"
                                      enum-name variant))))]
       [(equal? enum-name "error")
        (result 'error '())]
       [else
        (result 'unknown '())])]
    [(list "host" _ ...)
     (result 'module-path '())]
    [(list "world" _ ...)
     (result 'module-path '())]
    [(list "std" _ ...)
     (if (std-imported? globals)
         (result 'module-path '())
         (result 'unknown (list (diagnostic loc "module 'std' is not imported; add 'use std'"))))]
    [_ (result 'unknown '())]))

(define (infer-call-type callee globals)
  (match (strip-loc callee)
    [`(path "host" "io" "println") 'none]
    [`(path "host" "file" "read") 'string]
    [`(path "host" "str" "lines_count") 'number]
    [`(path "host" "str" "len") 'number]
    [`(path "host" "str" "join") 'string]
    [`(path "host" "str" "add") 'string]
    [`(path "host" "str" "eq") 'bool]
    [`(path "host" "str" "contains") 'bool]
    [`(path "host" "str" "trim") 'string]
    [`(path "host" "str" "upper") 'string]
    [`(path "host" "str" "lower") 'string]
    [`(path "host" "math" "abs") 'number]
    [`(path "host" "math" "min") 'number]
    [`(path "host" "math" "max") 'number]
    [`(path "host" "math" "round") 'number]
    [`(path "host" "debug" "show") 'none]
    [`(path "std" "io" "println") 'none]
    [`(path "std" "file" "read_text") 'string]
    [`(path "std" "str" "lines_count") 'number]
    [`(path "std" "str" "len") 'number]
    [`(path "std" "str" "join") 'string]
    [`(path "std" "str" "add") 'string]
    [`(path "std" "str" "eq") 'bool]
    [`(path "std" "str" "contains") 'bool]
    [`(path "std" "str" "trim") 'string]
    [`(path "std" "str" "upper") 'string]
    [`(path "std" "str" "lower") 'string]
    [`(path "std" "num" "abs") 'number]
    [`(path "std" "num" "min") 'number]
    [`(path "std" "num" "max") 'number]
    [`(path "std" "num" "round") 'number]
    [`(path ,name)
     (if (hash-has-key? (hash-ref globals 'skills) name)
         'unknown
         'unknown)]
    [_ 'unknown]))

(define (std-imported? globals)
  (hash-has-key? (hash-ref globals 'imports) '("std")))

(define (infer-block-value block env globals)
  (match (strip-loc block)
    [`(block ,items ...)
     (define diagnostics (check-block block env globals #t))
     (define type
       (match (if (null? items) #f (strip-loc (last items)))
         [`(expr ,value) (result-type (infer-expr value env globals))]
         [`(out ,value) (result-type (infer-expr value env globals))]
         [_ 'none]))
     (result type diagnostics)]
    [_ (result 'unknown (list "error: expected block AST"))]))

(define (check-binary-types op left-type right-type)
  (cond
    [(member op '("+" "-" "*" "/"))
     (cond
       [(or (eq? left-type 'unknown) (eq? right-type 'unknown)) '()]
       [(and (eq? left-type 'number) (eq? right-type 'number)) '()]
       [else
        (list (format "error: operator '~a' expects numbers, got ~a and ~a"
                      op
                      (type->string left-type)
                      (type->string right-type)))])]
    [else '()]))

(define (binary-result-type op)
  (if (member op '("+" "-" "*" "/")) 'number 'unknown))

(define (infer-literalish-type expr)
  (match (strip-loc expr)
    [`(number ,_) 'number]
    [`(string ,_) 'string]
    [`(none) 'none]
    [_ 'unknown]))

(define (top-level-name? globals name)
  (or (hash-has-key? (hash-ref globals 'constants) name)
      (hash-has-key? (hash-ref globals 'enums) name)
      (hash-has-key? (hash-ref globals 'skills) name)))

(define (type-compatible? expected actual)
  (or (eq? expected 'unknown)
      (eq? actual 'unknown)
      (equal? expected actual)))

(define (merge-type left right)
  (cond
    [(eq? left 'unknown) right]
    [(eq? right 'unknown) left]
    [(equal? left right) left]
    [else 'unknown]))

(define (type->string type)
  (match type
    [`(enum ,name) (format "enum ~a" name)]
    [_ (symbol->string type)]))

(define (strip-loc node)
  (match node
    [`(loc ,_ ,_ ,inner) inner]
    [_ node]))

(define (node-loc node)
  (match node
    [`(loc ,line ,col ,_) (cons line col)]
    [_ #f]))

(define (diagnostic loc message . args)
  (define text (apply format message args))
  (if loc
      (format "~a:~a: error: ~a" (car loc) (cdr loc) text)
      (format "error: ~a" text)))
