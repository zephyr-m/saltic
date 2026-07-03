#lang racket

(require racket/string
         "s-modules.rkt"
         "s-parser.rkt")

(provide machine-trace-file
         machine-trace-string
         machine-trace-datum)

(define (machine-trace-file path)
  (machine-trace-datum (load-s-file-datum path)))

(define (machine-trace-string source)
  (machine-trace-datum (ast->datum (parse-s-string source))))

(define (machine-trace-datum ast)
  (define raw-lines (machine-trace-lines ast))
  (string-append
   (string-join
    (for/list ([line raw-lines]
               [index (in-naturals 1)])
      (format "step ~a: ~a" index line))
    "\n")
   "\n"))

(define (machine-trace-lines ast)
  (match ast
    [`(program ,items ...)
     (define skills (collect-skills items))
     (define entry (collect-entry items))
     (unless entry
       (error 'machine-trace "missing program entry"))
     (match entry
       [(list params body)
        (append
         (list (format "enter program(~a)" (string-join params ", ")))
         (trace-block body skills)
         (list "halt"))])]
    [_ (error 'machine-trace "expected program AST")]))

(define (collect-skills items)
  (define skills (make-hash))
  (for ([item items])
    (match item
      [`(skill ,name ,params ,body)
       (hash-set! skills name (list params body))]
      [_ (void)]))
  skills)

(define (collect-entry items)
  (for/or ([item items])
    (match item
      [`(entry ,params ,body) (list params body)]
      [_ #f])))

(define (trace-block block skills)
  (match block
    [`(block ,items ...)
     (append-map (lambda (item) (trace-stmt item skills)) items)]
    [_ (error 'machine-trace "expected block AST")]))

(define (trace-stmt stmt skills)
  (match stmt
    [`(var ,name ,value)
     (append (list (format "bind ~a = ~a" name (expr->text value)))
             (trace-expr-effects value skills))]
    [`(assign ,name ,value)
     (append (list (format "set ~a = ~a" name (expr->text value)))
             (trace-expr-effects value skills))]
    [`(expr ,value)
     (trace-expr value skills)]
    [`(out ,value)
     (list (format "return ~a" (expr->text value)))]
    [`(if ,test ,body)
     (append (list (format "branch if ~a" (expr->text test)))
             (trace-block body skills))]
    [`(switch ,value ,cases ...)
     (cons (format "choice ~a" (expr->text value))
           (append-map
            (lambda (case)
              (match case
                [`(case ,tag ,case-value)
                 (cons (format "case .~a" tag)
                       (trace-expr case-value skills))]
                [_ (list "malformed case")]))
            cases))]
    [`(drum ,count ,body)
     (append (list (format "drum ~a" (expr->text count)))
             (trace-block body skills))]
    [_ (list (format "unsupported statement ~s" stmt))]))

(define (trace-expr expr skills)
  (match expr
    [`(call (path ,parts ...) ,args ...)
     (trace-call parts args skills)]
    [_ (trace-expr-effects expr skills)]))

(define (trace-expr-effects expr skills)
  (match expr
    [`(call (path ,parts ...) ,args ...)
     (trace-call parts args skills)]
    [`(group ,items ...)
     (append-map (lambda (item) (trace-expr-effects item skills)) items)]
    [`(box-new ,_ ,fields ...)
     (append-map
      (lambda (field)
        (match field
          [`(field ,_ ,value) (trace-expr-effects value skills)]
          [_ '()]))
      fields)]
    [`(binary ,_ ,left ,right)
     (append (trace-expr-effects left skills)
             (trace-expr-effects right skills))]
    [`(rescue ,value ,_ ,body)
     (append (trace-expr-effects value skills)
             (trace-block body skills))]
    [_ '()]))

(define (trace-call parts args skills)
  (define name (string-join parts "."))
  (define args-text (string-join (map expr->text args) ", "))
  (match parts
    [(list skill-name)
     #:when (hash-has-key? skills skill-name)
     (match (hash-ref skills skill-name)
       [(list params body)
        (append
         (list (format "call ~a(~a)" skill-name args-text)
               (format "enter ~a(~a)" skill-name (string-join params ", ")))
         (trace-block body skills))])]
    [(list "host" _ ...)
     (list (format "effect ~a(~a)" name args-text))]
    [(list "core" _ ...)
     (list (format "effect ~a(~a)" name args-text))]
    [(list "world" _ ...)
     (list (format "effect ~a(~a)" name args-text))]
    [(list "visual" _ ...)
     (list (format "effect ~a(~a)" name args-text))]
    [_ (list (format "call ~a(~a)" name args-text))]))

(define (expr->text expr)
  (match expr
    [`(number ,value) (number->string value)]
    [`(string ,value) (format "~s" value)]
    [`(answer ,value) value]
    [`(none) "none"]
    [`(enum-value ,name) (format ".~a" name)]
    [`(path ,parts ...) (string-join parts ".")]
    [`(call (path ,parts ...) ,args ...)
     (format "~a(~a)"
             (string-join parts ".")
             (string-join (map expr->text args) ", "))]
    [`(box-new ,name ,fields ...)
     (if (null? fields)
         (format "~a {}" name)
         (format "~a { ... }" name))]
    [`(group ,items ...)
     (format "[~a]" (string-join (map expr->text items) ", "))]
    [`(binary ,op ,left ,right)
     (format "~a ~a ~a" (expr->text left) op (expr->text right))]
    [`(rescue ,value ,_ ,_)
     (format "~a rescue ..." (expr->text value))]
    [_ (format "~s" expr)]))
