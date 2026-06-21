#lang racket

(require racket/list
         racket/string
         "s-parser.rkt")

(provide explain-s-file
         explain-s-string
         explain-s-datum)

(define (explain-s-file path)
  (explain-s-datum (ast->datum (parse-s-file path)) path))

(define (explain-s-string source)
  (explain-s-datum (ast->datum (parse-s-string source))))

(define (explain-s-datum ast [name #f])
  (define summary (summarize-program ast))
  (string-append
   (format "S explain~a\n" (if name (format ": ~a" name) ""))
   (format "top-level: ~a constants, ~a enums, ~a skills, ~a program\n"
           (length (hash-ref summary 'constants))
           (length (hash-ref summary 'enums))
           (length (hash-ref summary 'skills))
           (if (hash-ref summary 'entry) 1 0))
   "\n"
   (section "constants" (hash-ref summary 'constants))
   (section "enums" (hash-ref summary 'enums))
   (section "skills" (hash-ref summary 'skills))
   (entry-section (hash-ref summary 'entry))
   (section "host calls" (sort (hash-ref summary 'host-calls) string<?))
   (section "world actions" (sort (hash-ref summary 'world-actions) string<?))))

(define (summarize-program ast)
  (match ast
    [`(program ,items ...)
     (define constants '())
     (define enums '())
     (define skills '())
     (define entry #f)
     (define host-calls '())
     (define world-actions '())
     (for ([item items])
       (match item
         [`(const ,name ,_) (set! constants (cons name constants))]
         [`(enum ,name ,variants ...)
          (set! enums (cons (format "~a {~a}" name (string-join variants ", ")) enums))]
         [`(skill ,name ,params ,body)
          (set! skills (cons (format "~a(~a)" name (string-join params ", ")) skills))
          (define calls (collect-calls body))
          (set! host-calls (append (filter host-call? calls) host-calls))
          (set! world-actions (append (filter world-call? calls) world-actions))]
         [`(entry ,params ,body)
          (set! entry (format "program(~a)" (string-join params ", ")))
          (define calls (collect-calls body))
          (set! host-calls (append (filter host-call? calls) host-calls))
          (set! world-actions (append (filter world-call? calls) world-actions))]
         [_ (void)]))
     (hash 'constants (reverse constants)
           'enums (reverse enums)
           'skills (reverse skills)
           'entry entry
           'host-calls (remove-duplicates host-calls string=?)
           'world-actions (remove-duplicates world-actions string=?))]
    [_ (error 'explain "expected program AST")]))

(define (collect-calls node)
  (match node
    [`(call (path ,parts ...) ,args ...)
     (cons (string-join parts ".")
           (append-map collect-calls args))]
    [(list items ...)
     (append-map collect-calls items)]
    [_ '()]))

(define (host-call? call)
  (string-prefix? call "host."))

(define (world-call? call)
  (string-prefix? call "world."))

(define (section title items)
  (string-append
   title
   ":\n"
   (if (null? items)
       "  - none\n\n"
       (string-append
        (string-join (map (lambda (item) (format "  - ~a" item)) items) "\n")
        "\n\n"))))

(define (entry-section entry)
  (string-append
   "entry:\n"
   (if entry
       (format "  - ~a\n\n" entry)
       "  - none\n\n")))
