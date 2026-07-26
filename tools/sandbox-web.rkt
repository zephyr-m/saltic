#lang racket

(require racket/string
         web-server/http
         web-server/http/bindings
         web-server/servlet-env
         "s-checker.rkt"
         "s-runtime.rkt"
         "s-vm.rkt")

(define default-code
  #<<S
use core

program() {
    core.io.println("hello from S")
    out none
}
S
  )

(define (binding-ref req name fallback)
  (define binding
    (bindings-assq (string->bytes/utf-8 name)
                   (request-bindings/raw req)))
  (if (and binding (binding:form? binding))
      (bytes->string/utf-8 (binding:form-value binding))
      fallback))

(define (with-temp-s-file source proc)
  (define path (make-temporary-file "s-sandbox-~a.s"))
  (call-with-output-file path
    #:exists 'truncate
    (lambda (out) (display source out)))
  (dynamic-wind
    void
    (lambda () (proc (path->string path)))
    (lambda ()
      (with-handlers ([exn:fail? void])
        (delete-file path)))))

(define (capture-output proc)
  (define out (open-output-string))
  (define err (open-output-string))
  (define ok?
    (with-handlers ([exn:fail?
                     (lambda (exn)
                       (displayln (exn-message exn) err)
                       #f)])
      (parameterize ([current-output-port out]
                     [current-error-port err])
        (proc))
      #t))
  (values ok? (get-output-string out) (get-output-string err)))

(define (check-file path)
  (define diagnostics (check-s-file path))
  (if (diagnostics-empty? diagnostics)
      (displayln "ok")
      (begin
        (print-diagnostics diagnostics (current-error-port))
        (error 'sandbox "check failed"))))

(define (run-file path args)
  (define diagnostics (check-s-file path))
  (unless (diagnostics-empty? diagnostics)
    (print-diagnostics diagnostics (current-error-port))
    (error 'sandbox "check failed"))
  (run-s-file/args path args))

(define (run-vm-file path)
  (define diagnostics (check-s-file path))
  (unless (diagnostics-empty? diagnostics)
    (print-diagnostics diagnostics (current-error-port))
    (error 'sandbox "check failed"))
  (display (vm-run-result-output (run-s-file/vm path))))

(define (bytecode-file path)
  (define diagnostics (check-s-file path))
  (unless (diagnostics-empty? diagnostics)
    (print-diagnostics diagnostics (current-error-port))
    (error 'sandbox "check failed"))
  (display (vm-bytecode->text (compile-s-file/vm path))))

(define (run-sandbox source mode raw-args)
  (define args (if (equal? (string-trim raw-args) "") '() (string-split raw-args)))
  (with-temp-s-file
   source
   (lambda (path)
     (capture-output
      (lambda ()
        (case (string->symbol mode)
          [(check) (check-file path)]
          [(run) (run-file path args)]
          [(vm) (run-vm-file path)]
          [(bytecode) (bytecode-file path)]
          [else (error 'sandbox "unknown mode: ~a" mode)]))))))

(define (status-class ok?)
  (if ok? "ok" "fail"))

(define (status-text ok?)
  (if ok? "ok" "error"))

(define (app req)
  (define method (request-method req))
  (define posted? (equal? method #"POST"))
  (define source (binding-ref req "source" default-code))
  (define mode (binding-ref req "mode" "run"))
  (define args (binding-ref req "args" ""))
  (define-values (ok? stdout stderr)
    (if posted?
        (run-sandbox source mode args)
        (values #t "" "")))
  (response/xexpr
   `(html
     (head
      (meta ([charset "utf-8"]))
      (title "S sandbox")
      (style "
body { margin: 0; font: 14px system-ui, sans-serif; background: #f5f6f8; color: #1f2328; }
main { display: grid; grid-template-columns: minmax(420px, 1fr) minmax(360px, .8fr); gap: 16px; padding: 16px; min-height: 100vh; box-sizing: border-box; }
h1 { font-size: 18px; margin: 0; }
h2 { font-size: 13px; margin: 0 0 8px; color: #59636e; text-transform: uppercase; letter-spacing: .04em; }
form, section { min-width: 0; }
textarea, pre, input, button { font: 13px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
textarea { width: 100%; height: calc(100vh - 188px); box-sizing: border-box; resize: vertical; background: #ffffff; color: #1f2328; border: 1px solid #ccd2da; padding: 12px; }
input, button { background: #ffffff; color: #1f2328; border: 1px solid #ccd2da; padding: 8px 10px; }
button { cursor: pointer; border-radius: 4px; }
.primary { background: #2563eb; border-color: #2563eb; color: #ffffff; }
.bar { display: flex; gap: 8px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }
.top { justify-content: space-between; }
.commands { display: grid; grid-template-columns: repeat(4, minmax(92px, 1fr)); gap: 8px; margin-bottom: 10px; }
.args { flex: 1; min-width: 180px; }
.status { display: inline-block; padding: 3px 8px; border-radius: 4px; font-weight: 700; }
.mode { color: #59636e; font: 13px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
.ok { background: #dcfce7; color: #166534; }
.fail { background: #fee2e2; color: #991b1b; }
pre { white-space: pre-wrap; overflow: auto; background: #ffffff; border: 1px solid #ccd2da; padding: 12px; min-height: 120px; }
label { color: #59636e; }
@media (max-width: 900px) { main { grid-template-columns: 1fr; } textarea { height: 420px; } }
"))
     (body
      (main
       (form ([method "post"])
             (div ([class "bar top"])
                  (h1 "S sandbox")
                  (span ([class "mode"]) ,(string-append "last: " mode)))
             (h2 "commands")
             (div ([class "commands"])
                  (button ([class "primary"] [type "submit"] [name "mode"] [value "run"]) "Run")
                  (button ([type "submit"] [name "mode"] [value "check"]) "Check")
                  (button ([type "submit"] [name "mode"] [value "vm"]) "VM")
                  (button ([type "submit"] [name "mode"] [value "bytecode"]) "Bytecode"))
             (div ([class "bar"])
                  (input ([class "args"] [name "args"] [value ,args]
                          [placeholder "args for Run mode"])))
             (textarea ([name "source"] [spellcheck "false"]) ,source))
       (section
        (h1 "result " (span ([class ,(string-append "status " (status-class ok?))])
                            ,(status-text ok?)))
        (label "stdout")
        (pre ,stdout)
        (label "stderr")
        (pre ,stderr)))))))

(module+ main
  (define port
    (let ([args (current-command-line-arguments)])
      (if (= (vector-length args) 0)
          8090
          (string->number (vector-ref args 0)))))
  (serve/servlet app
                 #:port port
                 #:servlet-path "/"
                 #:launch-browser? #f
                 #:servlet-regexp #rx""))
