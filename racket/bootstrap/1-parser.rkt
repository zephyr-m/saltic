#lang racket

(require racket/list
         racket/path
         racket/runtime-path
         racket/string)

(provide parse-s-file
         parse-s-string
         ast->datum
         ast->datum/loc
         load-s-file-datum
         load-s-file-datum/loc
         core-module-paths)

(struct tok (kind value line col) #:transparent)
(struct located (node line col) #:transparent)

(struct program (items) #:transparent)
(struct use-decl (path) #:transparent)
(struct const-decl (name value) #:transparent)
(struct box-decl (name fields) #:transparent)
(struct enum-decl (name variants) #:transparent)
(struct entry-decl (params body) #:transparent)
(struct skill-decl (name params body) #:transparent)

(struct var-decl (name value) #:transparent)
(struct assign-stmt (name value) #:transparent)
(struct out-stmt (value) #:transparent)
(struct expr-stmt (value) #:transparent)
(struct block-stmt (items) #:transparent)
(struct if-stmt (test body) #:transparent)
(struct switch-stmt (value cases) #:transparent)
(struct switch-case (tag body) #:transparent)
(struct drum-stmt (count body) #:transparent)

(struct group-expr (items) #:transparent)
(struct rescue-expr (value err body) #:transparent)
(struct binary-expr (op left right) #:transparent)
(struct call-expr (callee args) #:transparent)
(struct box-new-expr (name fields) #:transparent)
(struct path-expr (parts) #:transparent)
(struct enum-value-expr (name) #:transparent)
(struct number-expr (value) #:transparent)
(struct string-expr (value) #:transparent)
(struct answer-expr (value) #:transparent)
(struct none-expr () #:transparent)

(define keywords
  '#hash(("skill" . SKILL)
         ("program" . PROGRAM)
         ("use" . USE)
         ("Box" . BOX)
         ("out" . OUT)
         ("enum" . ENUM)
         ("drum" . DRUM)
         ("rescue" . RESCUE)
         ("yes" . YES)
         ("no" . NO)
         ("none" . NONE)))

(define (parse-s-file path)
  (parse-s-string (file->string path) path))

(define (parse-s-string source [path '<string>])
  (define tokens (lex source path))
  (define-values (ast rest) (parse-program tokens))
  (unless (eq? (tok-kind (peek rest)) 'EOF)
    (parse-error (peek rest) "expected end of file"))
  ast)

(define (lex source path)
  (define len (string-length source))
  (define tokens '())
  (define (emit kind value line col)
    (set! tokens (cons (tok kind value line col) tokens)))
  (let loop ([i 0] [line 1] [col 1])
    (cond
      [(>= i len)
       (reverse (cons (tok 'EOF #f line col) tokens))]
      [else
       (define ch (string-ref source i))
       (cond
         [(or (char=? ch #\space) (char=? ch #\tab) (char=? ch #\return))
          (loop (add1 i) line (add1 col))]
         [(char=? ch #\newline)
          (emit 'NEWLINE "\n" line col)
          (loop (add1 i) (add1 line) 1)]
         [(char-alphabetic? ch)
          (define-values (text next col*) (read-while source i col identifier-char?))
          (emit (hash-ref keywords text 'IDENT) text line col)
          (loop next line col*)]
         [(char-numeric? ch)
          (define-values (text next col*) (read-number source i col))
          (emit 'NUMBER text line col)
          (loop next line col*)]
         [(char=? ch #\")
          (define-values (text next line* col*) (read-string-token source i line col path))
          (emit 'STRING text line col)
          (loop next line* col*)]
         [(and (< (add1 i) len)
               (char=? ch #\=)
               (char=? (string-ref source (add1 i)) #\=))
          (emit 'EQ "==" line col)
          (loop (+ i 2) line (+ col 2))]
         [(and (< (add1 i) len)
               (char=? ch #\=)
               (char=? (string-ref source (add1 i)) #\>))
          (emit 'ARROW "=>" line col)
          (loop (+ i 2) line (+ col 2))]
         [else
          (case ch
            [(#\@) (emit 'AT "@" line col)]
            [(#\{) (emit 'LBRACE "{" line col)]
            [(#\}) (emit 'RBRACE "}" line col)]
            [(#\[) (emit 'LBRACKET "[" line col)]
            [(#\]) (emit 'RBRACKET "]" line col)]
            [(#\() (emit 'LPAREN "(" line col)]
            [(#\)) (emit 'RPAREN ")" line col)]
            [(#\,) (emit 'COMMA "," line col)]
            [(#\.) (emit 'DOT "." line col)]
            [(#\|) (emit 'PIPE "|" line col)]
            [(#\=) (emit 'ASSIGN "=" line col)]
            [(#\>) (emit 'GT ">" line col)]
            [(#\<) (emit 'LT "<" line col)]
            [(#\+) (emit 'PLUS "+" line col)]
            [(#\-) (emit 'MINUS "-" line col)]
            [(#\*) (emit 'STAR "*" line col)]
            [(#\/) (emit 'SLASH "/" line col)]
            [else
             (error 'lex "~a:~a:~a: unexpected character ~v" path line col ch)])
          (loop (add1 i) line (add1 col))])])))

(define (identifier-char? ch)
  (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_)))

(define (read-while source start col pred?)
  (define len (string-length source))
  (let loop ([i start] [col* col] [chars '()])
    (if (and (< i len) (pred? (string-ref source i)))
        (loop (add1 i) (add1 col*) (cons (string-ref source i) chars))
        (values (list->string (reverse chars)) i col*))))

(define (read-number source start col)
  (define len (string-length source))
  (let loop ([i start] [col* col] [chars '()] [seen-dot? #f])
    (cond
      [(>= i len) (values (list->string (reverse chars)) i col*)]
      [else
       (define ch (string-ref source i))
       (cond
         [(char-numeric? ch)
          (loop (add1 i) (add1 col*) (cons ch chars) seen-dot?)]
         [(and (char=? ch #\.) (not seen-dot?)
               (< (add1 i) len)
               (char-numeric? (string-ref source (add1 i))))
          (loop (add1 i) (add1 col*) (cons ch chars) #t)]
         [else
          (values (list->string (reverse chars)) i col*)])])))

(define (read-string-token source start line col path)
  (define len (string-length source))
  (let loop ([i (add1 start)] [line* line] [col* (add1 col)] [chars '()])
    (cond
      [(>= i len)
       (error 'lex "~a:~a:~a: unterminated string" path line col)]
      [else
       (define ch (string-ref source i))
       (cond
         [(char=? ch #\")
          (values (list->string (reverse chars)) (add1 i) line* (add1 col*))]
         [(char=? ch #\\)
          (when (>= (add1 i) len)
            (error 'lex "~a:~a:~a: unterminated escape" path line* col*))
          (define next (string-ref source (add1 i)))
          (define decoded
            (case next
              [(#\n) #\newline]
              [(#\t) #\tab]
              [(#\") #\"]
              [(#\\) #\\]
              [else next]))
          (loop (+ i 2) line* (+ col* 2) (cons decoded chars))]
         [(char=? ch #\newline)
          (loop (add1 i) (add1 line*) 1 (cons ch chars))]
         [else
          (loop (add1 i) line* (add1 col*) (cons ch chars))])])))

(define (peek tokens) (car tokens))
(define (advance tokens) (cdr tokens))
(define (token? tokens kind) (eq? (tok-kind (peek tokens)) kind))

(define (skip-newlines tokens)
  (if (token? tokens 'NEWLINE)
      (skip-newlines (advance tokens))
      tokens))

(define (parse-error token message)
  (error 'parse "~a:~a: ~a, got ~a"
         (tok-line token)
         (tok-col token)
         message
         (tok-kind token)))

(define (expect tokens kind [message #f])
  (if (token? tokens kind)
      (values (peek tokens) (advance tokens))
      (parse-error (peek tokens) (or message (format "expected ~a" kind)))))

(define (expect-ident tokens [message "expected identifier"])
  (if (token? tokens 'IDENT)
      (values (tok-value (peek tokens)) (advance tokens))
      (parse-error (peek tokens) message)))

(define (parse-program tokens)
  (let loop ([tokens (skip-newlines tokens)] [items '()])
    (cond
      [(token? tokens 'EOF)
       (values (program (reverse items)) tokens)]
      [else
       (define-values (item rest) (parse-top-level tokens))
       (loop (skip-newlines rest) (cons item items))])))

(define (parse-top-level tokens)
  (cond
    [(token? tokens 'USE) (parse-use tokens)]
    [(token? tokens 'PROGRAM) (parse-entry tokens)]
    [(token? tokens 'SKILL) (parse-skill tokens)]
    [(and (token? tokens 'IDENT) (token? (advance tokens) 'ASSIGN)
          (token? (advance (advance tokens)) 'BOX))
     (parse-box tokens)]
    [(and (token? tokens 'IDENT) (token? (advance tokens) 'ASSIGN)
          (token? (advance (advance tokens)) 'ENUM))
     (parse-enum tokens)]
    [(token? tokens 'IDENT) (parse-const tokens)]
    [else (parse-error (peek tokens) "expected top-level declaration")]))

(define (parse-use tokens)
  (define start (peek tokens))
  (define-values (_use t1) (expect tokens 'USE))
  (define-values (path rest) (parse-path t1))
  (values (locate (use-decl (path-expr-parts (located-node path))) start) rest))

(define (parse-entry tokens)
  (define start (peek tokens))
  (define-values (_program t1) (expect tokens 'PROGRAM))
  (define-values (_lp t2) (expect t1 'LPAREN "expected ( after program"))
  (define-values (params t3) (parse-param-list t2))
  (define-values (_rp t4) (expect t3 'RPAREN))
  (define-values (body rest) (parse-block t4))
  (values (locate (entry-decl params body) start) rest))

(define (parse-const tokens)
  (define start (peek tokens))
  (define-values (name t1) (expect-ident tokens))
  (define-values (_eq t2) (expect t1 'ASSIGN))
  (define-values (value rest) (parse-expression t2))
  (values (locate (const-decl name value) start) rest))

(define (parse-box tokens)
  (define start (peek tokens))
  (define-values (name t1) (expect-ident tokens))
  (define-values (_eq t2) (expect t1 'ASSIGN))
  (define-values (_box t3) (expect t2 'BOX))
  (define-values (fields rest) (parse-field-block t3 "expected field name"))
  (values (locate (box-decl name fields) start) rest))

(define (parse-enum tokens)
  (define start (peek tokens))
  (define-values (name t1) (expect-ident tokens))
  (define-values (_eq t2) (expect t1 'ASSIGN))
  (define-values (_enum t3) (expect t2 'ENUM))
  (define-values (_lb t4) (expect t3 'LBRACE))
  (let loop ([tokens (skip-newlines t4)] [variants '()])
    (cond
      [(token? tokens 'RBRACE)
       (values (locate (enum-decl name (reverse variants)) start) (advance tokens))]
      [else
       (define-values (variant t1) (expect-ident tokens "expected enum variant"))
       (define rest (if (token? t1 'COMMA) (advance t1) t1))
       (loop (skip-newlines rest) (cons variant variants))])))

(define (parse-skill tokens)
  (define start (peek tokens))
  (define-values (_skill t1) (expect tokens 'SKILL))
  (define-values (name t2) (expect-ident t1 "expected skill name"))
  (define-values (_lp t3) (expect t2 'LPAREN))
  (define-values (params t4) (parse-param-list t3))
  (define-values (_rp t5) (expect t4 'RPAREN))
  (define-values (body rest) (parse-block t5))
  (values (locate (skill-decl name params body) start) rest))

(define (parse-param-list tokens)
  (cond
    [(token? tokens 'RPAREN) (values '() tokens)]
    [else
     (let loop ([tokens tokens] [params '()])
       (define-values (param t1) (expect-ident tokens "expected parameter name"))
       (cond
         [(token? t1 'COMMA)
          (loop (advance t1) (cons param params))]
         [else
          (values (reverse (cons param params)) t1)]))]))

(define (parse-block tokens)
  (define start (peek tokens))
  (define-values (_lb t1) (expect tokens 'LBRACE))
  (let loop ([tokens (skip-newlines t1)] [items '()])
    (cond
      [(token? tokens 'RBRACE)
       (values (locate (block-stmt (reverse items)) start) (advance tokens))]
      [(token? tokens 'EOF)
       (parse-error (peek tokens) "expected }")]
      [else
       (define-values (stmt rest) (parse-statement tokens))
       (loop (skip-newlines rest) (cons stmt items))])))

(define (parse-statement tokens)
  (cond
    [(token? tokens 'AT) (parse-var-decl tokens)]
    [(token? tokens 'OUT) (parse-out tokens)]
    [(token? tokens 'DRUM) (parse-drum tokens)]
    [(token? tokens 'LPAREN) (parse-paren-block-stmt tokens)]
    [(and (token? tokens 'IDENT) (token? (advance tokens) 'ASSIGN))
     (parse-assign tokens)]
    [else
     (define-values (expr rest) (parse-expression tokens))
     (values (expr-stmt expr) rest)]))

(define (parse-var-decl tokens)
  (define start (peek tokens))
  (define-values (_at t1) (expect tokens 'AT))
  (define-values (name t2) (expect-ident t1 "expected variable name"))
  (define-values (_eq t3) (expect t2 'ASSIGN "expected = after variable name"))
  (define-values (value rest) (parse-expression t3))
  (values (locate (var-decl name value) start) rest))

(define (parse-assign tokens)
  (define start (peek tokens))
  (define-values (name t1) (expect-ident tokens))
  (define-values (_eq t2) (expect t1 'ASSIGN))
  (define-values (value rest) (parse-expression t2))
  (values (locate (assign-stmt name value) start) rest))

(define (parse-out tokens)
  (define start (peek tokens))
  (define-values (_out t1) (expect tokens 'OUT))
  (define-values (value rest) (parse-expression t1))
  (values (locate (out-stmt value) start) rest))

(define (parse-drum tokens)
  (define start (peek tokens))
  (define-values (_drum t1) (expect tokens 'DRUM))
  (define-values (_lp t2) (expect t1 'LPAREN "expected ( after drum"))
  (define-values (count t3) (parse-expression t2))
  (define-values (_rp t4) (expect t3 'RPAREN))
  (define-values (body rest) (parse-block t4))
  (values (locate (drum-stmt count body) start) rest))

(define (parse-paren-block-stmt tokens)
  (define start (peek tokens))
  (define-values (_lp t1) (expect tokens 'LPAREN))
  (define-values (expr t2) (parse-expression t1))
  (define-values (_rp t3) (expect t2 'RPAREN))
  (define-values (_lb t4) (expect t3 'LBRACE))
  (define body-start (skip-newlines t4))
  (if (token? body-start 'DOT)
      (parse-switch-tail expr body-start start)
      (parse-if-tail expr body-start start)))

(define (parse-if-tail expr tokens start)
  (let loop ([tokens (skip-newlines tokens)] [items '()])
    (cond
      [(token? tokens 'RBRACE)
       (values (locate (if-stmt expr (locate (block-stmt (reverse items)) start)) start) (advance tokens))]
      [else
       (define-values (stmt rest) (parse-statement tokens))
       (loop (skip-newlines rest) (cons stmt items))])))

(define (parse-switch-tail expr tokens start)
  (let loop ([tokens (skip-newlines tokens)] [cases '()])
    (cond
      [(token? tokens 'RBRACE)
       (values (locate (switch-stmt expr (reverse cases)) start) (advance tokens))]
      [else
       (define case-start (peek tokens))
       (define-values (_dot t1) (expect tokens 'DOT))
       (define-values (tag t2) (expect-ident t1 "expected switch case tag"))
       (define-values (_arrow t3) (expect t2 'ARROW))
       (define-values (value t4) (parse-expression t3))
       (define rest (if (token? t4 'COMMA) (advance t4) t4))
       (loop (skip-newlines rest) (cons (locate (switch-case tag value) case-start) cases))])))

(define (parse-expression tokens)
  (define-values (expr rest) (parse-binary tokens 0))
  (if (token? rest 'RESCUE)
      (parse-rescue expr rest)
      (values expr rest)))

(define precedences
  '#hash((EQ . 1)
         (GT . 1)
         (LT . 1)
         (PLUS . 2)
         (MINUS . 2)
         (STAR . 3)
         (SLASH . 3)))

(define (parse-binary tokens min-prec)
  (define-values (left rest) (parse-postfix tokens))
  (let loop ([left left] [tokens rest])
    (define kind (tok-kind (peek tokens)))
    (define prec (hash-ref precedences kind #f))
    (if (and prec (>= prec min-prec))
        (let ([op-token (peek tokens)])
          (let-values ([(right rest*) (parse-binary (advance tokens) (add1 prec))])
            (loop (locate (binary-expr (tok-value op-token) left right) op-token) rest*)))
        (values left tokens))))

(define (parse-postfix tokens)
  (define-values (expr rest) (parse-primary tokens))
  (let loop ([expr expr] [tokens rest])
    (cond
      [(token? tokens 'LPAREN)
       (define start (peek tokens))
       (define-values (args rest*) (parse-args tokens))
       (loop (locate (call-expr expr args) start) rest*)]
      [(and (path-expr? (located-node expr))
            (= (length (path-expr-parts (located-node expr))) 1)
            (token? tokens 'LBRACE))
       (define start (peek tokens))
       (define-values (fields rest*) (parse-field-block tokens "expected field name"))
       (loop (locate (box-new-expr (first (path-expr-parts (located-node expr))) fields) start) rest*)]
      [else
       (values expr tokens)])))

(define (parse-field-block tokens field-message)
  (define-values (_lb t1) (expect tokens 'LBRACE))
  (let loop ([tokens (skip-newlines t1)] [fields '()])
    (cond
      [(token? tokens 'RBRACE)
       (values (reverse fields) (advance tokens))]
      [(token? tokens 'EOF)
       (parse-error (peek tokens) "expected }")]
      [else
       (define-values (field t2) (expect-ident tokens field-message))
       (define-values (_eq t3) (expect t2 'ASSIGN "expected = after field name"))
       (define-values (value t4) (parse-expression t3))
       (define rest (if (token? t4 'COMMA) (advance t4) t4))
       (loop (skip-newlines rest) (cons (list field value) fields))])))

(define (parse-args tokens)
  (define-values (_lp t1) (expect tokens 'LPAREN))
  (cond
    [(token? t1 'RPAREN) (values '() (advance t1))]
    [else
     (let loop ([tokens t1] [args '()])
       (define-values (arg t2) (parse-expression tokens))
       (cond
         [(token? t2 'COMMA) (loop (advance t2) (cons arg args))]
         [else
          (define-values (_rp rest) (expect t2 'RPAREN))
          (values (reverse (cons arg args)) rest)]))]))

(define (parse-rescue value tokens)
  (define start (peek tokens))
  (define-values (_rescue t1) (expect tokens 'RESCUE))
  (define-values (_pipe1 t2) (expect t1 'PIPE))
  (define-values (err t3) (expect-ident t2 "expected rescue error name"))
  (define-values (_pipe2 t4) (expect t3 'PIPE))
  (define-values (body rest) (parse-block t4))
  (values (locate (rescue-expr value err body) start) rest))

(define (parse-primary tokens)
  (cond
    [(token? tokens 'NUMBER)
     (values (locate (number-expr (string->number (tok-value (peek tokens)))) (peek tokens)) (advance tokens))]
    [(token? tokens 'STRING)
     (values (locate (string-expr (tok-value (peek tokens))) (peek tokens)) (advance tokens))]
    [(token? tokens 'YES)
     (values (locate (answer-expr #t) (peek tokens)) (advance tokens))]
    [(token? tokens 'NO)
     (values (locate (answer-expr #f) (peek tokens)) (advance tokens))]
    [(token? tokens 'NONE)
     (values (locate (none-expr) (peek tokens)) (advance tokens))]
    [(token? tokens 'DOT)
     (define start (peek tokens))
     (define-values (_dot t1) (expect tokens 'DOT))
     (define-values (name rest) (expect-ident t1 "expected enum value"))
     (values (locate (enum-value-expr name) start) rest)]
    [(token? tokens 'LBRACKET)
     (parse-group tokens)]
    [(token? tokens 'IDENT)
     (parse-path tokens)]
    [(token? tokens 'LPAREN)
     (define-values (_lp t1) (expect tokens 'LPAREN))
     (define-values (expr t2) (parse-expression t1))
     (define-values (_rp rest) (expect t2 'RPAREN))
     (values expr rest)]
    [else
     (parse-error (peek tokens) "expected expression")]))

(define (parse-group tokens)
  (define start (peek tokens))
  (define-values (_lb t1) (expect tokens 'LBRACKET))
  (let loop ([tokens (skip-newlines t1)] [items '()])
    (cond
      [(token? tokens 'RBRACKET)
       (values (locate (group-expr (reverse items)) start) (advance tokens))]
      [(token? tokens 'EOF)
       (parse-error (peek tokens) "expected ]")]
      [else
       (define-values (item t2) (parse-expression tokens))
       (define rest (if (token? t2 'COMMA) (advance t2) t2))
       (loop (skip-newlines rest) (cons item items))])))

(define (parse-path tokens)
  (define start (peek tokens))
  (define-values (first t1) (expect-ident tokens))
  (let loop ([tokens t1] [parts (list first)])
    (cond
      [(and (token? tokens 'DOT) (token? (advance tokens) 'IDENT))
       (define-values (_dot t2) (expect tokens 'DOT))
       (define-values (part t3) (expect-ident t2))
       (loop t3 (append parts (list part)))]
      [else
       (values (locate (path-expr parts) start) tokens)])))

(define (locate node token)
  (located node (tok-line token) (tok-col token)))

(define (ast->datum ast)
  (cond
    [(located? ast) (ast->datum (located-node ast))]
    [(program? ast) `(program ,@(map ast->datum (program-items ast)))]
    [(use-decl? ast) `(use ,@(use-decl-path ast))]
    [(const-decl? ast) `(const ,(const-decl-name ast) ,(ast->datum (const-decl-value ast)))]
    [(box-decl? ast) `(box ,(box-decl-name ast)
                           ,@(map (lambda (field)
                                     `(field ,(first field) ,(ast->datum (second field))))
                                   (box-decl-fields ast)))]
    [(enum-decl? ast) `(enum ,(enum-decl-name ast) ,@(enum-decl-variants ast))]
    [(entry-decl? ast) `(entry ,(entry-decl-params ast) ,(ast->datum (entry-decl-body ast)))]
    [(skill-decl? ast) `(skill ,(skill-decl-name ast) ,(skill-decl-params ast)
                              ,(ast->datum (skill-decl-body ast)))]
    [(var-decl? ast) `(var ,(var-decl-name ast) ,(ast->datum (var-decl-value ast)))]
    [(assign-stmt? ast) `(assign ,(assign-stmt-name ast) ,(ast->datum (assign-stmt-value ast)))]
    [(out-stmt? ast) `(out ,(ast->datum (out-stmt-value ast)))]
    [(expr-stmt? ast) `(expr ,(ast->datum (expr-stmt-value ast)))]
    [(block-stmt? ast) `(block ,@(map ast->datum (block-stmt-items ast)))]
    [(if-stmt? ast) `(if ,(ast->datum (if-stmt-test ast)) ,(ast->datum (if-stmt-body ast)))]
    [(switch-stmt? ast) `(switch ,(ast->datum (switch-stmt-value ast))
                                 ,@(map ast->datum (switch-stmt-cases ast)))]
    [(switch-case? ast) `(case ,(switch-case-tag ast) ,(ast->datum (switch-case-body ast)))]
    [(drum-stmt? ast) `(drum ,(ast->datum (drum-stmt-count ast)) ,(ast->datum (drum-stmt-body ast)))]
    [(group-expr? ast) `(group ,@(map ast->datum (group-expr-items ast)))]
    [(rescue-expr? ast) `(rescue ,(ast->datum (rescue-expr-value ast))
                                 ,(rescue-expr-err ast)
                                 ,(ast->datum (rescue-expr-body ast)))]
    [(binary-expr? ast) `(binary ,(binary-expr-op ast)
                                 ,(ast->datum (binary-expr-left ast))
                                 ,(ast->datum (binary-expr-right ast)))]
    [(call-expr? ast) `(call ,(ast->datum (call-expr-callee ast))
                             ,@(map ast->datum (call-expr-args ast)))]
    [(box-new-expr? ast) `(box-new ,(box-new-expr-name ast)
                                   ,@(map (lambda (field)
                                           `(field ,(first field) ,(ast->datum (second field))))
                                         (box-new-expr-fields ast)))]
    [(path-expr? ast) `(path ,@(path-expr-parts ast))]
    [(enum-value-expr? ast) `(enum-value ,(enum-value-expr-name ast))]
    [(number-expr? ast) `(number ,(number-expr-value ast))]
    [(string-expr? ast) `(string ,(string-expr-value ast))]
    [(answer-expr? ast) `(answer ,(if (answer-expr-value ast) "yes" "no"))]
    [(none-expr? ast) '(none)]
    [else ast]))

(define (ast->datum/loc ast)
  (cond
    [(located? ast)
     `(loc ,(located-line ast) ,(located-col ast) ,(ast->datum/loc (located-node ast)))]
    [(program? ast) `(program ,@(map ast->datum/loc (program-items ast)))]
    [(use-decl? ast) `(use ,@(use-decl-path ast))]
    [(const-decl? ast) `(const ,(const-decl-name ast) ,(ast->datum/loc (const-decl-value ast)))]
    [(box-decl? ast) `(box ,(box-decl-name ast)
                           ,@(map (lambda (field)
                                     `(field ,(first field) ,(ast->datum/loc (second field))))
                                   (box-decl-fields ast)))]
    [(enum-decl? ast) `(enum ,(enum-decl-name ast) ,@(enum-decl-variants ast))]
    [(entry-decl? ast) `(entry ,(entry-decl-params ast) ,(ast->datum/loc (entry-decl-body ast)))]
    [(skill-decl? ast) `(skill ,(skill-decl-name ast) ,(skill-decl-params ast)
                              ,(ast->datum/loc (skill-decl-body ast)))]
    [(var-decl? ast) `(var ,(var-decl-name ast) ,(ast->datum/loc (var-decl-value ast)))]
    [(assign-stmt? ast) `(assign ,(assign-stmt-name ast) ,(ast->datum/loc (assign-stmt-value ast)))]
    [(out-stmt? ast) `(out ,(ast->datum/loc (out-stmt-value ast)))]
    [(expr-stmt? ast) `(expr ,(ast->datum/loc (expr-stmt-value ast)))]
    [(block-stmt? ast) `(block ,@(map ast->datum/loc (block-stmt-items ast)))]
    [(if-stmt? ast) `(if ,(ast->datum/loc (if-stmt-test ast)) ,(ast->datum/loc (if-stmt-body ast)))]
    [(switch-stmt? ast) `(switch ,(ast->datum/loc (switch-stmt-value ast))
                                 ,@(map ast->datum/loc (switch-stmt-cases ast)))]
    [(switch-case? ast) `(case ,(switch-case-tag ast) ,(ast->datum/loc (switch-case-body ast)))]
    [(drum-stmt? ast) `(drum ,(ast->datum/loc (drum-stmt-count ast)) ,(ast->datum/loc (drum-stmt-body ast)))]
    [(group-expr? ast) `(group ,@(map ast->datum/loc (group-expr-items ast)))]
    [(rescue-expr? ast) `(rescue ,(ast->datum/loc (rescue-expr-value ast))
                                 ,(rescue-expr-err ast)
                                 ,(ast->datum/loc (rescue-expr-body ast)))]
    [(binary-expr? ast) `(binary ,(binary-expr-op ast)
                                 ,(ast->datum/loc (binary-expr-left ast))
                                 ,(ast->datum/loc (binary-expr-right ast)))]
    [(call-expr? ast) `(call ,(ast->datum/loc (call-expr-callee ast))
                             ,@(map ast->datum/loc (call-expr-args ast)))]
    [(box-new-expr? ast) `(box-new ,(box-new-expr-name ast)
                                   ,@(map (lambda (field)
                                             `(field ,(first field) ,(ast->datum/loc (second field))))
                                           (box-new-expr-fields ast)))]
    [(path-expr? ast) `(path ,@(path-expr-parts ast))]
    [(enum-value-expr? ast) `(enum-value ,(enum-value-expr-name ast))]
    [(number-expr? ast) `(number ,(number-expr-value ast))]
    [(string-expr? ast) `(string ,(string-expr-value ast))]
    [(answer-expr? ast) `(answer ,(if (answer-expr-value ast) "yes" "no"))]
    [(none-expr? ast) '(none)]
    [else ast]))

(define-runtime-path core-root "../../core")
(define-runtime-path project-root "../..")

(define core-module-files
  '("file.s"
    "json.s"
    "str.s"
    "num.s"
    "group.s"))

(define (core-module-paths)
  (for/list ([core-file core-module-files])
    (build-path core-root core-file)))

(define (load-s-file-datum path)
  (expand-file path ast->datum))

(define (load-s-file-datum/loc path)
  (expand-file path ast->datum/loc))

(define (expand-file path ast->datum-proc)
  (define normalized (simplify-path path))
  (define included (make-hash))
  (define items (expand-file-items normalized ast->datum-proc '() included))
  `(program ,@items))

(define (expand-file-items path ast->datum-proc stack included)
  (define normalized (simplify-path path))
  (when (member normalized stack equal?)
    (error 'modules "cyclic import involving ~a" normalized))
  (if (hash-has-key? included normalized)
      '()
      (begin
        (hash-set! included normalized #t)
        (let ([ast (ast->datum-proc (parse-s-file normalized))])
          (match ast
            [`(program ,items ...)
             (apply append
                    (for/list ([item items])
                      (match (strip-loc item)
                        [`(use "core")
                         (append
                          (list item)
                          (apply append
                                 (for/list ([core-path (core-module-paths)])
                                   (expand-file-items core-path
                                                      ast->datum-proc
                                                      (cons normalized stack)
                                                      included))))]
                        [`(use ,parts ...)
                         (append
                          (list item)
                          (expand-file-items (resolve-module-path normalized parts)
                                             ast->datum-proc
                                             (cons normalized stack)
                                             included))]
                        [_ (list item)])))]
            [_ (error 'modules "expected program AST in ~a" normalized)])))))

(define (strip-loc item)
  (match item
    [`(loc ,_ ,_ ,inner) inner]
    [_ item]))

(define (resolve-module-path source-path parts)
  (if (equal? (first parts) "s")
      (resolve-system-module parts)
      (resolve-local-module source-path parts)))

(define (resolve-system-module parts)
  (define relative
    (apply build-path
           (append (map string->path (drop-right parts 1))
                   (list (string->path (format "~a.s" (last parts)))))))
  (define resolved (simplify-path (build-path project-root relative)))
  (unless (file-exists? resolved)
    (error 'modules "system module '~a' not found at ~a"
           (string-join parts ".")
           resolved))
  resolved)

(define (resolve-local-module source-path parts)
  (define base (or (path-only source-path) (current-directory)))
  (define relative
    (apply build-path
           (append (map string->path (drop-right parts 1))
                   (list (string->path (format "~a.s" (last parts)))))))
  (define resolved (simplify-path (build-path base relative)))
  (unless (file-exists? resolved)
    (error 'modules "module '~a' not found at ~a"
           (string-join parts ".")
           resolved))
  resolved)

(module+ main
  (define args (current-command-line-arguments))
  (when (not (= (vector-length args) 1))
    (eprintf "usage: racket racket/bootstrap/1-parser.rkt <file.s>\n")
    (exit 2))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (eprintf "~a\n" (exn-message exn))
                     (exit 1))])
    (pretty-write (ast->datum (parse-s-file (vector-ref args 0))))))
