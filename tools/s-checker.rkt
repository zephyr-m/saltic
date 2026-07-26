#lang racket

(require "s-modules.rkt"
         "s-parser.rkt")

(provide check-s-file
         check-s-string
         check-s-datum
         check-s-file/details
         check-s-string/details
         check-s-datum/details
         diagnostics-empty?
         print-diagnostics
         diagnostics->jsexpr)

(struct scope (vars parent) #:transparent)
(struct result (type diagnostics) #:transparent)
(struct s-diagnostic (level code message line col hint) #:transparent)

(define (check-s-file path)
  (map diagnostic->string (check-s-file/details path)))

(define (check-s-string source)
  (map diagnostic->string (check-s-string/details source)))

(define (check-s-datum ast)
  (map diagnostic->string (check-s-datum/details ast)))

(define (check-s-file/details path)
  (check-s-datum/details (load-s-file-datum/loc path)))

(define (check-s-string/details source)
  (check-s-datum/details (ast->datum/loc (parse-s-string source))))

(define (diagnostics-empty? diagnostics)
  (null? diagnostics))

(define (print-diagnostics diagnostics [out (current-output-port)])
  (for ([diagnostic diagnostics])
    (fprintf out "~a\n" (if (s-diagnostic? diagnostic)
                            (diagnostic->string diagnostic)
                            diagnostic))))

(define (diagnostics->jsexpr diagnostics)
  (hash 'ok (diagnostics-empty? diagnostics)
        'diagnostics (map diagnostic->jsexpr diagnostics)))

(define (check-s-datum/details ast)
  (match ast
    [`(program ,items ...)
     (define-values (globals diagnostics) (collect-globals items))
     (append diagnostics
             (apply append
                    (for/list ([item items])
                      (check-top-level item globals))))]
    [_ (list (diagnostic #f "expected program AST"))]))

(define (collect-globals items)
  (define constants (make-hash))
  (define enums (make-hash))
  (define skills (make-hash))
  (define boxes (make-hash))
  (define imports (make-hash))
  (define entry #f)
  (define diagnostics '())
  (define (define-global! table kind name value)
    (if (or (hash-has-key? constants name)
            (hash-has-key? enums name)
            (hash-has-key? boxes name)
            (hash-has-key? skills name))
        (set! diagnostics
              (cons (diagnostic #f "duplicate top-level name '~a'" name) diagnostics))
        (hash-set! table name value)))
  (for ([item items])
    (match (strip-loc item)
      [`(use ,parts ...)
       (hash-set! imports parts #t)]
      [`(const ,name ,value)
       (define-global! constants 'const name (infer-literalish-type value))]
      [`(box ,name ,fields ...)
       (define-global! boxes 'box name fields)]
      [`(enum ,name ,variants ...)
       (define-global! enums 'enum name variants)]
      [`(entry ,params ,body)
       (if entry
           (set! diagnostics (cons (diagnostic #f "duplicate program entry") diagnostics))
           (set! entry (list params body)))]
      [`(skill ,name ,params ,body)
       (define-global! skills 'skill name params)]
      [_ (void)]))
  (values (hash 'constants constants
                'enums enums
                'boxes boxes
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
    [`(box ,name ,fields ...)
     (check-box-fields name fields globals)]
    [`(enum ,_ ,_ ...) '()]
    [`(entry ,params ,body)
     (check-skill params body globals)]
    [`(skill ,_ ,params ,body)
     (check-skill params body globals)]
    [`(out ,_)
     (list (diagnostic (node-loc item) "'out' can only be used inside skill"))]
    [_ '()]))

(define (check-use parts loc)
  (match parts
    [(or (list "core") (list "core")) '()]
    [_ '()]))

(define (check-box-fields box-name fields globals)
  (define seen (make-hash))
  (define diagnostics '())
  (for ([field fields])
    (match (strip-loc field)
      [`(field ,name ,value)
       (when (hash-has-key? seen name)
         (set! diagnostics
               (cons (diagnostic #f "duplicate field '~a' in Box '~a'" name box-name)
                     diagnostics)))
       (hash-set! seen name #t)
       (set! diagnostics
             (append (result-diagnostics (infer-expr value (make-root-scope) globals))
                     diagnostics))]
      [_ (set! diagnostics (cons (diagnostic #f "malformed Box field") diagnostics))]))
  (reverse diagnostics))

(define (check-skill params body globals)
  (define root (make-root-scope))
  (define diagnostics '())
  (for ([param params])
    (if (scope-has-local? root param)
        (set! diagnostics (cons (diagnostic #f "duplicate parameter '~a'" param) diagnostics))
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
    [_ (list (diagnostic #f "expected block AST"))]))

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
      (if in-skill? '() (list (diagnostic stmt-loc "'out' can only be used inside skill")))
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
                 [_ (list (diagnostic #f "malformed switch case"))]))))]
    [`(drum ,count ,body)
     (append
      (result-diagnostics (infer-expr count env globals))
      (check-block body (make-child-scope env) globals in-skill?))]
    [_ (list (diagnostic stmt-loc "unsupported statement ~s" (strip-loc stmt)))]))

(define (infer-expr expr env globals)
  (define expr-loc (node-loc expr))
  (match (strip-loc expr)
    [`(number ,_) (result 'number '())]
    [`(string ,_) (result 'string '())]
    [`(answer ,_) (result 'answer '())]
    [`(none) (result 'none '())]
    [`(enum-value ,_) (result 'enum-value '())]
    [`(group ,items ...)
     (infer-group items env globals)]
    [`(box-new ,name ,fields ...)
     (infer-box-new name fields env globals expr-loc)]
    [`(path ,parts ...)
     (infer-path parts env globals expr-loc)]
    [`(call ,callee ,args ...)
     (define callee-result (infer-expr callee env globals))
     (define arg-results (map (lambda (arg) (infer-expr arg env globals)) args))
     (result (infer-call-type callee globals arg-results)
             (append (result-diagnostics callee-result)
                     (apply append (map result-diagnostics arg-results))))]
    [`(binary ,op ,left ,right)
     (define left-result (infer-expr left env globals))
     (define right-result (infer-expr right env globals))
     (define diagnostics
       (append (result-diagnostics left-result)
               (result-diagnostics right-result)
               (check-binary-types op (result-type left-result) (result-type right-result))))
     (result (if (comparison-op? op) 'answer (binary-result-type op))
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
       [(hash-has-key? (hash-ref globals 'boxes) name)
        (result 'box-type '())]
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
       [(scope-ref env enum-name)
        => (lambda (type)
             (infer-field-path type (list variant) globals loc))]
       [else
        (result 'unknown '())])]
    [(list name fields ...)
     (cond
       [(member name '("host" "core" "world" "visual" "ui"))
        (infer-module-path parts globals loc)]
       [(scope-ref env name)
        => (lambda (type)
             (infer-field-path type fields globals loc))]
       [(hash-has-key? (hash-ref globals 'constants) name)
        (infer-field-path (hash-ref (hash-ref globals 'constants) name) fields globals loc)]
       [else (result 'unknown '())])]
    [(list "host" _ ...)
     (result 'module-path '())]
    [(list "world" _ ...)
     (result 'module-path '())]
    [(list "core" _ ...)
     (if (core-imported? globals)
         (result 'module-path '())
         (result 'unknown (list (diagnostic loc "module 'core' is not imported; add 'use core'"))))]
    [_ (result 'unknown '())]))

(define (infer-module-path parts globals loc)
  (match parts
    [(list "host" _ ...) (result 'module-path '())]
    [(list "world" _ ...) (result 'module-path '())]
    [(list "visual" _ ...) (result 'module-path '())]
    [(list "ui" _ ...) (result 'module-path '())]
    [(list "core" _ ...)
     (if (core-imported? globals)
         (result 'module-path '())
         (result 'unknown (list (diagnostic loc "module 'core' is not imported; add 'use core'"))))]
    [_ (result 'unknown '())]))

(define (infer-field-path base-type fields globals loc)
  (let loop ([type base-type] [remaining fields])
    (cond
      [(null? remaining) (result type '())]
      [(eq? type 'unknown) (result 'unknown '())]
      [else
       (match type
         [`(box ,box-name)
          (define field-name (first remaining))
          (define field-type (box-field-type box-name field-name globals))
          (if field-type
              (loop field-type (rest remaining))
              (result 'unknown
                      (list (diagnostic loc "Box '~a' has no field '~a'" box-name field-name))))]
         [_ (result 'unknown
                    (list (diagnostic loc
                                      "cannot access field '~a' on ~a"
                                      (first remaining)
                                      (type->string type))))])])))

(define (box-field-type box-name field-name globals)
  (define fields (hash-ref (hash-ref globals 'boxes) box-name #f))
  (and fields
       (for/or ([field fields])
         (match (strip-loc field)
           [`(field ,name ,value)
            (and (equal? name field-name)
                 (infer-literalish-type value))]
           [_ #f]))))

(define (infer-box-new name fields env globals loc)
  (define box-fields (hash-ref (hash-ref globals 'boxes) name #f))
  (cond
    [(not box-fields)
     (result 'unknown (list (diagnostic loc "unknown Box '~a'" name)))]
    [else
     (define field-types
       (for/hash ([field box-fields])
         (match (strip-loc field)
           [`(field ,field-name ,value)
            (values field-name (infer-literalish-type value))]
           [_ (values #f 'unknown)])))
     (define seen (make-hash))
     (define diagnostics '())
     (for ([field fields])
       (match (strip-loc field)
         [`(field ,field-name ,value)
          (when (hash-has-key? seen field-name)
            (set! diagnostics
                  (cons (diagnostic loc "duplicate field '~a' in Box literal '~a'" field-name name)
                        diagnostics)))
          (hash-set! seen field-name #t)
          (define inferred (infer-expr value env globals))
          (define expected (hash-ref field-types field-name #f))
          (set! diagnostics (append (result-diagnostics inferred) diagnostics))
          (cond
            [(not expected)
             (set! diagnostics
                   (cons (diagnostic loc "Box '~a' has no field '~a'" name field-name)
                         diagnostics))]
            [(type-compatible? expected (result-type inferred))
             (void)]
            [else
             (set! diagnostics
                   (cons (diagnostic loc
                                     "cannot assign ~a to field '~a' of Box '~a' with type ~a"
                                     (type->string (result-type inferred))
                                     field-name
                                     name
                                     (type->string expected))
                         diagnostics))])]
         [_ (set! diagnostics (cons (diagnostic loc "malformed Box literal field") diagnostics))]))
     (result `(box ,name) (reverse diagnostics))]))

(define (infer-group items env globals)
  (define item-results (map (lambda (item) (infer-expr item env globals)) items))
  (define diagnostics (apply append (map result-diagnostics item-results)))
  (define item-type
    (for/fold ([current 'unknown])
              ([item-result item-results])
      (merge-type current (result-type item-result))))
  (result `(group ,item-type) diagnostics))

(define (infer-call-type callee globals [arg-results '()])
  (match (strip-loc callee)
    [`(path "host" "io" "println") 'none]
    [`(path "host" "file" "read") 'string]
    [`(path "host" "file" "write") 'none]
    [`(path "host" "json" "encode") 'string]
    [`(path "host" "str" "lines_count") 'number]
    [`(path "host" "str" "lines") '(group string)]
    [`(path "host" "str" "len") 'number]
    [`(path "host" "str" "at") 'string]
    [`(path "host" "str" "slice") 'string]
    [`(path "host" "str" "join") 'string]
    [`(path "host" "str" "eq") 'answer]
    [`(path "host" "str" "contains") 'answer]
    [`(path "host" "str" "trim") 'string]
    [`(path "host" "str" "upper") 'string]
    [`(path "host" "str" "lower") 'string]
    [`(path "host" "str" "split") '(group string)]
    [`(path "host" "math" "parse") 'number]
    [`(path "host" "math" "abs") 'number]
    [`(path "host" "math" "min") 'number]
    [`(path "host" "math" "max") 'number]
    [`(path "host" "math" "round") 'number]
    [`(path "host" "debug" "show") 'none]
    [`(path "core" "io" "println") 'none]
    [`(path "core" "file" "read_text") 'string]
    [`(path "core" "file" "write_text") 'none]
    [`(path "core" "json" "encode") 'string]
    [`(path "core" "str" "lines_count") 'number]
    [`(path "core" "str" "lines") '(group string)]
    [`(path "core" "str" "len") 'number]
    [`(path "core" "str" "at") 'string]
    [`(path "core" "str" "slice") 'string]
    [`(path "core" "str" "join") 'string]
    [`(path "core" "str" "add") 'string]
    [`(path "core" "str" "eq") 'answer]
    [`(path "core" "str" "is_empty") 'answer]
    [`(path "core" "str" "starts_with") 'answer]
    [`(path "core" "str" "ends_with") 'answer]
    [`(path "core" "str" "contains") 'answer]
    [`(path "core" "str" "trim") 'string]
    [`(path "core" "str" "upper") 'string]
    [`(path "core" "str" "lower") 'string]
    [`(path "core" "str" "split") '(group string)]
    [`(path "core" "num" "parse") 'number]
    [`(path "core" "num" "abs") 'number]
    [`(path "core" "num" "min") 'number]
    [`(path "core" "num" "max") 'number]
    [`(path "core" "num" "round") 'number]
    [`(path "core" "group" "count") 'number]
    [`(path "core" "group" "at")
     (match arg-results
       [(list (result `(group ,item-type) _) _)
        item-type]
       [_ 'unknown])]
    [`(path "core" "group" "append")
     (match arg-results
       [(list (result `(group ,item-type) _) (result value-type _))
        `(group ,(merge-type item-type value-type))]
       [_ '(group unknown)])]
    [`(path "world" "spawn") 'unknown]
    [`(path "world" "place") 'none]
    [`(path "world" "move") 'none]
    [`(path "world" "emit") 'none]
    [`(path "world" "step") 'none]
    [`(path "world" "trace") 'none]
    [`(path "world" "trace_text") 'string]
    [`(path "world" "state") 'none]
    [`(path "world" "state_text") 'string]
    [`(path "world" "replay") 'string]
    [`(path "visual" "sheet") 'none]
    [`(path "visual" "grid") 'none]
    [`(path "visual" "square_bipyramid") 'none]
    [`(path "visual" "rotate") 'none]
    [`(path "visual" "present") 'none]
    [`(path "visual" "trace") 'none]
    [`(path "visual" "trace_text") 'string]
    [`(path "ui" "panel") 'none]
    [`(path "ui" "text") 'none]
    [`(path "ui" "field") 'none]
    [`(path "ui" "button") 'none]
    [`(path "ui" "value") 'none]
    [`(path "ui" "present") 'none]
    [`(path "ui" "trace") 'none]
    [`(path "ui" "trace_text") 'string]
    [`(path ,name)
     (if (hash-has-key? (hash-ref globals 'skills) name)
         'unknown
         'unknown)]
    [_ 'unknown]))

(define (core-imported? globals)
  (or (hash-has-key? (hash-ref globals 'imports) '("core"))
      (hash-has-key? (hash-ref globals 'imports) '("core"))))

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
    [_ (result 'unknown (list (diagnostic #f "expected block AST")))]))

(define (check-binary-types op left-type right-type)
  (cond
    [(member op '("+" "-" "*" "/" ">" "<"))
     (cond
       [(or (eq? left-type 'unknown) (eq? right-type 'unknown)) '()]
       [(and (eq? left-type 'number) (eq? right-type 'number)) '()]
       [else
        (list (diagnostic #f
                          "operator '~a' expects numbers, got ~a and ~a"
                          op
                          (type->string left-type)
                          (type->string right-type)))])]
    [else '()]))

(define (binary-result-type op)
  (if (member op '("+" "-" "*" "/")) 'number 'unknown))

(define (comparison-op? op)
  (member op '("==" ">" "<")))

(define (infer-literalish-type expr)
  (match (strip-loc expr)
    [`(number ,_) 'number]
    [`(string ,_) 'string]
    [`(answer ,_) 'answer]
    [`(none) 'none]
    [`(box-new ,name ,_ ...) `(box ,name)]
    [`(group ,items ...)
     (define item-types
       (for/list ([item items])
         (infer-literalish-type item)))
     `(group ,(for/fold ([current 'unknown])
                         ([item-type item-types])
                (merge-type current item-type)))]
    [_ 'unknown]))

(define (top-level-name? globals name)
  (or (hash-has-key? (hash-ref globals 'constants) name)
      (hash-has-key? (hash-ref globals 'enums) name)
      (hash-has-key? (hash-ref globals 'boxes) name)
      (hash-has-key? (hash-ref globals 'skills) name)))

(define (type-compatible? expected actual)
  (or (eq? expected 'unknown)
      (eq? actual 'unknown)
      (equal? expected actual)
      (match (list expected actual)
        [(list `(group ,expected-item) `(group ,actual-item))
         (type-compatible? expected-item actual-item)]
        [_ #f])))

(define (merge-type left right)
  (cond
    [(eq? left 'unknown) right]
    [(eq? right 'unknown) left]
    [(equal? left right) left]
    [(and (pair? left)
          (pair? right)
          (eq? (first left) 'group)
          (eq? (first right) 'group))
     `(group ,(merge-type (second left) (second right)))]
    [else 'unknown]))

(define (type->string type)
  (match type
    [`(enum ,name) (format "enum ~a" name)]
    [`(box ,name) (format "Box ~a" name)]
    [`(group ,item-type) (format "Group ~a" (type->string item-type))]
    ['answer "yes/no"]
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
  (define code (diagnostic-code text))
  (s-diagnostic 'error
                code
                text
                (and loc (car loc))
                (and loc (cdr loc))
                (diagnostic-hint code)))

(define (diagnostic->string diagnostic)
  (if (s-diagnostic? diagnostic)
      (let ([line (s-diagnostic-line diagnostic)]
            [col (s-diagnostic-col diagnostic)]
            [level (s-diagnostic-level diagnostic)]
            [message (s-diagnostic-message diagnostic)])
        (if (and line col)
            (format "~a:~a: ~a: ~a" line col level message)
            (format "~a: ~a" level message)))
      diagnostic))

(define (diagnostic->jsexpr diagnostic)
  (cond
    [(s-diagnostic? diagnostic)
     (define base
       (hash 'level (symbol->string (s-diagnostic-level diagnostic))
             'code (symbol->string (s-diagnostic-code diagnostic))
             'message (s-diagnostic-message diagnostic)))
     (define with-line
       (if (s-diagnostic-line diagnostic)
           (hash-set base 'line (s-diagnostic-line diagnostic))
           base))
     (define with-col
       (if (s-diagnostic-col diagnostic)
           (hash-set with-line 'col (s-diagnostic-col diagnostic))
           with-line))
     (if (s-diagnostic-hint diagnostic)
         (hash-set with-col 'hint (s-diagnostic-hint diagnostic))
         with-col)]
    [else
     (hash 'level "error"
           'code "checker_error"
           'message diagnostic)]))

(define (diagnostic-code message)
  (cond
    [(regexp-match? #rx"^module 'core' is not imported" message) 'core_not_imported]
    [(regexp-match? #rx"^unsupported module" message) 'unsupported_module]
    [(regexp-match? #rx"^unknown name" message) 'unknown_name]
    [(regexp-match? #rx"^variable '.+' is not declared" message) 'variable_not_declared]
    [(regexp-match? #rx"^cannot assign to constant" message) 'constant_assignment]
    [(regexp-match? #rx"^cannot assign .+ to variable" message) 'type_mismatch]
    [(regexp-match? #rx"^duplicate" message) 'duplicate_definition]
    [(regexp-match? #rx"^'out' can only be used inside skill" message) 'out_outside_skill]
    [(regexp-match? #rx"^operator '.+' expects numbers" message) 'operator_type_mismatch]
    [else 'checker_error]))

(define (diagnostic-hint code)
  (match code
    ['core_not_imported "add `use core` at top level"]
    ['variable_not_declared "declare the variable with `@name = value` before assigning to it"]
    ['constant_assignment "constants are immutable; use a local variable for changing values"]
    [_ #f]))
