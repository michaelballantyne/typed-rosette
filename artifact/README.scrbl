#lang scribble/manual

@require[scribble/eval
         scriblib/autobib
         racket/list]

@(define HOME (find-system-path 'home-dir))
@(define REPO (apply build-path (drop-right (explode-path (current-directory)) 1)))
@(define ARTIFACT (build-path REPO "artifact"))
@(define TURNSTILE (build-path REPO "turnstile"))
@(define MACROTYPES (build-path REPO "macrotypes"))
@(define DOCS (build-path TURNSTILE "doc" "turnstile" "index.html"))
@(define GUIDE (build-path TURNSTILE "doc" "turnstile" "The_Turnstile_Guide.html"))
@(define REF (build-path TURNSTILE "doc" "turnstile" "The_Turnstile_Reference.html"))
@(define POPL-EXAMPLES (build-path ARTIFACT "examples"))
@(define RACKET-EXAMPLES (build-path MACROTYPES "examples"))
@(define TURNSTILE-EXAMPLES (build-path TURNSTILE "examples"))
@(define TURNSTILE-TEST (build-path TURNSTILE-EXAMPLES "tests"))
@(define MLISH-TEST (build-path TURNSTILE-TEST "mlish"))

@(define PAPER-TITLE  "Symbolic Types for Lenient Symbolic Execution")
@(define PAPER-PDF  "paper.pdf")
@(define PAPER (build-path ARTIFACT PAPER-PDF))

@(define REPO-URL "https://github.com/stchang/typed-rosette")
@(define POPL-URL "http://www.ccs.neu.edu/home/stchang/popl2018")
@(define VM-URL (string-append POPL-URL "/" "typed-rosette.ova"))

@(define (file:// p) ;; Path -> String
   (string-append "file://" (path->string p)))

@(define (file-url prefix [suffix #f]) ;; Path (U String #f) -> Elem
   (define p (if suffix (build-path prefix suffix) prefix))
   (hyperlink (file:// p) (tt (if suffix suffix (path->string p)))))

@; -----------------------------------------------------------------------------

@title{Artifact: @|PAPER-TITLE|}

@(author (author+email "Stephen Chang" "stchang@ccs.neu.edu")
         (author+email "Alex Knauth" "alexknauth@ccs.neu.edu")
         (author+email "Emina Torlak" "emina@cs.washington.edu"))

This is a README file for the artifact that accompanies "@|PAPER-TITLE|" in
POPL 2018.  If you have any questions, please email any (or all) of the
authors.

Our artifact is a VM image that contains:
@itemlist[
  @item{a copy of the POPL 2018 camera-ready @hyperlink[@file://[PAPER]]{[link]},}
  @item{a distribution of the Racket programming language (v6.10.1),}
  @item{and the @racket[typed-rosette] language and some of its libraries.}
 ]

The goals of this artifact are to:
@itemlist[
  @item{package the @racket[typed-rosette] language described in the paper,}
  @item{provide runnable code for each example in the paper,}
  @item{and review a few of the evaluation examples.}
  @;item{and show how the tables in the paper were computed.}
 ]


@; -----------------------------------------------------------------------------
@section{Artifact Setup and Installation}

Skip this section if you are already reading this document from within the VM.

The artifact may be installed in two ways:
@itemlist[@item{@secref{vm} (recommended)}
          @item{@secref{manual}}]

The VM image is configured to automatically login to the @tt{artifact} user
account. The password for the account is also @tt{artifact}. The account has
root privileges using @tt{sudo} without a password.


@subsection[#:tag "vm"]{VirtualBox VM image}

The artifact is available as a virtual machine appliance for
@hyperlink["https://www.virtualbox.org/wiki/Downloads"]{VirtualBox}.
@margin-note{VM appliance:
@hyperlink[VM-URL]{[link]}}

To run the artifact image, open the downloaded @tt{.ova} file using the
@tt{File->Import Appliance} menu item. This will create a new VM
that can be launched after import. We recommend giving the VM at least
2GB of RAM.

@subsection[#:tag "manual"]{Manual installation}

Follow these instructions to manually install the artifact only if
the VirtualBox image is somehow not working.

(We have only tested these steps with Linux.)

@itemlist[@item{Install @hyperlink["http://download.racket-lang.org"]{Racket
            6.10.1}.

           Add the Racket @tt{bin} directory to your @tt{PATH}. The
           remaining steps assume that Racket's @tt{bin} directory is in the 
           @tt{PATH}.}
           
          @item{Clone the repository into the @tt{popl2018} directory (or any directory):

                @tt{git clone https://github.com/stchang/typed-rosette popl2018}}
          @item{Change directory to the repository root:

                @tt{cd popl2018}}
          @item{From the repository root, check out the @tt{popl2018-artifact} branch:

                @tt{git checkout popl2018-artifact}}
          @item{From the repository root, install the repo as a Racket package:

                @tt{raco pkg install }@literal{--}@tt{auto}}
          @item{Register the documentation:

                @tt{raco setup }@literal{--}@tt{doc-index}}
          @item{From the repository root, change to the @tt{artifact} directory:

                @tt{cd artifact}}
          @item{Build the readme:

                @tt{make readme}}
          @item{Open the produced @tt{README.html} file.}]

@; -----------------------------------------------------------------------------
@section{Artifact Overview}


The relevant files are in @file-url[REPO].

The following files may also be accessed via the VM Desktop:
@itemlist[
  @item{@file-url[ARTIFACT]{README.html}: This page}
  @item{@file-url[ARTIFACT PAPER-PDF]: The camera-ready version of the paper.}
  @item{@tt{DrRacket}: DrRacket IDE for Racket v6.10.1

  Run example files by opening them in DrRacket and pressing the "Run" button.
  
 Alternatively, run files from the command line with @tt{racket}:

  @tt{racket <Racket filename>}}
 ]


@; -----------------------------------------------------------------------------
@section[#:tag "examples"]{Code From the Paper}

For readability and conciseness, the paper sometimes stylizes code that may not
run exactly as presented. This artifact, however, includes and describes
runnable versions of all the paper's examples.

The file links below open in the browser by default. (If not viewing in the VM,
you may need to adjust your browser's "Text Encoding" to display Unicode.) To
run the files, run with @tt{racket} on the command line, or open with DrRacket.

@subsection{Paper section 1}

The paper's intro section contains a single example that demonstrates the kind
of unintuitive errors that can occur in a naive implementation of lenient
symbolic execution, where symbolic values mix with code that may not recognize
them. Specifically, here is the example in (untyped) Rosette:

@codeblock{
#lang rosette

(define-symbolic x integer?) ; defines symbolic value x

;; ok because Rosette lifts `integer?` to handle symbolic vals
(if (integer? x)
    (add1 x)
    (error "can't add non-int")) ; => symbolic value (+ x 1)

;; import raw Racket's `integer?`, as `unlifted-int?`
(require (only-in racket [integer? unlifted-int?]))

(if (unlifted-int? x)
    (add1 x)
    (error "can't add non-int")) ; => errors}

This program is also available in @file-url[POPL-EXAMPLES]{intro-example-untyped-rosette.rkt}

The first @racket[if] expression is valid because Rosette's @racket[integer?]
function recognizes symbolic values.

The second @racket[if] expression, however, reaches the error branch even
though @racket[x] is an integer because the base @racket[integer?] predicate
from @emph{Racket}, which we have renamed to @racket[unlifted-int?], does not
recognize symbolic values.

If the "else" branch did not happen throw an error, the program would instead
silently return the incorrect value.

In contrast, our Typed Rosette language reports type errors when symbolic
values flow to positions that do not recognize them:

@codeblock{
#lang typed/rosette

(define-symbolic x integer?) ; defines symbolic value x

;; ok because `integer?` is lifted to handle symbolic vals
(if (integer? x)
    (add1 x)
    (error "can't add non-int")) ; => symbolic value (+ 1 x)

;; import raw Racket's `integer?`, as `unlifted-int?`, with type
(require/type racket [integer? unlifted-int? : (C→ CAny CBool)])

(if (unlifted-int? x)
    (add1 x)
    (error "can't add non-int")) ; => type error}

This program is also available in @file-url[POPL-EXAMPLES]{intro-example-typed-rosette.rkt}

In this program, the raw Racket @racket[integer?] is imported with a
@racket[CAny] type, indicating that its input may be any @emph{concrete}
value. Since @racket[x] is a symbolic value, the type checker raises a type error.

@subsection{Paper section 2}

The paper's second section introduces Rosette via examples and motivates the
need for Typed Rosette.

The first part of the section introduces basic computing with symbolic values
in Rosette and shows one example of interacting with the solver. These programs
use the restricted @racket[rosette/safe] language, which does not allow lenient
symbolic execution. These "safe" Rosette examples are already described in the
paper and are mostly straightforward so we will not repeat the explanations
here. Runnable versions of the safe examples may be viewed here:

@file-url[POPL-EXAMPLES]{sec2-rosette-safe-examples.rkt}

Using the full @racket[rosette] language instead of @racket[rosette/safe],
programmers can take advantage of lenient symbolic execution and use the full
Racket language. The first @tt{#lang rosette} example, viewable here:

@file-url[POPL-EXAMPLES]{sec2-rosette-unsafe-hash-example.rkt}

uses (unlifted) hash
tables and tries to prove that the list is always sorted with the specified
constraints. Even we expect that the constraints are sufficient to specify
sortedness, the solver returns a "counterexample" that supposedly violates our
constraints. Inspecting this "counterexample", however, reveals that it is not
actually a counterexample--- it still results in a sorted hash!


At this point, Rosette programmers are stumped, since the program has failed
silently. Specifically, the solver has returned an unexpected result but the
programmer has no information with which to look for the cause of the problem
in the program. Even worse, an inattentive programmer may not think anything is
wrong and instead accept the result of solver as correct. This highlights the
problems with lenient symbolic execution.


In contrast, the same example in Typed Rosette produces a type error that
pinpoints the exact source of the problem. Specifically, @racket[hash-ref] is
unlifted, i.e., it does not recognize symbolic keys, but the programmer has
given it a symbolic value.

The full program is here:

@file-url[POPL-EXAMPLES]{sec2-typed-rosette-hash-example.rkt}



@subsection{}

@file-url[POPL-EXAMPLES]
@itemlist[@item{@file-url[POPL-EXAMPLES]{lam.rkt}: defines a language with only
                single-argument lambda.}
          @item{@file-url[POPL-EXAMPLES]{lam-prog.rkt}: a program using
                @tt{lam.rkt} as its language.
                Attempting to apply functions results in a syntax error.
                This file uses our custom unit-testing framework to catch and
                check errors.}
          @item{@file-url[POPL-EXAMPLES]{lc.rkt}: extends @tt{lam.rkt} with
                function application.}
          @item{@file-url[POPL-EXAMPLES]{lc-prog.rkt}: a program using
                @tt{lc.rkt} as its language.
                This program will loop forever when run.}]
          
@subsection{Paper section 3}

@file-url[POPL-EXAMPLES]
@itemlist[@item{@file-url[POPL-EXAMPLES]{stlc-with-racket.rkt}: runnable version
                of code from figures 3 through 8.}
          @item{@file-url[POPL-EXAMPLES]{stlc-with-racket-prog.rkt}:
                a program that uses @tt{stlc-with-racket.rkt} as its language.
                Shows a few type errors.}]

@subsection{Paper section 4}

@file-url[POPL-EXAMPLES]
@itemlist[@item{@file-url[POPL-EXAMPLES]{stlc-with-turnstile.rkt}: runnable
                version of code from figure 11, as well as the extended
                @tt{#%app} from section 4.2.}
          @item{@file-url[POPL-EXAMPLES]{stlc-with-turnstile-prog.rkt}:
                same as @tt{stlc-with-racket-prog.rkt}, but using
                @tt{stlc-with-turnstile.rkt} as its language.}
          @item{@file-url[POPL-EXAMPLES]{stlc+prim.rkt}: language implementation from figure 12
                that extends @tt{stlc-with-turnstile.rkt} with integers and addition.}
          @item{@file-url[POPL-EXAMPLES]{stlc+prim-prog.rkt}: some examples
                (not shown in paper) using the @tt{stlc+prim.rkt} language.}
          @item{@file-url[POPL-EXAMPLES]{stlc+prim-with-racket.rkt}:
                (not shown in paper) same language implementation as
                @tt{stlc+prim.rkt}, but using base Racket instead of Turnstile.}
          @item{@file-url[POPL-EXAMPLES]{stlc+prim-with-racket-prog.rkt}:
                (not shown in paper) same as @tt{stlc+prim-prog.rkt}, but using
                @tt{stlc+prim-with-racket.rkt} as its language.}]

@subsection{Paper section 5}

@file-url[POPL-EXAMPLES]

@itemlist[@item{@file-url[POPL-EXAMPLES]{exist.rkt}: language with existential
                types from figure 13, including @tt{subst} and @tt{τ=}.}
          @item{@file-url[POPL-EXAMPLES]{exist-prog.rkt}: the "counter" example
                from the paper.}
          @item{@file-url[POPL-EXAMPLES]{stlc+sub.rkt}: language with subtyping
                from figure 14; reuses rules from @tt{stlc+prim.rkt}.}
          @item{@file-url[POPL-EXAMPLES]{stlc+sub-prog.rkt}: some examples
                (not shown in paper) using the @tt{stlc+sub.rkt} language.}
          @item{@file-url[POPL-EXAMPLES]{fomega.rkt}: F-omega language from
                figure 16.}
          @item{@file-url[POPL-EXAMPLES]{fomega-prog.rkt}: some examples
                (not shown in paper) using the @tt{fomega.rkt} language.}
          @item{@file-url[POPL-EXAMPLES]{effect.rkt}: language with
                type-and-effect system from figure 17.}
          @item{@file-url[POPL-EXAMPLES]{effect-prog.rkt}: some examples
                (not shown in paper) using the @tt{effect.rkt} language.}]

@subsection{Other files}
@file-url[POPL-EXAMPLES]
@itemlist[@item{@file-url[POPL-EXAMPLES]{abbrv.rkt}: defines abbreviations from
                the paper, like @tt{define-m}.}
          @item{@file-url[POPL-EXAMPLES]{run-all-examples.rkt}: runs all the
                @tt{-prog.rkt} example programs.}]

@; -----------------------------------------------------------------------------
@section{Paper Section 6: MLish}
The paper presents simplistic snippets of the MLish language implementation,
optimized for readability. The actual implementation can be found in the files
listed below.

@file-url[TURNSTILE-EXAMPLES]
@itemlist[@item{@file-url[TURNSTILE-EXAMPLES]{mlish.rkt}: MLish language
                (no type classes).}
          @item{@file-url[TURNSTILE-EXAMPLES]{mlish+adhoc.rkt}: MLish language
                (with type classes); @tt{define-tc} in the paper is
                @tt{define-typeclass}.}]

These implementations fill in the gaps from the paper. The actual
implementations may additionally differ from the paper in other ways, for
example with improved error message reporting and a more efficient type
inference algorithm.

Feel free to experiment with creating your own MLish program. Look at examples
in the @file-url[TURNSTILE-EXAMPLES]{tests/mlish} directory to help get started.

For example, @file-url[MLISH-TEST]{trees.mlish} and
@file-url[MLISH-TEST]{trees-tests.mlish} contain the trees example from the
paper.

@; -----------------------------------------------------------------------------
@section[#:tag "tables"]{Tables From the Paper}

To evaluate Turnstile, we implemented two versions of several example languages:
@itemlist[#:style 'ordered
          @item{a version using Racket, as described in Section 3 of the paper.
                These implementations can be found at:

                @file-url[RACKET-EXAMPLES]}
          @item{a version using Turnstile, as described in Sections 4-6 of the
                paper. These implementations can be found at:

                @file-url[TURNSTILE-EXAMPLES]}]

The languages in each directory extend and reuse components from each other when
possible.

@subsection{Table 1: Summary of reuse (visual)}

Table 1 was compiled using the
@hyperlink[@file://[RACKET-EXAMPLES]]{Racket implementations} (#1 above).
Table 1 remains roughly accurate for the
@hyperlink[@file://[TURNSTILE-EXAMPLES]]{Turnstile versions} (#2), except that
Turnstile defines more things, e.g., @tt{τ=}, automatically.

The (Excel) source for Table 1 is at @file-url[REPO]{extension-table.xlsm}. The
VM does not have a local viewer for the file but the file is viewable with
Google Sheets. It is also publicly downloadable from our repository.

@subsection{Table 2: Summary of reuse (line counts)}

@itemlist[@item{Column 1: reports the exact line numbers of the
@hyperlink[@file://[TURNSTILE-EXAMPLES]]{Turnstile implementations} (#2 above).}

@item{Column 2: estimates the number of lines required to implement
each language without reusing any other languages by adding up the lines for
the relevant languages from column 1. Column 2 is an approximation because it
only counts lines from files that were @emph{entirely} needed to implement the
language in question, and excludes files from which only a few lines are reused.}

@item{Column 3: estimates all the lines of code required by the 
@hyperlink[RACKET-EXAMPLES]{non-Turnstile implementations} (#1 above). Since we
did not explicitly implement every permutation of every language, and instead
followed standard software development practices such as moving common
operations to libraries, column 3 was difficult to compute accurately. To get a
rough idea, we simply added all the lines of code in the language implementations and common library
files together.}]

All line counts include comments and whitespace and all approximate numbers are
rounded to two significant figures. Despite the approximations, this table
remains useful for understanding the degree of reuse achieved by using
Turnstile.

The numbers in Table 2 may be recomputed by running @file-url[REPO]{compute-table2.rkt}.

@subsection{Table 3: Tests (line counts)}

@itemlist[@item{Column 1: number of lines of tests for the core languages, available at:

 @file-url[TURNSTILE-TEST]

Run all (non-MLish) tests by running @file-url[TURNSTILE-TEST]{run-all-tests.rkt}.}

@item{Column 2: number of lines of tests for MLish, available at:

 @file-url[MLISH-TEST]

Run all the MLish tests by running @file-url[TURNSTILE-TEST]{run-all-mlish-tests.rkt}.}]

All line counts include comments and whitespace.

@margin-note{To completely re-compile and re-run all tests (may take ~30-60min):
 @itemlist[@item{@tt{raco setup -c turnstile macrotypes}}
           @item{@tt{raco setup turnstile macrotypes}}
           @item{@tt{raco test turnstile macrotypes}}]}

Particular files of interest for MLish tests:
@itemize[@item{@file-url[MLISH-TEST]{generic.mlish}: example typeclass operations
         }
         @item{@file-url[MLISH-TEST]{term.mlish}: some tests from
          @hyperlink["https://realworldocaml.org/"]{@emph{Real-World OCaml}}
         }
         @item{@file-url[MLISH-TEST]{nbody.mlish},
               @file-url[MLISH-TEST]{fasta.mlish},
               @file-url[MLISH-TEST]{chameneos.mlish}:
          some tests from
          @hyperlink["http://benchmarksgame.alioth.debian.org/"]{The Computer Language Benchmarks Game}
         }
         @item{@file-url[MLISH-TEST]{listpats.mlish},
               @file-url[MLISH-TEST]{match2.mlish}:
          pattern matching tests for lists, tuples, and user-defined datatypes
         }
         @item{@file-url[(build-path MLISH-TEST "bg")]{okasaki.mlish}:
           tests from @emph{Purely Functional Data Structures}
         }
         @item{@file-url[MLISH-TEST]{polyrecur.mlish}: polymorphic, recursive
           type definitions
         }
         @item{@file-url[MLISH-TEST]{queens.mlish},
               @file-url[(build-path MLISH-TEST "bg")]{huffman.mlish}:
          a few other common example programs
         }
]

The numbers in Table 3 may be recomputed by running @file-url[REPO]{compute-table3.rkt}.

@; -----------------------------------------------------------------------------
@section[#:tag "new"]{Building New Typed Languages}

To learn more about @racketmodname[turnstile], view the official 
@racketmodname[turnstile] documentation.

@secref["The_Turnstile_Guide"
         #:doc '(lib "turnstile/scribblings/turnstile.scrbl")]
describes how to build and re-use a new typed language.

@secref["The_Turnstile_Reference"
         #:doc '(lib "turnstile/scribblings/turnstile.scrbl")]
describes all the forms provided
by Turnstile.

