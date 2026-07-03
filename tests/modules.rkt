#lang racket

(require rackunit
         racket/file
         "../tools/s-modules.rkt")

(define (write-module dir name text)
  (define path (build-path dir name))
  (display-to-file text path #:exists 'replace)
  path)

(define module-dir (make-temporary-file "s-modules-~a" 'directory))

(void
 (write-module
  module-dir
  "leaflet.s"
  #<<S
Leaflet = Box {
    kind = "PING"
}
S
  ))

(void
 (write-module
  module-dir
  "actor_a.s"
  #<<S
use leaflet

ActorA = Box {
    leaflet = Leaflet {}
}
S
  ))

(void
 (write-module
  module-dir
  "actor_b.s"
  #<<S
use leaflet

ActorB = Box {
    leaflet = Leaflet {}
}
S
  ))

(define main-path
  (write-module
   module-dir
   "main.s"
   #<<S
use actor_a

use actor_b

program() {
    out none
}
S
   ))

(define expanded (load-s-file-datum main-path))

(define leaflet-count
  (for/sum ([item (cdr expanded)])
    (match item
      [`(box "Leaflet" . ,_) 1]
      [_ 0])))

(check-equal? leaflet-count 1)

(define std-main-path
  (write-module
   module-dir
   "std_main.s"
   #<<S
use core

program() {
    out none
}
S
   ))

(define std-expanded (load-s-file-datum std-main-path))

(check-true
 (for/or ([item (cdr std-expanded)])
   (match item
     [`(skill "std_str_add" . ,_) #t]
     [_ #f])))
