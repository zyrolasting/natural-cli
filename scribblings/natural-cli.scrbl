#lang scribble/manual
@require[@for-label[natural-cli
                    racket/base                   
                    racket/cmdline
                    racket/contract
                    mzlib/etc]]

@title{Write Large CLIs Easily}
@author{Sage Gerard}

@defmodule[natural-cli]

This collection helps you write non-trivial command-line interfaces (CLIs).

If you want to put together a simple CLI or offer a single level of
subcommands, then don't use this. Just use @racketmodname[racket/cmdline].

Use @racketmodname[natural-cli] if you have subcommands that
have subcommands that have subcommands, and are constantly
iterating on the interface's design. In this situation,
the CLI's structure is a distraction and you'll need
help managing it.


@section{Quick Start}

After installing, run the following:

@verbatim[#:indent 4]|{
$ mkdir cli && cd cli
$ natural-cli mkmodule olympian.rkt
$ racket olympian.rkt
}|

You just made a command module that supports subcommands (See @secref{clm} for details).

To add a subcommand, make a new module with an underscore separating
the command name from the subcommand name.

@verbatim[#:indent 4]|{
$ natural-cli mkmodule olympian_jump.rkt
}|

@margin-note{The code duplication you'll observe is intentional. In practice, each module needs to evolve independently.}

If you run @tt{olympian.rkt} again, you'll see @tt{jump} as a subcommand.

You can keep adding deeper subcommands.

@verbatim[#:indent 4]|{
$ natural-cli mkmodule olympian_jump_high.rkt olympian_jump_far.rkt
}|

If your shell supports brace expansion, you can express command trees succiently.
You do not have to run this command. It's only here as a quick tip.

@verbatim[#:indent 4]|{
$ natural-cli mkmodule olympian_run{_{fast,slow},}.rkt
}|

For polish, you can create a Racket launcher using
the @tt{mklauncher} command. If you want a GRacket
launcher, use the @tt{-g} switch.

@verbatim[#:indent 4]|{
$ natural-cli mklauncher olympian.rkt
$ ./olympian
$ ./olympian jump
$ ./olympian jump high
$ ./olympian jump far
}|

Each module created using @tt{natural-cli mkmodule} is eligible for
use in @racket[racket-launcher-libraries] or @racket[gracket-launcher-libraries]
in @tt{info.rkt}.

To recap on what we observed:

@itemlist[
@item{Underscores separate parent commands from subcommands.}
@item{These modules must all be @tt{.rkt} files sitting in the same directory.}
@item{Every possible command in the command tree must have a module.}
]


@section{Flag Handling}

@racketmodname[natural-cli] scopes flags to their associated commands.
This allows you to pass flags between commands to configure behavior
at different levels of a program.

@verbatim[#:indent 4]|{
$ ./olympian --home Germany jump far --start-distance 20m
}|

This means that a flag's position matters between commands and subcommands.
Here we cover the implications.


@subsection{Getting Help}

@racketmodname[racket/cmdline] reserves the @tt{-h} flag for
requesting help, and normally exits after doing so.

You can request help for different commands by moving the @tt{-h} flag.

@verbatim[#:indent 4]|{
$ ./olympian jump high -h
$ ./olympian jump -h high
$ ./olympian -h jump high
}|

The exit behavior prevents any subcommands from running, so any additional
@tt{-h} or subcommand following the first @tt{-h} will have no
effect.

You can configure the behavior of @tt{-h} using
@racket[#:handlers] in @racket[command-line] in the associated module.

@subsection{Example: Illustrating Command Scope}

To show how flags are scoped to subsets of a command line,
we'll review how two flags of the same name are subject to
the rules of different parsers.

Here's a @tt{config.rkt} that holds dynamic runtime data
shared between commands.

@racketmod[#:file "config.rkt"
racket/base
(provide (all-defined-out))
(define top (make-parameter 0))
(define sub (make-parameter 0))
]

Next, let's run @tt{natural-cli mkmodule top.rkt top_sub.rkt}
and edit each new file as follows:

@racketmod[#:file "top.rkt"
racket/base
(provide process-command-line)
(require "./config.rkt")

(module+ main (void (process-command-line)))

(require racket/cmdline
         racket/runtime-path
         (only-in mzlib/etc this-expression-file-name)
         natural-cli)

(define program-name
  (get-program-name (this-expression-file-name)))
(define-runtime-path cli-directory ".")

(define (process-command-line)
  (define-values (fin arg-strs help unknown)
    (make-subcommand-handlers cli-directory program-name))
  (command-line #:program program-name
                #:multi
                [("-a") "Increment top" (top (add1 (top)))]
                #:handlers fin arg-strs help unknown))]

@racketmod[#:file "sub.rkt"
racket/base
(provide process-command-line summary)
(require "./config.rkt")

(define summary "Prints counters.")

(require racket/cmdline
         racket/runtime-path
         (only-in mzlib/etc this-expression-file-name)
         natural-cli)

(define program-name
  (get-program-name (this-expression-file-name)))
(define-runtime-path cli-directory ".")

(define (process-command-line)
  (command-line #:program program-name
                #:once-each
                [("-a") "Increment sub"
                        (sub (add1 (sub)))]
                #:args _
                (printf "~a ~a~n" (top) (sub))))]

Notice that @tt{top} allows multiple uses of @tt{-a} with @racket[#:multi], and
@tt{sub} uses @racket[#:once-each].

For this collection, this session holds:

@verbatim[#:indent 4]|{
$ ./top sub -a
0 1
$ ./top -a sub
1 0
$ ./top -a sub -a
1 1
$ ./top -a -a sub -a
2 1
$ ./top -a sub -a -a
top_sub: the -a option can only be specified once
}|

@section{Tweaking the CLI}

The @tt{mkmodule} command writes code that is coupled to the file
system. So long as that code is preserved, you can design a CLI by
changing files.

To remove a subcommand from a project, just delete its file.

@verbatim[#:indent 4]|{
$ rm olympian_jump_high.rkt
}|

To add a command, run @tt{natural-cli mkmodule} as discussed
or copy an existing module for later editing.

@verbatim[#:indent 4]|{
$ natural-cli mkmodule olympian_throw.rkt # or...
$ cp olympian_jump.rkt olympian_throw.rkt
}|

To rename a command, rename the file.

@verbatim[#:indent 4]|{
$ mv olympian_swim.rkt olympian_dive.rkt
}|

To move a command under a different parent, rename the file.

@verbatim[#:indent 4]|{
$ mv olympian_jump_far.rkt olympian_throw_far.rkt
}|

For more advanced cases, use batch renaming.


@section[#:tag "clm"]{Command Modules}

Each Racket module managed by @racketmodname[natural-cli]
should @racket[(provide process-command-line summary)].

@defthing[summary string?]{
A one-line summary of the command's intended function. This will appear
in help strings of a parent command.

If not provided, this will default to @racket{Run with -h for details.}
}

@defproc[(process-command-line) any/c]{
A procedure that may use @racketmodname[racket/cmdline] as it wishes.
When control enters this procedure, @racket[current-command-line-arguments]
will hold only the options, switches, and arguments meant for that
command.

If not provided, this will default to a procedure that announces a missing
implementation and evaluates @racket[(exit 1)].
}

@section{API Reference}

@racket[(require natural-cli)] offers bindings that cooperate
with code created by @tt{natural-cli mkmodule}.

@defproc[(make-subcommand-handlers [cli-directory directory-exists?]
                                   [program-name string?])
                                   (values ((list?) () #:rest list? . ->* . any)
                                           (listof string?)
                                           (string? . -> . any)
                                           (string? . -> . any))]{
Returns (in the order shown), a @racket[finish-expr], a
@racket[arg-strings-expr], a @racket[help-expr], and a
@racket[unknown-expr] for use in the @racket[#:handlers] clause of
@racket[command-line]. You can modify these values, but you need
@racket[finish-expr] to transfer control to subcommands.

@racket[finish-expr] dynamically instantiates the command module
referenced by the first positional (non-flag) argument from the
command line.
}

@defproc[(get-program-name [source-file path-string?]) string?]{
Returns the canonical program name based on a path string of the calling module file.
}
