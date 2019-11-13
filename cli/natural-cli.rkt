#lang racket/base

(provide process-command-line summary)
(require racket/cmdline racket/runtime-path "../main.rkt")

(define-runtime-path cli-directory ".")
(define summary "Write large CLIs easily.")
(define program-name "natural-cli")
(module+ main (void (process-command-line)))

(define (process-command-line)
  (define-values (final-expr arg-strings-expr help-expr unknown-expr)
    (make-subcommand-handlers cli-directory program-name))
  (command-line #:program program-name
                #:handlers final-expr arg-strings-expr help-expr unknown-expr))

