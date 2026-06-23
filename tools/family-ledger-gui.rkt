#lang racket

(require racket/date
         racket/gui/base
         racket/list
         racket/match
         racket/string
         "s-runtime.rkt")

(define source-path "examples/apps/family-ledger/ui.s")
(define ledger-path "examples/apps/family-ledger/ledger.txt")

(define (ledger-trace)
  (with-output-to-string
    (lambda ()
      (run-s-file/args source-path (list ledger-path)))))

(define (trace-values trace)
  (for/hash ([line (in-list (filter non-empty-string? (string-split trace "\n")))]
             #:when (string-prefix? line "value "))
    (match (string-split line)
      [(list "value" name value ...)
       (values name (string-join value " "))]
      [_ (values "unknown" "")])))

(define (today-text)
  (define now (seconds->date (current-seconds)))
  (format "~a-~a-~a"
          (date-year now)
          (~r (date-month now) #:min-width 2 #:pad-string "0")
          (~r (date-day now) #:min-width 2 #:pad-string "0")))

(define (append-entry! kind amount label)
  (define clean-kind (string-trim kind))
  (define clean-amount (string-trim amount))
  (define clean-label (string-trim label))
  (when (or (string=? clean-amount "")
            (not (string->number clean-amount)))
    (error 'family-ledger-gui "amount must be a number"))
  (define final-label
    (if (string=? clean-label "") "entry" (string-replace clean-label " " "_")))
  (call-with-output-file ledger-path
    (lambda (out)
      (fprintf out "~a ~a ~a ~a\n" clean-kind (today-text) clean-amount final-label))
    #:exists 'append))

(define frame
  (new frame%
       [label "S Family Ledger"]
       [width 560]
       [height 420]))

(define root
  (new vertical-panel%
       [parent frame]
       [alignment '(left top)]
       [border 18]
       [spacing 12]))

(new message%
     [parent root]
     [label "Family ledger"])

(define form
  (new horizontal-panel%
       [parent root]
       [alignment '(left center)]
       [spacing 8]))

(define kind-choice
  (new choice%
       [parent form]
       [label "Kind"]
       [choices '("income" "expense" "debt")]))

(define amount-field
  (new text-field%
       [parent form]
       [label "Amount"]
       [min-width 120]))

(define label-field
  (new text-field%
       [parent form]
       [label "Label"]
       [min-width 160]))

(define status-message
  (new message%
       [parent root]
       [label ""]))

(define values-panel
  (new vertical-panel%
       [parent root]
       [alignment '(left top)]
       [spacing 6]))

(define value-messages (make-hash))

(define (value-message name)
  (hash-ref!
   value-messages
   name
   (lambda ()
     (new message%
          [parent values-panel]
          [label ""]))))

(define (refresh!)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (send status-message set-label (format "error: ~a" (exn-message exn))))])
    (define values (trace-values (ledger-trace)))
    (for ([name (in-list '("income" "expenses" "debt" "free" "status"))])
      (define key name)
      (define value (hash-ref values key "0"))
      (send (value-message key) set-label (format "~a: ~a" key value)))
    (send status-message set-label "ready")))

(new button%
     [parent root]
     [label "Add"]
     [callback
      (lambda (_button _event)
        (with-handlers ([exn:fail?
                         (lambda (exn)
                           (send status-message set-label
                                 (format "error: ~a" (exn-message exn))))])
          (append-entry! (send kind-choice get-string-selection)
                         (send amount-field get-value)
                         (send label-field get-value))
          (send amount-field set-value "")
          (send label-field set-value "")
          (refresh!)))])

(refresh!)
(send frame show #t)

