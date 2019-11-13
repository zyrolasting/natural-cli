#lang racket/base

(provide summary
         process-command-line)
(require racket/cmdline
         racket/port
         racket/runtime-path
         "../main.rkt")

(define summary "Creates command-line modules.")
(module+ main (void (process-command-line)))

(define-runtime-path skel-file "../skel.rkt")

(define (process-command-line)
  (command-line
   #:program "natural-cli_mkmodule"
   #:usage-help "Generates module code to handle a command line"
   #:args paths
   (for ([path paths])
     (call-with-output-file path
       (λ (to-target)
         (call-with-input-file
           skel-file
           (λ (from-skel) (copy-port from-skel to-target))))))))
