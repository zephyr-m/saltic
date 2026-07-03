#lang racket

(require racket/list
         racket/string
         "s-modules.rkt"
         "s-parser.rkt")

(provide explain-s-file
         explain-s-string
         explain-s-datum
         explain-s-file/details
         explain-s-string/details
         explain-s-datum/details
         explanation->jsexpr)

(define (explain-s-file path)
  (explain-s-datum (load-s-file-datum path) path))

(define (explain-s-string source)
  (explain-s-datum (ast->datum (parse-s-string source))))

(define (explain-s-file/details path)
  (explain-s-datum/details (load-s-file-datum path) path))

(define (explain-s-string/details source)
  (explain-s-datum/details (ast->datum (parse-s-string source))))

(define (explain-s-datum ast [name #f])
  (explanation->text (explain-s-datum/details ast name)))

(define (explain-s-datum/details ast [name #f])
  (define summary (summarize-program ast))
  (hash 'name (and name (name->string name))
        'top-level (hash 'constants (length (hash-ref summary 'constants))
                         'enums (length (hash-ref summary 'enums))
                         'skills (length (hash-ref summary 'skills))
                         'program (if (hash-ref summary 'entry) 1 0))
        'imports (hash-ref summary 'imports)
        'constants (hash-ref summary 'constants)
        'enums (hash-ref summary 'enums)
        'skills (hash-ref summary 'skills)
        'entry (hash-ref summary 'entry)
        'calls (hash 'core (sort (hash-ref summary 'core-calls) string<?)
                     'host (sort (hash-ref summary 'host-calls) string<?)
                     'world (sort (hash-ref summary 'world-actions) string<?)
                     'visual (sort (hash-ref summary 'visual-actions) string<?)
                     'ui (sort (hash-ref summary 'ui-actions) string<?))))

(define (name->string name)
  (cond
    [(path? name) (path->string name)]
    [else (format "~a" name)]))

(define (explanation->jsexpr explanation)
  (hash 'ok #t
        'explanation explanation))

(define (explanation->text explanation)
  (define top-level (hash-ref explanation 'top-level))
  (define calls (hash-ref explanation 'calls))
  (string-append
   (format "S explain~a\n" (if (hash-ref explanation 'name)
                                (format ": ~a" (hash-ref explanation 'name))
                                ""))
   (format "top-level: ~a constants, ~a enums, ~a skills, ~a program\n"
           (hash-ref top-level 'constants)
           (hash-ref top-level 'enums)
           (hash-ref top-level 'skills)
           (hash-ref top-level 'program))
   "\n"
   (section "imports" (hash-ref explanation 'imports))
   (section "constants" (hash-ref explanation 'constants))
   (section "enums" (hash-ref explanation 'enums))
   (section "skills" (hash-ref explanation 'skills))
   (entry-section (hash-ref explanation 'entry))
   (section "core calls" (hash-ref calls 'core))
   (section "host calls" (hash-ref calls 'host))
   (section "world actions" (hash-ref calls 'world))
   (section "visual actions" (hash-ref calls 'visual))
   (section "ui actions" (hash-ref calls 'ui))))

(define (summarize-program ast)
  (match ast
    [`(program ,items ...)
     (define constants '())
     (define imports '())
     (define enums '())
     (define skills '())
     (define entry #f)
     (define core-calls '())
     (define host-calls '())
     (define world-actions '())
     (define visual-actions '())
     (define ui-actions '())
     (for ([item items])
       (match item
         [`(use ,parts ...)
          (set! imports (cons (string-join parts ".") imports))]
         [`(const ,name ,_) (set! constants (cons name constants))]
         [`(enum ,name ,variants ...)
          (set! enums (cons (format "~a {~a}" name (string-join variants ", ")) enums))]
         [`(skill ,name ,params ,body)
          (unless (std-internal-skill? name)
            (set! skills (cons (format "~a(~a)" name (string-join params ", ")) skills))
            (define calls (collect-calls body))
            (set! core-calls (append (filter core-call? calls) core-calls))
            (set! host-calls (append (filter host-call? calls) host-calls))
            (set! world-actions (append (filter world-call? calls) world-actions))
            (set! visual-actions (append (filter visual-call? calls) visual-actions))
            (set! ui-actions (append (filter ui-call? calls) ui-actions)))]
         [`(entry ,params ,body)
          (set! entry (format "program(~a)" (string-join params ", ")))
          (define calls (collect-calls body))
          (set! core-calls (append (filter core-call? calls) core-calls))
          (set! host-calls (append (filter host-call? calls) host-calls))
          (set! world-actions (append (filter world-call? calls) world-actions))
          (set! visual-actions (append (filter visual-call? calls) visual-actions))
          (set! ui-actions (append (filter ui-call? calls) ui-actions))]
         [_ (void)]))
     (hash 'imports (reverse imports)
           'constants (reverse constants)
           'enums (reverse enums)
           'skills (reverse skills)
           'entry entry
           'core-calls (remove-duplicates core-calls string=?)
           'host-calls (remove-duplicates host-calls string=?)
           'world-actions (remove-duplicates world-actions string=?)
           'visual-actions (remove-duplicates visual-actions string=?)
           'ui-actions (remove-duplicates ui-actions string=?))]
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

(define (std-internal-skill? name)
  (string-prefix? name "std_"))

(define (core-call? call)
  (string-prefix? call "core."))

(define (world-call? call)
  (string-prefix? call "world."))

(define (visual-call? call)
  (string-prefix? call "visual."))

(define (ui-call? call)
  (string-prefix? call "ui."))

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
