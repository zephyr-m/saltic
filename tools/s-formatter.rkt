#lang racket

(require racket/string
         "s-parser.rkt")

(provide format-s-file
         format-s-string
         format-s-datum)

(define indent-width 4)

(define (format-s-file path)
  (format-s-datum (ast->datum (parse-s-file path))))

(define (format-s-string source)
  (format-s-datum (ast->datum (parse-s-string source))))

(define (format-s-datum ast)
  (string-append (format-program ast) "\n"))

(define (format-program ast)
  (match ast
    [`(program ,items ...)
     (string-join (map format-top-level items) "\n\n")]
    [_ (formatter-error "expected program AST")]))

(define (format-top-level item)
  (match item
    [`(use ,parts ...)
     (format "use ~a" (string-join parts "."))]
    [`(const ,name ,value)
     (format "~a = ~a" name (format-expr value))]
    [`(box ,name ,fields ...)
     (string-append
      (format "~a = Box {\n" name)
      (string-join
       (for/list ([field fields])
         (format-box-field field 1))
       "\n")
      "\n}")]
    [`(enum ,name ,variants ...)
     (string-append
      (format "~a = enum {\n" name)
      (string-join
       (for/list ([variant variants])
         (format "~a~a," (indent 1) variant))
       "\n")
      "\n}")]
    [`(entry ,params ,body)
     (format "program(~a) ~a"
             (string-join params ", ")
             (format-block body 0))]
    [`(skill ,name ,params ,body)
     (format "skill ~a(~a) ~a"
             name
             (string-join params ", ")
             (format-block body 0))]
    [_ (formatter-error "unsupported top-level item: ~s" item)]))

(define (format-block block level)
  (match block
    [`(block ,items ...)
     (cond
       [(null? items) "{}"]
       [else
        (string-append
         "{\n"
         (string-join
          (map (lambda (stmt) (format-stmt stmt (add1 level))) items)
          "\n")
         "\n"
         (indent level)
         "}")])]
    [_ (formatter-error "expected block AST")]))

(define (format-stmt stmt level)
  (match stmt
    [`(var ,name ,value)
     (format "~a@~a = ~a" (indent level) name (format-expr value level))]
    [`(assign ,name ,value)
     (format "~a~a = ~a" (indent level) name (format-expr value level))]
    [`(out ,value)
     (format "~aout ~a" (indent level) (format-expr value level))]
    [`(expr ,value)
     (format "~a~a" (indent level) (format-expr value level))]
    [`(if ,test ,body)
     (format "~a(~a) ~a"
             (indent level)
             (format-expr test)
             (format-block body level))]
    [`(switch ,value ,cases ...)
     (string-append
      (format "~a(~a) {\n" (indent level) (format-expr value))
      (string-join
       (map (lambda (case) (format-switch-case case (add1 level))) cases)
       "\n")
      "\n"
      (indent level)
      "}")]
    [`(drum ,count ,body)
     (format "~adrum (~a) ~a"
             (indent level)
             (format-expr count)
             (format-block body level))]
    [_ (formatter-error "unsupported statement: ~s" stmt)]))

(define (format-switch-case case level)
  (match case
    [`(case ,tag ,value)
     (format "~a.~a => ~a," (indent level) tag (format-expr value level))]
    [_ (formatter-error "malformed switch case: ~s" case)]))

(define (format-expr expr [level 0])
  (format-expr/prec expr level 0 'none))

(define (format-expr/prec expr level parent-prec side)
  (match expr
    [`(number ,value) (number->string value)]
    [`(string ,value) (format "~s" value)]
    [`(answer ,value) value]
    [`(none) "none"]
    [`(enum-value ,name) (format ".~a" name)]
    [`(group ,items ...)
     (format-group items level)]
    [`(path ,parts ...) (string-join parts ".")]
    [`(call ,callee ,args ...)
     (define text
       (format "~a(~a)"
               (format-expr/prec callee level 5 'left)
               (string-join (map (lambda (arg) (format-expr arg level)) args) ", ")))
     (maybe-parenthesize text 5 parent-prec side)]
    [`(box-new ,name ,fields ...)
     (format-box-new name fields level)]
    [`(binary ,op ,left ,right)
     (define prec (binary-precedence op))
     (define text
       (format "~a ~a ~a"
               (format-expr/prec left level prec 'left)
               op
               (format-expr/prec right level prec 'right)))
     (maybe-parenthesize text prec parent-prec side)]
    [`(rescue ,value ,err ,body)
     (define text
       (format "~a rescue |~a| ~a"
               (format-expr/prec value level 1 'left)
               err
               (format-block body level)))
     (maybe-parenthesize text 1 parent-prec side)]
    [_ (formatter-error "unsupported expression: ~s" expr)]))

(define (binary-precedence op)
  (match op
    [(or "*" "/") 4]
    [(or "+" "-") 3]
    [(or "==" ">" "<") 2]
    [_ 2]))

(define (format-box-field field level)
  (match field
    [`(field ,name ,value)
     (format "~a~a = ~a" (indent level) name (format-expr value level))]
    [_ (formatter-error "malformed box field: ~s" field)]))

(define (format-box-new name fields level)
  (cond
    [(null? fields) (format "~a {}" name)]
    [else
     (string-append
      (format "~a {\n" name)
      (string-join
       (for/list ([field fields])
         (format-box-field field (add1 level)))
       "\n")
      "\n"
      (indent level)
      "}")]))

(define (format-group items level)
  (cond
    [(null? items) "[]"]
    [else
     (string-append
      "[\n"
      (string-join
       (for/list ([item items])
         (format "~a~a," (indent (add1 level)) (format-expr item (add1 level))))
       "\n")
      "\n"
      (indent level)
      "]")]))

(define (maybe-parenthesize text prec parent-prec side)
  (if (or (< prec parent-prec)
          (and (eq? side 'right) (= prec parent-prec)))
      (format "(~a)" text)
      text))

(define (indent level)
  (make-string (* indent-width level) #\space))

(define (formatter-error message . args)
  (apply error 'format message args))
