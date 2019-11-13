#lang racket/base


(require racket/cmdline
         launcher/launcher)

(provide process-command-line
         summary)

(define summary "Create racket launchers for modules.")
(module+ main (void (process-command-line)))

(define (process-command-line)
  (define gracket? (make-parameter #f))
  (command-line #:program "natural-cli_mklauncher"
                #:once-each [("-g") "Make GRacket launcher"
                                    (gracket? #t)]
                #:args module-paths
                (for ([user-path module-paths])
                  (define path (path->complete-path user-path))
                  (define-values (dir basename _) (split-path path))
                  (define maker (if (gracket?)
                                    make-gracket-launcher
                                    make-racket-launcher))
                  (maker (list (path->string path))
                         (path-replace-extension basename "")))))

