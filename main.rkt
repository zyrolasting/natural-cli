#lang racket/base

(require racket/contract)
(provide (contract-out
          [make-subcommand-handlers (-> directory-exists?
                                        string?
                                        (values ((list?) () #:rest list? . ->* . any)
                                                (listof string?)
                                                (-> string? any)
                                                (-> string? any)))]
          [get-program-name (-> path-string? string?)]))

(require racket/format
         racket/path
         racket/set
         racket/string
         racket/vector)


;; Return handlers for use in the first three arguments of a #:handlers
;; clause for (command-line). Shows contextualized help and a means
;; to send control to a subcommand module via dynamic-require.
(define (make-subcommand-handlers cli-directory program-name)
  (define subcommands (get-subcommands cli-directory program-name))
  (define has-subcommands? (> (length subcommands) 0))

  (values
   ; handles arguments by delegating control
   (λ (options . argv)
     (natural-cli-run-subcommand cli-directory program-name (list->vector argv)))

   ; arg strings for the usage line
   (if has-subcommands?
       (list "subcommand" "subcommand-args")
       (list "args"))

   ; Runs when user specifies -h.
   (λ (s)
     (displayln s)
     (when has-subcommands?
       (displayln "where <subcommand> is one of")
       (show-subcommand-help cli-directory program-name subcommands))
     (exit 0))

   ; On unknown flag
   (λ (s)
     (printf "~a: unknown switch: ~a~n" program-name s)
     (exit 1))))


;; > ; When the current directory has "foo_a.rkt" "foo_b.rkt" "foo_b_x.rkt",
;; > (get-subcommands (current-directory) "foo")
;; '("a" "b")
;; > (get-subcommands (current-directory "foo_b"))
;; '("x")
(define (get-subcommands where program-name)
  (set->list
   (for/fold ([working (set)])
             ([relative-path (directory-list where)])
     (define without-ext (path-replace-extension relative-path #""))
     (define as-string (path->string without-ext))
     (if (and (natural-cli-file-name? relative-path)
              (string-prefix? as-string (format "~a_" program-name)))
         (set-add working
                  (car (string-split (string-replace as-string program-name "")
                                     "_")))
         working))))

(define (natural-cli-file-name? name)
  (and (bytes=? (or (path-get-extension name) #"") #".rkt")
       (andmap (λ (x) (regexp-match? #px"^[a-zA-Z0-9-]+$" x))
               (string-split (path->string (path-replace-extension name #"")) "_"))))


(define (get-subcommand-path cli-directory program-name subcommand)
  (build-path cli-directory
              (format "~a_~a.rkt"
                      program-name
                      subcommand)))

(define expected-handler-name 'process-command-line)
(define (natural-cli-run-subcommand cli-directory program-name argv)
  (define subcommands (get-subcommands cli-directory program-name))
  (when (> (length subcommands) 0)
    (unless (> (vector-length argv) 0)
      (printf "~a: Command not specified~n~n" program-name)
      (displayln "Available subcommands:")
      (show-subcommand-help cli-directory program-name subcommands)
      (exit 1))

    (define subcommand (vector-ref argv 0))
    (unless (member subcommand subcommands)
      (printf "~a: `~a` is not a command~n~n" program-name subcommand)
      (displayln "Available subcommands:")
      (show-subcommand-help cli-directory program-name subcommands)
      (exit 1))

    (parameterize ([current-command-line-arguments (vector-drop argv 1)])
      (define path (get-subcommand-path cli-directory program-name subcommand))
      (apply (dynamic-require path
                              expected-handler-name
                              (λ _
                                (printf "Module does not provide ~a~n  path: ~a~n"
                                        expected-handler-name
                                        path)
                                (exit 1)))
             null))))

(define (show-subcommand-help cli-directory program-name subcommands)
  (define longest (apply max (map string-length subcommands)))
  (for/list ([subcmd subcommands])
    (define name-column
      (~a subcmd
          #:align 'right
          #:min-width longest
          #:left-pad-string " "))
    (printf "  ~a: ~a~n"
            name-column
            (dynamic-require (get-subcommand-path cli-directory program-name subcmd)
                             'summary
                             (λ _ "Run with -h for details.")))))

(define (get-program-name path-string)
  (path->string (path-replace-extension path-string #"")))

(module+ test
  (require rackunit)
  (test-case "natural-cli-file-name?"
    (test-true "Simplest case" (natural-cli-file-name? "basic.rkt"))
    (test-true "With subcommand" (natural-cli-file-name? "parent_child.rkt"))
    (test-true "With all allowed characters" (natural-cli-file-name? "parent_Ch1ld.rkt"))
    (test-false "Disallow spaces" (natural-cli-file-name? "sweet sauce.rkt"))
    (test-false "Disallow non-.rkt" (natural-cli-file-name? "sweetsauce.png"))))
