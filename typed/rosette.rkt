#lang turnstile
;; reuse unlifted forms as-is
(reuse  
 let let* letrec begin #%datum ann current-join ⊔
 define-type-alias define-named-type-alias
 #:from turnstile/examples/stlc+union)
(require
 ;; manual imports
 (only-in turnstile/examples/stlc+union
          define-named-type-alias)
 ;; import typed rosette types
 "rosette/types.rkt"
 ;; import base forms
 (rename-in "rosette/base-forms.rkt" [#%app app])
 ;; base lang
 (prefix-in ro: (combine-in rosette rosette/lib/synthax))
 (rename-in "rosette-util.rkt" [bitvector? lifted-bitvector?]))

(provide : define λ apply ann begin list
         (rename-out [app #%app]
                     [ro:#%module-begin #%module-begin] 
                     [λ lambda])
         (for-syntax get-pred expand/ro)
         CAny Any CNothing Nothing
         CU U (for-syntax ~CU* ~U*)
         Constant
         C→ C→* → (for-syntax ~C→ ~C→* C→? concrete-function-type?)
         Ccase-> (for-syntax ~Ccase-> Ccase->?) ; TODO: sym case-> not supported
         CListof Listof CList CPair Pair
         (for-syntax ~CListof)
         CVectorof MVectorof IVectorof Vectorof CMVectorof CIVectorof CVector
         CParamof ; TODO: symbolic Param not supported yet
         CBoxof MBoxof IBoxof CMBoxof CIBoxof CHashTable
         (for-syntax ~CHashTable)
         CUnit Unit (for-syntax ~CUnit CUnit?)
         CNegInt NegInt
         CZero Zero
         CPosInt PosInt
         CNat Nat
         CInt Int
         CFloat Float
         CNum Num
         CFalse CTrue CBool Bool
         CString String (for-syntax CString?)
         CStx ; symblic Stx not supported
         CSymbol
         CAsserts
         ;; BV types
         CBV BV
         CBVPred BVPred
         CSolution CSolver CPict CRegexp
         LiftedPred LiftedPred2 LiftedNumPred LiftedIntPred UnliftedPred)

;; a legacy auto-providing version of define-typed-syntax
;; TODO: convert everything to new define-typed-syntax
(define-syntax (define-typed-syntax stx)
  (syntax-parse stx
    [(_ name:id #:export-as out-name:id . rst)
     #'(begin-
         (provide- (rename-out [name out-name]))
         (define-typerule name . rst))] ; define-typerule doesnt provide
    [(_ name:id . rst)
     #'(define-typed-syntax name #:export-as name . rst)]
    [(_ (name:id . pat) . rst)
     #'(define-typed-syntax name #:export-as name [(_ . pat) . rst])]))

;; ---------------------------------
;; define-symbolic

(define-typed-syntax define-symbolic
  [(_ x:id ...+ pred?) ≫
   [⊢ [pred? ≫ pred?- (⇒ : _) (⇒ typefor ty) (⇒ solvable? s?)]]
   #:fail-unless (syntax-e #'s?)
                 (format "Expected a Rosette-solvable type, given ~a." 
                         (syntax->datum #'pred?))
   #:with (y ...) (generate-temporaries #'(x ...))
   --------
   [_ ≻ (begin-
          (define-syntax- x (make-rename-transformer (⊢ y : (Constant ty)))) ...
          (ro:define-symbolic y ... pred?-))]])

(define-typed-syntax define-symbolic*
  [(_ x:id ...+ pred?) ≫
   [⊢ [pred? ≫ pred?- (⇒ : _) (⇒ typefor ty) (⇒ solvable? s?)]]
   #:fail-unless (syntax-e #'s?)
                 (format "Expected a Rosette-solvable type, given ~a." 
                         (syntax->datum #'pred?))
   #:with (y ...) (generate-temporaries #'(x ...))
   --------
   [_ ≻ (begin-
          (define-syntax- x (make-rename-transformer (⊢ y : (Constant ty)))) ...
          (ro:define-symbolic* y ... pred?-))]])

;; TODO: support internal definition contexts
(define-typed-syntax let-symbolic
  [(_ (x:id ...+ pred?) e ...) ≫
   [⊢ [pred? ≫ pred?- (⇒ : _) (⇒ typefor ty) (⇒ solvable? s?)]]
   #:fail-unless (syntax-e #'s?)
                 (format "Expected a Rosette-solvable type, given ~a." 
                         (syntax->datum #'pred?))
   [([x ≫ x- : (Constant ty)] ...) ⊢ [(stlc+union:begin e ...) ≫ e- ⇒ τ_out]]
   --------
   [⊢ [_ ≫ (ro:let-values
            ([(x- ...) (ro:let ()
                         (ro:define-symbolic x ... pred?-)
                         (ro:values x ...))])
            e-) ⇒ : τ_out]]])
(define-typed-syntax let-symbolic*
  [(_ (x:id ...+ pred?) e ...) ≫
   [⊢ [pred? ≫ pred?- (⇒ : _) (⇒ typefor ty) (⇒ solvable? s?)]]
   #:fail-unless (syntax-e #'s?)
                 (format "Expected a Rosette-solvable type, given ~a." 
                         (syntax->datum #'pred?))
   [([x ≫ x- : (Constant ty)] ...) ⊢ [(stlc+union:begin e ...) ≫ e- ⇒ τ_out]]
   --------
   [⊢ [_ ≫ (ro:let-values
            ([(x- ...) (ro:let ()
                         (ro:define-symbolic* x ... pred?-)
                         (ro:values x ...))])
            e-) ⇒ : τ_out]]])

;; ---------------------------------
;; assert, assert-type

(define-typed-syntax assert
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:assert e-) ⇒ : CUnit]]]
  [(_ e m) ≫
   [⊢ [e ≫ e- ⇒ : _]]
   [⊢ [m ≫ m- ⇐ : (CU CString (C→ CNothing))]]
   --------
   [⊢ [_ ≫ (ro:assert e- m-) ⇒ : CUnit]]])

;; TODO: assert-type wont work with unlifted types
;; but sometimes it should, eg in with for/all lifted functions
;; - but this means we need to lift a pred (eg string?) and associate it with the newly lifted type 
(define-typed-syntax assert-type #:datum-literals (:)
  [(_ e : ty:type) ≫
   [⊢ [e ≫ e- ⇒ : _]]
   #:with pred (get-pred #'ty.norm)
   --------
   [⊢ [_ ≫ (ro:#%app assert-pred e- pred) ⇒ : ty.norm]]])  


;; ---------------------------------
;; Racket forms

;; struct enabling typed structs to cooperate with struct-info
(begin-for-syntax
  (require racket/struct-info)
  (struct typed-struct (id fn)
    #:property prop:procedure (struct-field-index fn)
    #:property prop:struct-info
               (λ (x)
                 (extract-struct-info
                  (syntax-local-value
                   (typed-struct-id x))))))

;; TODO: get subtyping to work for struct-generated types?
;; TODO: allow super struct
(define-typed-syntax struct #:datum-literals (:)
  [(_ name:id (x:id ...+) ~! . rst) ≫
   #:fail-when #t "Missing type annotations for fields"
   --------
   [≻ (ro:struct name (x ...) . rst)]]
  [(_ name:id ([x:id : ty:type . xrst] ...) . kws) ≫
   #:fail-unless (id-lower-case? #'name)
                 (format "Expected lowercase struct name, given ~a" #'name)
   #:with name* (generate-temporary #'name)
   #:with Name (id-upcase #'name)
   #:with CName (format-id #'name "C~a" #'Name)
   ;; find mutable fields and their types (converted to symbolic)
   ;; produces two lists
   ;; 1) fields+types of just mutable fields
   ;; 2) all fields+types (with those of mutable fields converted to symbolic)
   #:with (([x_mut ty_mut] ...) ([x/mut ty/mut] ...)) ; xs are needed to make ellipses match
          (if (stx-datum-member '#:mutable #'kws)
              (let ([xs+tys/mut (stx-map (λ (x t) #`[#,x (U #,t)]) #'(x ...) #'(ty ...))])
                (list xs+tys/mut xs+tys/mut))
              (let-values
                ([(xs+tys_mut xs+tys/mut)
                  (for/fold ([xs+tys_mut '()][xs+tys/mut '()])
                            ([x (stx->list #'(x ...))]
                             [ty (stx->list #'(ty ...))]
                             [xrst (stx->list #'(xrst ...))])
                    (if (stx-datum-member '#:mutable xrst)
                        (values (cons #`[#,x (U #,ty)] xs+tys_mut)
                                (cons #`[#,x (U #,ty)] xs+tys/mut))
                        (values xs+tys_mut
                                (cons #`[#,x #,ty] xs+tys/mut))))])
                (list (reverse xs+tys_mut) (reverse xs+tys/mut))))
   #:with TyOut #'(Name ty/mut ...)
   #:with CTyOut #'(CName ty/mut ...)
   #:with (name-x ...) (stx-map (λ (f) (format-id #'name "~a-~a" #'name f)) #'(x/mut ...))
   #:with (name-x* ...) (stx-map (λ (f) (format-id #'name* "~a-~a" #'name* f)) #'(x/mut ...))
   #:with (set-x ...) (stx-map (λ (f) (format-id #'name "set-~a-~a!" #'name f)) #'(x_mut ...))
   #:with (set-x* ...) (stx-map (λ (f) (format-id #'name* "set-~a-~a!" #'name* f)) #'(x_mut ...))
   #:with name? (format-id #'name "~a?" #'name)
   #:with name?* (format-id #'name* "~a?" #'name*)
   --------
   [≻ (ro:begin
       (ro:struct name* ([x . xrst] ...) . kws)
       (define-type-constructor CName #:arity = #,(stx-length #'(x ...)))
       (define-named-type-alias (Name x ...) (U (CName x ...)))
       (define-syntax name   ; constructor
         (typed-struct #'name* 
          (make-variable-like-transformer
           (assign-type #'name* #'(C→ ty/mut ... CTyOut)))))
       (define-syntax name?  ; predicate
         (make-variable-like-transformer 
          (assign-type #'name?* #'LiftedPred)))
       (define-syntax name-x ; accessors
         (make-variable-like-transformer 
          (assign-type #'name-x* #'(C→ TyOut ty/mut)))) ...
       (define-syntax set-x ; setters (only mutable fields)
         (make-variable-like-transformer
          (assign-type #'set-x* #'(C→ TyOut ty_mut CUnit)))) ...)]])

;; TODO: add type rules for generics
(define-typed-syntax define-generics #:datum-literals (: ->)
  [(_ name:id (f:id x:id ... -> ty-out)) ≫
   #:with app-f (format-id #'f "apply-~a" #'f)
   --------
   [_ ≻ (ro:begin
         (ro:define-generics name (f x ...))
         (define-syntax app-f ; tmp workaround: each gen fn has its own apply
           (syntax-parser
             [(_ . es)
              #:with es+ (stx-map expand/df #'es)
              (assign-type #'(ro:#%app f . es+) #'ty-out)])))]])

;; ---------------------------------
;; quote

(define-typed-syntax quote
  ;; base case: symbol
  [(_ x:id) ≫
   --------
   [⊢ (ro:quote x) ⇒ CSymbol]]
  ;; recur: list (this clause should come before pair)
  [(_ (x ...)) ≫
   [⊢ (quote x) ≫ (_ x-) ⇒ τ] ...
   --------
   [⊢ (ro:quote (x- ...)) ⇒ (CList τ ...)]]
  ;; recur: pair
  [(_ (x . y)) ≫
   [⊢ (quote x) ≫ (_ x-) ⇒ τx]
   [⊢ (quote y) ≫ (_ y-) ⇒ τy]
   --------
   [⊢ (ro:quote (x- . y-)) ⇒ (CPair τx τy)]]
  ;; base case: other datums
  [(_ x) ≫
   [⊢ (stlc+union:#%datum . x) ≫ (_ x-) ⇒ τ]
   --------
   [⊢ (ro:quote x-) ⇒ τ]])

;; ---------------------------------
;; if

;; TODO: this is not precise enough
;; specifically, a symbolic non-bool should produce a concrete val
(define-typed-syntax if
  [(_ e_tst e1 e2) ≫
   [⊢ [e_tst ≫ e_tst- ⇒ : ty_tst]]
   #:when (or (concrete? #'ty_tst) ; either concrete
              ; or non-bool symbolic
              (not (typecheck? #'ty_tst ((current-type-eval) #'Bool))))
   [⊢ [e1 ≫ e1- ⇒ : ty1]]
   [⊢ [e2 ≫ e2- ⇒ : ty2]]
   #:when (and (concrete? #'ty1) (concrete? #'ty2))
   --------
   [⊢ [_ ≫ (ro:if e_tst- e1- e2-) ⇒ : (CU ty1 ty2)]]]
  [(_ e_tst e1 e2) ≫
   [⊢ [e_tst ≫ e_tst- ⇒ : _]]
   [⊢ [e1 ≫ e1- ⇒ : ty1]]
   [⊢ [e2 ≫ e2- ⇒ : ty2]]
   --------
   [⊢ [_ ≫ (ro:if e_tst- e1- e2-) ⇒ : (U ty1 ty2)]]])
   
;; ---------------------------------
;; set!

;; TODO: use x instead of x-?
(define-typed-syntax set!
  [(set! x:id e) ≫
   [⊢ [x ≫ x- ⇒ : ty_x]]
   [⊢ [e ≫ e- ⇐ : ty_x]]
   --------
   [⊢ [_ ≫ (ro:set! x- e-) ⇒ : CUnit]]])

;; ---------------------------------
;; vector

;; mutable constructor
(define-typed-syntax vector
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇒ : τ] ...]
   --------
   [⊢ [_ ≫ (ro:vector e- ...) ⇒ : #,(if (stx-andmap concrete? #'(τ ...))
                                        #'(CMVectorof (CU τ ...))
                                        #'(CMVectorof (U τ ...)))]]])

(provide (typed-out [vector? : LiftedPred]))

;; immutable constructor
(define-typed-syntax vector-immutable
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇒ : τ] ...]
   --------
   [⊢ [_ ≫ (ro:vector-immutable e- ...) ⇒ : #,(if (stx-andmap concrete? #'(τ ...))
                                                  #'(CIVectorof (CU τ ...))
                                                  #'(CIVectorof (U τ ...)))]]])

;; TODO: add CList case?
;; returne mutable vector
(define-typed-syntax list->vector
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:list->vector ⇒ : (Ccase-> (C→ (CListof Any) (CMVectorof Any))
                                        (C→ (Listof Any) (MVectorof Any)))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:list->vector e-) ⇒ : (CMVectorof τ)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:list->vector e-) ⇒ : (U (CMVectorof τ) ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ ...)]]
   --------
   [⊢ [_ ≫ (ro:list->vector e-) ⇒ : (CMVectorof (U τ ...))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:list->vector e-) ⇒ : (U (CMVector (U τ ...)) ...)]]])

(define-typed-syntax vector-ref
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~or (~CMVectorof τ) (~CIVectorof τ))]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:vector-ref e- n-) ⇒ : τ]]]
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~and (~or (~CMVectorof τ) (~CIVectorof τ))) ...)]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:vector-ref e- n-) ⇒ : (U τ ...)]]])

;; ---------------------------------
;; hash tables

(define-typed-syntax hash-keys
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CHashTable τ _)]]
   --------
   [⊢ [_ ≫ (ro:hash-keys e-) ⇒ : (CListof τ)]]])

(define-typed-syntax hash-values
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CHashTable _ τ)]]
   --------
   [⊢ [_ ≫ (ro:hash-values e-) ⇒ : (CListof τ)]]])

;; ---------------------------------
;; lists

(provide (typed-out [null? : (Ccase-> (C→ (CListof Any) CBool)
                                      (C→ (Listof Any) Bool))]
                    [empty? : (Ccase-> (C→ (CListof Any) CBool)
                                       (C→ (Listof Any) Bool))]
                    [list? : LiftedPred]))

(define-typed-syntax cons
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:cons ⇒ : (Ccase-> 
                        (C→ Any Any (CPair Any Any))
                        (C→ Any (CListof Any) (CListof Any))
                        (C→ Any (Listof Any) (Listof Any)))]]]
  [(_ e1 e2) ≫
   [⊢ [e2 ≫ e2- ⇒ : (~CListof τ1)]]
   [⊢ [e1 ≫ e1- ⇒ : τ2]]
   --------
   [⊢ [_ ≫ (ro:cons e1- e2-) 
           ⇒ : #,(if (and (concrete? #'τ1) (concrete? #'τ2))
                     #'(CListof (CU τ1 τ2))
                     #'(CListof (U τ1 τ2)))]]]
  [(_ e1 e2) ≫
   [⊢ [e2 ≫ e2- ⇒ : (~U* (~CListof τ) ...)]]
   [⊢ [e1 ≫ e1- ⇒ : τ1]]
   --------
   [⊢ [_ ≫ (ro:cons e1- e2-) ⇒ : (U (CListof (U τ1 τ)) ...)]]]
  [(_ e1 e2) ≫
   [⊢ [e1 ≫ e1- ⇒ : τ1]]
   [⊢ [e2 ≫ e2- ⇒ : (~CList τ ...)]]
   --------
   [⊢ [_ ≫ (ro:cons e1- e2-) ⇒ : (CList τ1 τ ...)]]]
  [(_ e1 e2) ≫
   [⊢ [e1 ≫ e1- ⇒ : τ1]]
   [⊢ [e2 ≫ e2- ⇒ : (~U* (~CList τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:cons e1- e2-) ⇒ : (U (CList τ1 τ ...) ...)]]]
  [(_ e1 e2) ≫
   [⊢ [e1 ≫ e1- ⇒ : τ1]]
   [⊢ [e2 ≫ e2- ⇒ : τ2]]
   --------
   [⊢ [_ ≫ (ro:cons e1- e2-) ⇒ : (CPair τ1 τ2)]]])

;; car and cdr additionally support pairs
(define-typed-syntax car
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:car ⇒ : (Ccase-> (C→ (Pair Any Any) Any)
                               (C→ (Listof Any) Any))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : (U τ ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ1 τ ...)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : τ1]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ1 τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : (U τ1 ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CPair τ _)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CPair τ _) ...)]]
   --------
   [⊢ [_ ≫ (ro:car e-) ⇒ : (U τ ...)]]])

(define-typed-syntax cdr
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:cdr ⇒ : (Ccase-> (C→ (CListof Any) (CListof Any))
                                (C→ (Listof Any) (Listof Any)))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : (CListof τ)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : (U (CListof τ) ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ1 τ ...)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : (CList τ ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ1 τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : (U (CList τ ...) ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CPair _ τ)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CPair _ τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:cdr e-) ⇒ : (U τ ...)]]])


(define-typed-syntax first
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:first ⇒ : (C→ (Listof Any) Any)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:first e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:first e-) ⇒ : (U τ ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ1 τ ...)]]
   --------
   [⊢ [_ ≫ (ro:first e-) ⇒ : τ1]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ1 τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:first e-) ⇒ : (U τ1 ...)]]])

(define-typed-syntax rest
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:rest ⇒ : (Ccase-> (C→ (CListof Any) (CListof Any))
                                (C→ (Listof Any) (Listof Any)))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:rest e-) ⇒ : (CListof τ)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:rest e-) ⇒ : (U (CListof τ) ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ1 τ ...)]]
   --------
   [⊢ [_ ≫ (ro:rest e-) ⇒ : (CList τ ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ1 τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:rest e-) ⇒ : (U (CList τ ...) ...)]]])

(define-typed-syntax second
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:second ⇒ : (C→ (Listof Any) Any)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:second e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:second e-) ⇒ : (U τ ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ1 τ2 τ ...)]]
   --------
   [⊢ [_ ≫ (ro:second e-) ⇒ : τ2]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ1 τ2 τ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:second e-) ⇒ : (U τ2 ...)]]])

;; n must be Int bc Rosette does not have symbolic Nats
(define-typed-syntax take
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:take ⇒ : (Ccase-> (C→ (CListof Any) CInt (CListof Any))
                                (C→ (Listof Any) Int (Listof Any)))]]]
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:take e- n-) ⇒ : (CListof τ)]]]
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:take e- n-) ⇒ : (U (CListof τ) ...)]]]
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~CList τ ...)]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:take e- n-) ⇒ : (CListof (U τ ...))]]]
  [(_ e n) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ ...) ...)]]
   [⊢ [n ≫ n- ⇐ : Int]]
   --------
   [⊢ [_ ≫ (ro:take e- n-) ⇒ : (U (CList (U τ ...)) ...)]]])

(define-typed-syntax length
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:length ⇒ : (Ccase-> (C→ (CListof Any) CNat)
                                (C→ (Listof Any) Nat))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇐ : (CListof Any)]]
   --------
   [⊢ [_ ≫ (ro:length e-) ⇒ : CNat]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof _) ...)]]
   --------
   [⊢ [_ ≫ (ro:length e-) ⇒ : Nat]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList _ ...)]]
   --------
   [⊢ [_ ≫ (ro:length e-) ⇒ : CNat]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList _ ...) ...)]]
   --------
   [⊢ [_ ≫ (ro:length e-) ⇒ : Nat]]])

(define-typed-syntax reverse
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:reverse ⇒ : (Ccase-> (C→ (CListof Any) (CListof Any))
                                   (C→ (Listof Any) (Listof Any)))]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   --------
   [⊢ [_ ≫ (ro:reverse e-) ⇒ : (CListof τ)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   --------
   [⊢ [_ ≫ (ro:reverse e-) ⇒ : (U (CListof τ) ...)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~CList . τs)]]
   #:with τs/rev (stx-rev #'τs)
   --------
   [⊢ [_ ≫ (ro:reverse e-) ⇒ : (CList . τs/rev)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList . τs) ...)]]
   #:with (τs/rev ...) (stx-map stx-rev #'(τs ...))
   --------
   [⊢ [_ ≫ (ro:reverse e-) ⇒ : (U (CList . τs/rev) ...)]]])

(define-typed-syntax build-list
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:build-list ⇒ : (C→ CNat (C→ CNat Any) (CListof Any))]]]
  [(_ n f) ≫
   [⊢ [n ≫ n- ⇐ : CNat]]
   [⊢ [f ≫ f- ⇒ : (~C→ ty1 ty2)]]
   #:fail-unless (typecheck? #'ty1 ((current-type-eval) #'CNat))
                 "expected function that consumes concrete Nat"
   --------
   [⊢ [_ ≫ (ro:build-list n- f-) ⇒ : (CListof ty2)]]])
(define-typed-syntax map
  #;[_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:map ⇒ : (C→ (C→ Any Any) (CListof Any) (CListof Any))]]]
  [(_ f lst) ≫
   [⊢ [f ≫ f- ⇒ : (~C→ ~! ty1 ty2)]]
   [⊢ [lst ≫ lst- ⇐ : (CListof ty1)]]
   --------
   [⊢ [_ ≫ (ro:map f- lst-) ⇒ : (CListof ty2)]]]
  [(_ f lst) ≫
   [⊢ [lst ≫ lst- ⇒ : (~CListof ty1)]]
   [⊢ [f ≫ f- ⇒ : (~Ccase-> ~! ty-fns ...)]] ; find first match
   #:with (~C→ _ ty2)
          (for/first ([ty-fn (stx->list #'(ty-fns ...))]
                      #:when (syntax-parse ty-fn
                               [(~C→ t1 _) #:when (typecheck? #'ty1 #'t1) #t]
                               [_ #f]))
            (displayln (syntax->datum ty-fn))
            ty-fn)
   --------
   [⊢ [_ ≫ (ro:map f- lst-) ⇒ : (CListof ty2)]]]
  [(_ f lst) ≫
   [⊢ [lst ≫ lst- ⇒ : (~U* (~CListof ty1))]]
   [⊢ [f ≫ f- ⇒ : (~Ccase-> ~! ty-fns ...)]] ; find first match
   #:with (~C→ _ ty2)
          (for/first ([ty-fn (stx->list #'(ty-fns ...))]
                      #:when (syntax-parse ty-fn
                               [(~C→ t1 _) #:when (typecheck? #'ty1 #'t1) #t]
                               [_ #f]))
            ty-fn)
   --------
   [⊢ [_ ≫ (ro:map f- lst-) ⇒ : (CListof ty2)]]])

;; TODO: finish andmap
(define-typed-syntax andmap
  #;[_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:andmap ⇒ : (C→ (C→ Any Bool) (CListof Any) Bool)]]]
  [(_ f lst) ≫
   [⊢ [f ≫ f- ⇒ : (~C→ ~! ty ty-bool)]]
   [⊢ [lst ≫ lst- ⇒ : (~CListof _)]]
   --------
   [⊢ [_ ≫ (ro:andmap f- lst-) ⇒ : Bool]]]
  #;[(_ f lst) ≫
   [⊢ [lst ≫ lst- ⇒ : (~CListof ty)]]
   [⊢ [f ≫ f- ⇒ : (~Ccase-> ~! ty-fns ...)]] ; find first match
   #:with (~C→ _ ty2)
          (for/first ([ty-fn (stx->list #'(ty-fns ...))]
                      #:when (syntax-parse ty-fn
                               [(~C→ t1 _) #:when (typecheck? #'ty1 #'t1) #t]
                               [_ #f]))
            (displayln (syntax->datum ty-fn))
            ty-fn)
   --------
   [⊢ [_ ≫ (ro:map f- lst-) ⇒ : (CListof ty2)]]]
  #;[(_ f lst) ≫
   [⊢ [lst ≫ lst- ⇒ : (~U* (~CListof ty1))]]
   [⊢ [f ≫ f- ⇒ : (~Ccase-> ~! ty-fns ...)]] ; find first match
   #:with (~C→ _ ty2)
          (for/first ([ty-fn (stx->list #'(ty-fns ...))]
                      #:when (syntax-parse ty-fn
                               [(~C→ t1 _) #:when (typecheck? #'ty1 #'t1) #t]
                               [_ #f]))
            ty-fn)
   --------
   [⊢ [_ ≫ (ro:map f- lst-) ⇒ : (CListof ty2)]]])

(define-typed-syntax sort
  [_:id ≫ ;; TODO: use polymorphism
   --------
   [⊢ [_ ≫ ro:sort ⇒ : (Ccase-> (C→ (CListof Any) LiftedPred2 (CListof Any))
                                (C→ (Listof Any) LiftedPred2 (Listof Any)))]]]
  [(_ e cmp) ≫
   [⊢ [e ≫ e- ⇒ : (~CListof τ)]]
   [⊢ [cmp ≫ cmp- ⇐ : (C→ τ τ Bool)]]
   --------
   [⊢ [_ ≫ (ro:sort e- cmp-) ⇒ : (CListof τ)]]]
  [(_ e cmp) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CListof τ) ...)]]
   [⊢ [cmp ≫ cmp- ⇐ : (C→ (U τ ...) (U τ ...) Bool)]]
   --------
   [⊢ [_ ≫ (ro:sort e- cmp-) ⇒ : (U (CListof τ) ...)]]]
  [(_ e cmp) ≫
   [⊢ [e ≫ e- ⇒ : (~CList . τs)]]
   [⊢ [cmp ≫ cmp- ⇐ : (C→ (U . τs) (U . τs) Bool)]]
   --------
   [⊢ [_ ≫ (ro:sort e- cmp-) ⇒ : (CListof (U . τs))]]]
  [(_ e cmp) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~CList τ ...) ...)]]
   [⊢ [cmp ≫ cmp- ⇐ : (C→ (U τ ... ...) (U τ ... ...) Bool)]]
   --------
   [⊢ [_ ≫ (ro:sort e- cmp-) ⇒ : (U (CList (U τ ...)) ...)]]])

;; ---------------------------------
;; IO and other built-in ops

(provide (typed-out [void : (C→ CUnit)]
                    [printf : (Ccase-> (C→ CString CUnit)
                                       (C→ CString Any CUnit)
                                       (C→ CString Any Any CUnit))]
                    [display : (C→ Any CUnit)]
                    [displayln : (C→ Any CUnit)]
                    [with-output-to-string : (C→ (C→ Any) CString)]
                    [string-contains? : (C→ CString CString CBool)]
                    [pretty-print : (C→ Any CUnit)]
                    [error : (Ccase-> (C→ (CU CString CSymbol) CNothing)
                                      (C→ CSymbol CString CNothing))]

                    [string-length : (C→ CString CNat)]
                    [string-append : (C→ CString CString CString)]

                    [equal? : LiftedPred2]
                    [eq? : LiftedPred2]
                    [distinct? : (Ccase-> (C→* [] [] #:rest (CListof CAny) CBool)
                                          (C→* [] [] #:rest (CListof Any) Bool)
                                          (C→* [] [] #:rest (Listof Any) Bool))]
                    
                    [pi : CNum]
                    
                    [add1 : (Ccase-> (C→ CNegInt (CU CNegInt CZero))
                                     (C→ NegInt (U NegInt Zero))
                                     (C→ CZero CPosInt)
                                     (C→ Zero PosInt)
                                     (C→ CPosInt CPosInt)
                                     (C→ PosInt PosInt)
                                     (C→ CNat CPosInt)
                                     (C→ Nat PosInt)
                                     (C→ CInt CInt)
                                     (C→ Int Int))]
                    [sub1 : (Ccase-> (C→ CNegInt CNegInt)
                                     (C→ NegInt NegInt)
                                     (C→ CZero CNegInt)
                                     (C→ Zero NegInt)
                                     (C→ CPosInt CNat)
                                     (C→ PosInt Nat)
                                     (C→ CNat CInt)
                                     (C→ Nat Int)
                                     (C→ CInt CInt)
                                     (C→ Int Int))]
                    [+ : (Ccase-> (C→ CZero)
                                  (C→* [] [] #:rest (CListof CNat) CNat)
                                  (C→* [] [] #:rest (CListof Nat) Nat)
                                  (C→* [] [] #:rest (Listof Nat) Nat)
                                  (C→* [] [] #:rest (CListof CInt) CInt)
                                  (C→* [] [] #:rest (CListof Int) Int)
                                  (C→* [] [] #:rest (Listof Int) Int)
                                  (C→* [] [] #:rest (CListof CNum) CNum)
                                  (C→* [] [] #:rest (CListof Num) Num)
                                  (C→* [] [] #:rest (Listof Num) Num))]
                    [- : (Ccase-> (C→ CInt CInt)
                                  (C→ CInt CInt CInt)
                                  (C→ CInt CInt CInt CInt)
                                  (C→ CInt CInt CInt CInt CInt)
                                  (C→ Int Int Int)
                                  (C→ Int Int Int Int)
                                  (C→ Int Int Int Int Int)
                                  (C→ CNum CNum CNum)
                                  (C→ CNum CNum CNum CNum)
                                  (C→ CNum CNum CNum CNum CNum)
                                  (C→ Num Num Num)
                                  (C→ Num Num Num Num)
                                  (C→ Num Num Num Num Num))]
                    [* : (Ccase-> (C→ CNat CNat CNat)
                                  (C→ CNat CNat CNat CNat)
                                  (C→ CNat CNat CNat CNat CNat)
                                  (C→ Nat Nat Nat)
                                  (C→ Nat Nat Nat Nat)
                                  (C→ Nat Nat Nat Nat Nat)
                                  (C→ CInt CInt CInt)
                                  (C→ CInt CInt CInt CInt)
                                  (C→ CInt CInt CInt CInt CInt)
                                  (C→ Int Int Int)
                                  (C→ Int Int Int Int)
                                  (C→ Int Int Int Int Int)
                                  (C→ CNum CNum CNum)
                                  (C→ CNum CNum CNum CNum)
                                  (C→ CNum CNum CNum CNum CNum)
                                  (C→ Num Num Num)
                                  (C→ Num Num Num Num)
                                  (C→ Num Num Num Num Num))]
                    [/ : (Ccase-> (C→ CNum CNum)
                                  (C→ CNum CNum CNum)
                                  (C→ CNum CNum CNum CNum)
                                  (C→ Num Num)
                                  (C→ Num Num Num)
                                  (C→ Num Num Num Num))]
                    [= : (Ccase-> (C→ CNum CNum CBool)
                                  (C→ CNum CNum CNum CBool)
                                  (C→ Num Num Bool)
                                  (C→ Num Num Num Bool))]
                    [< : (Ccase-> (C→ CNum CNum CBool)
                                  (C→ CNum CNum CNum CBool)
                                  (C→ Num Num Bool)
                                  (C→ Num Num Num Bool))]
                    [> : (Ccase-> (C→ CNum CNum CBool)
                                  (C→ CNum CNum CNum CBool)
                                  (C→ Num Num Bool)
                                  (C→ Num Num Num Bool))]
                    [<= : (Ccase-> (C→ CNum CNum CBool)
                                   (C→ CNum CNum CNum CBool)
                                   (C→ Num Num Bool)
                                   (C→ Num Num Num Bool))]
                    [>= : (Ccase-> (C→ CNum CNum CBool)
                                   (C→ CNum CNum CNum CBool)
                                   (C→ Num Num Bool)
                                   (C→ Num Num Num Bool))]
                    
                    [abs : (Ccase-> (C→ CPosInt CPosInt)
                                    (C→ PosInt PosInt)
                                    (C→ CZero CZero)
                                    (C→ Zero Zero)
                                    (C→ CNegInt CPosInt)
                                    (C→ NegInt PosInt)
                                    (C→ CInt CInt)
                                    (C→ Int Int)
                                    (C→ CNum CNum)
                                    (C→ Num Num))]
                    
                    [max : (Ccase-> (C→ CInt CInt CInt)
                                    (C→ CInt CInt CInt CInt)
                                    (C→ CNum CNum CNum)
                                    (C→ CNum CNum CNum CNum)
                                    (C→ Int Int Int)
                                    (C→ Int Int Int Int)
                                    (C→ Num Num Num)
                                    (C→ Num Num Num Num))]
                    [min : (Ccase-> (C→ CInt CInt CInt)
                                    (C→ CInt CInt CInt CInt)
                                    (C→ CNum CNum CNum)
                                    (C→ CNum CNum CNum CNum)
                                    (C→ Int Int Int)
                                    (C→ Int Int Int Int)
                                    (C→ Num Num Num)
                                    (C→ Num Num Num Num))] 
                    ;; out type for these fns must be CNum, because of +inf.0 and +nan.0
                    [floor : (Ccase-> (C→ CNum CNum)
                                      (C→ Num Num))]
                    [ceiling : (Ccase-> (C→ CNum CNum)
                                        (C→ Num Num))]
                    [truncate : (Ccase-> (C→ CNum CNum)
                                         (C→ Num Num))]
                    [sgn : (Ccase-> (C→ CZero CZero)
                                    (C→ Zero Zero)
                                    (C→ CInt CInt)
                                    (C→ Int Int)
                                    (C→ CNum CNum)
                                    (C→ Num Num))]
                    
                    [expt : (Ccase-> (C→ CNum CZero CPosInt)
                                     (C→ Num Zero PosInt)
                                     (C→ CInt CInt CInt)
                                     (C→ Int Int Int)
                                     (C→ CNum CNum CNum)
                                     (C→ Num Num Num))]
                    
                    [not : LiftedPred]
                    [xor : (Ccase-> (C→ CAny CAny CAny)
                                    (C→ Any Any Any))]
                    [false? : LiftedPred]
                    
                    [true : CTrue]
                    [false : CFalse]
                    [real->integer : (C→ Num Int)]
                    [string? : UnliftedPred]
                    [number? : LiftedPred]
                    [positive? : LiftedNumPred]
                    [negative? : LiftedNumPred]
                    [zero? : LiftedNumPred]
                    [even? : LiftedIntPred]
                    [odd? : LiftedIntPred]
                    [inexact->exact : (Ccase-> (C→ CNum CNum)
                                               (C→ Num Num))]
                    [exact->inexact : (Ccase-> (C→ CNum CNum)
                                               (C→ Num Num))]
                    [quotient : (Ccase-> (C→ CInt CInt CInt)
                                         (C→ Int Int Int))]
                    [remainder : (Ccase-> (C→ CInt CInt CInt)
                                          (C→ Int Int Int))]
                    [modulo : (Ccase-> (C→ CInt CInt CInt)
                                       (C→ Int Int Int))]
                    
                    ;; rosette-specific
                    [pc : (C→ Bool)]
                    [asserts : (C→ CAsserts)]
                    [clear-asserts! : (C→ CUnit)]))

;; ---------------------------------
;; more built-in ops

;(define-rosette-primop boolean? : (C→ Any Bool))
(define-typed-syntax boolean?
  [_:id ≫
   --------
   [⊢ (mark-solvablem
       (add-typeform
        ro:boolean?
        Bool)) ⇒ LiftedPred]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇒ ty]
   --------
   [⊢ (ro:boolean? e-) ⇒ #,(if (concrete? #'ty) #'CBool #'Bool)]])

;(define-rosette-primop integer? : (C→ Any Bool))
(define-typed-syntax integer?
  [_:id ≫
   --------
   [⊢ (mark-solvablem
       (add-typeform
        ro:integer?
        Int)) ⇒ LiftedPred]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇒ ty]
   --------
   [⊢ (ro:integer? e-) ⇒ #,(if (concrete? #'ty) #'CBool #'Bool)]])

;(define-rosette-primop real? : (C→ Any Bool))
(define-typed-syntax real?
  [_:id ≫
   --------
   [⊢ (mark-solvablem
       (add-typeform
        ro:real?
        Num)) ⇒ LiftedPred]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇒ ty]
   --------
   [⊢ (ro:real? e-) ⇒ #,(if (concrete? #'ty) #'CBool #'Bool)]])

(define-typed-syntax time
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : ty]]
   --------
   [⊢ [_ ≫ (ro:time e-) ⇒ : ty]]])

;; ---------------------------------
;; mutable boxes

(define-typed-syntax box
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : τ]]
   --------
   [⊢ [_ ≫ (ro:box e-) ⇒ : (CMBoxof τ)]]])

(define-typed-syntax box-immutable
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : τ]]
   --------
   [⊢ [_ ≫ (ro:box-immutable e-) ⇒ : (CIBoxof τ)]]])

(define-typed-syntax unbox
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~or (~CMBoxof τ) (~CIBoxof τ))]]
   --------
   [⊢ [_ ≫ (ro:unbox e-) ⇒ : τ]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : (~U* (~and (~or (~CMBoxof τ) (~CIBoxof τ))) ...)]]
   --------
   [⊢ [_ ≫ (ro:unbox e-) ⇒ : (U τ ...)]]])

;; TODO: implement multiple values
;; result type should be (Valuesof ty CAsserts)
(define-typed-syntax with-asserts
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : ty]]
   --------
   [⊢ [_ ≫ (ro:with-asserts e-) ⇒ : ty]]])

(provide (typed-out
          [term-cache
           : (Ccase-> (C→ (CHashTable Any Any))
                      (C→ (CHashTable Any Any) CUnit))]
          [clear-terms! 
           : (Ccase-> (C→ CUnit)
                      (C→ CFalse CUnit)
                      (C→ (CListof Any) CUnit))])) ; list of terms

;; ---------------------------------
;; BV Types and Operations

;; this must be a macro in order to support Racket's overloaded set/get
;; parameter patterns
(define-typed-syntax current-bitwidth
  [_:id ≫
   --------
   [⊢ [_ ≫ ro:current-bitwidth ⇒ : (CParamof (CU CFalse CPosInt))]]]
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:current-bitwidth) ⇒ : (CU CFalse CPosInt)]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇐ : (CU CFalse CPosInt)]]
   --------
   [⊢ [_ ≫ (ro:current-bitwidth e-) ⇒ : CUnit]]])

(define-named-type-alias BVMultiArgOp (Ccase-> (C→ BV BV BV)
                                               (C→ BV BV BV BV)))

(provide (typed-out [bv : (Ccase-> (C→ CInt CBVPred CBV)
                                   (C→ CInt CPosInt CBV))]
                    [bv? : LiftedPred]
                    
                    [bveq : (C→ BV BV Bool)]
                    [bvslt : (C→ BV BV Bool)]
                    [bvult : (C→ BV BV Bool)]
                    [bvsle : (C→ BV BV Bool)]
                    [bvule : (C→ BV BV Bool)]
                    [bvsgt : (C→ BV BV Bool)]
                    [bvugt : (C→ BV BV Bool)]
                    [bvsge : (C→ BV BV Bool)]
                    [bvuge : (C→ BV BV Bool)]
                    
                    [bvnot : (C→ BV BV)]
                    
                    [bvand : (C→ BV BV BV)]
                    [bvor : (C→ BV BV BV)]
                    [bvxor : (C→ BV BV BV)]
                    
                    [bvshl : (C→ BV BV BV)]
                    [bvlshr : (C→ BV BV BV)]
                    [bvashr : (C→ BV BV BV)]
                    [bvneg : (C→ BV BV)]
                    
                    [bvadd : BVMultiArgOp]
                    [bvsub : BVMultiArgOp]
                    [bvmul : BVMultiArgOp]
                    
                    [bvsdiv : (C→ BV BV BV)]
                    [bvudiv : (C→ BV BV BV)]
                    [bvsrem : (C→ BV BV BV)]
                    [bvurem : (C→ BV BV BV)]
                    [bvsmod : (C→ BV BV BV)]
                    
                    [concat : BVMultiArgOp]
                    [extract : (C→ Int Int BV BV)]
                    [sign-extend : (C→ BV BVPred BV)]
                    [zero-extend : (C→ BV BVPred BV)]
                    
                    [bitvector->integer : (C→ BV Int)]
                    [bitvector->natural : (C→ BV Nat)]
                    [integer->bitvector : (C→ Int BVPred BV)]
                    
                    [bitvector-size : (C→ CBVPred CPosInt)]))

;(define-rosette-primop bitvector : (C→ CPosInt CBVPred))
(define-typed-syntax bitvector
  [_:id ≫
   --------
   [⊢ ro:bitvector ⇒ (C→ CPosInt CBVPred)]]
  [(_ n) ≫
   [⊢ n ≫ n- ⇐ CPosInt]
   --------
   [⊢ (mark-solvablem
       (add-typeform
        (ro:bitvector n-)
        BV)) ⇒ CBVPred]])

;; bitvector? can produce type CFalse if input does not have type (C→ Any Bool)
;; result is always CBool, since anything symbolic returns false
;(define-rosette-primop bitvector? : (C→ Any Bool))
(define-typed-syntax bitvector?
  [_:id ≫
   --------
   [⊢ ro:bitvector? ⇒ UnliftedPred]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇐ LiftedPred]
   --------
   [⊢ (ro:bitvector? e-) ⇒ CBool]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇒ _]
   --------
   [⊢ (ro:bitvector? e-) ⇒ CFalse]])

;; ---------------------------------
;; Uninterpreted functions

(define-typed-syntax ~>
  [(_ pred? ...+ out) ≫
   [⊢ pred? ≫ pred?- (⇒ : _) (⇒ typefor ty) (⇒ solvable? s?) (⇒ function? f?)] ...
   [⊢ out ≫ out- (⇒ : _) (⇒ typefor ty-out) (⇒ solvable? out-s?) (⇒ function? out-f?)]
   #:fail-unless (stx-andmap syntax-e #'(s? ... out-s?))
                 (format "Expected a Rosette-solvable type, given ~a." 
                         (syntax->datum #'(pred? ... out)))
   #:fail-when (stx-ormap syntax-e #'(f? ... out-f?))
               (format "Expected a non-function Rosette type, given ~a." 
                       (syntax->datum #'(pred? ... out)))
   --------
   [⊢ (mark-solvablem
       (mark-functionm
        (add-typeform
         (ro:~> pred?- ... out-)
         (→ ty ... ty-out)))) ⇒ LiftedPred]])

(provide (typed-out [fv? : LiftedPred]))

;; function? can produce type CFalse if input does not have type (C→ Any Bool)
;; result is always CBool, since anything symbolic returns false
;(define-rosette-primop function? : (C→ Any Bool))
(define-typed-syntax function?
  [_:id ≫
   --------
   [⊢ ro:function? ⇒ UnliftedPred]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇐ LiftedPred]
   --------
   [⊢ (ro:function? e-) ⇒ CBool]]
  [(_ e) ≫
   [⊢ e ≫ e- ⇒ _]
   --------
   [⊢ (ro:function? e-) ⇒ CFalse]])

;; ---------------------------------
;; Logic operators
(provide (typed-out [! : (C→ Bool Bool)]
                    [<=> : (C→ Bool Bool Bool)]
                    [=> : (C→ Bool Bool Bool)]))

(define-typed-syntax &&
  [_:id ≫
   --------
   [⊢ [_ ≫ ro:&& ⇒ :
           (Ccase-> (C→ Bool)
                    (C→ Bool Bool)
                    (C→ Bool Bool Bool))]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇐ : Bool] ...]
   --------
   [⊢ [_ ≫ (ro:&& e- ...) ⇒ : Bool]]])
(define-typed-syntax ||
  [_:id ≫
   --------
   [⊢ [_ ≫ ro:|| ⇒ :
           (Ccase-> (C→ Bool)
                    (C→ Bool Bool)
                    (C→ Bool Bool Bool))]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇐ : Bool] ...]
   --------
   [⊢ [_ ≫ (ro:|| e- ...) ⇒ : Bool]]])

(define-typed-syntax and
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:and) ⇒ : CTrue]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇐ : Bool] ...]
   --------
   [⊢ [_ ≫ (ro:and e- ...) ⇒ : Bool]]]
  [(_ e ... elast) ≫
   [⊢ [e ≫ e- ⇒ : ty] ...]
   [⊢ [elast ≫ elast- ⇒ : ty-last]]
   --------
   [⊢ [_ ≫ (ro:and e- ... elast-) ⇒ : (U CFalse ty-last)]]])
(define-typed-syntax or
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:or) ⇒ : CFalse]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇐ : Bool] ...]
   --------
   [⊢ [_ ≫ (ro:or e- ...) ⇒ : Bool]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇒ : ty] ...]
   --------
   [⊢ [_ ≫ (ro:or efirst- e- ...) ⇒ : (U ty ...)]]])
(define-typed-syntax nand
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:nand) ⇒ : CFalse]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇒ : _] ...]
   --------
   [⊢ [_ ≫ (ro:nand e- ...) ⇒ : Bool]]])
(define-typed-syntax nor
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:nor) ⇒ : CTrue]]]
  [(_ e ...) ≫
   [⊢ [e ≫ e- ⇒ : _] ...]
   --------
   [⊢ [_ ≫ (ro:nor e- ...) ⇒ : Bool]]])
(define-typed-syntax implies
  [(_ e1 e2) ≫
   --------
   [_ ≻ (if e1 e2 (stlc+union:#%datum . #t))]])

;; ---------------------------------
;; solver forms

(provide (typed-out [sat? : UnliftedPred]
                    [unsat? : UnliftedPred]
                    [solution? : UnliftedPred]
                    [unknown? : UnliftedPred]
                    [sat : (Ccase-> (C→ CSolution)
                                    (C→ (CHashTable Any Any) CSolution))]
                    [unsat : (Ccase-> (C→ CSolution)
                                      (C→ (CListof Bool) CSolution))]
                    [unknown : (C→ CSolution)]
                    [model : (C→ CSolution (CHashTable Any Any))]
                    [core : (C→ CSolution (U (Listof Any) CFalse))]))

;(define-rosette-primop forall : (C→ (CListof Any) Bool Bool))
;(define-rosette-primop exists : (C→ (CListof Any) Bool Bool))
(define-typed-syntax forall
  [(_ vs body) ≫
   ;; TODO: allow U of Constants?
   [⊢ [vs ≫ vs- ⇒ : (~CListof ~! ty)]]
   #:fail-unless (Constant*? #'ty)
   (format "Expected list of symbolic constants, given list of ~a" 
           (type->str #'ty))
   [⊢ [body ≫ body- ⇐ : Bool]]
   --------
   [⊢ [_ ≫ (ro:forall vs- body-) ⇒ : Bool]]]
  [(_ vs body) ≫
   [⊢ [vs ≫ vs- ⇒ : (~CList ~! ty ...)]]
   #:fail-unless (stx-andmap Constant*? #'(ty ...))
   (format "Expected list of symbolic constants, given list containing: ~a" 
           (string-join (stx-map type->str #'(ty ...)) ", "))
   [⊢ [body ≫ body- ⇐ : Bool]]
   --------
   [⊢ [_ ≫ (ro:forall vs- body-) ⇒ : Bool]]])
(define-typed-syntax exists
  [(_ vs body) ≫
   [⊢ [vs ≫ vs- ⇒ : (~CListof ~! ty)]]
   ;; TODO: allow U of Constants?
   #:fail-unless (Constant*? #'ty)
   (format "Expected list of symbolic constants, given list of ~a" 
           (type->str #'ty))
   [⊢ [body ≫ body- ⇐ : Bool]]
   --------
   [⊢ [_ ≫ (ro:exists vs- body-) ⇒ : Bool]]]
  [(_ vs body) ≫
   [⊢ [vs ≫ vs- ⇒ : (~CList ~! ty ...)]]
   #:fail-unless (stx-andmap Constant*? #'(ty ...))
   (format "Expected list of symbolic constants, given list containing: ~a" 
           (string-join (stx-map type->str #'(ty ...)) ", "))
   [⊢ [body ≫ body- ⇐ : Bool]]
   --------
   [⊢ [_ ≫ (ro:exists vs- body-) ⇒ : Bool]]])

(define-typed-syntax verify
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:verify e-) ⇒ : CSolution]]]
  [(_ #:assume ae #:guarantee ge) ≫
   [⊢ [ae ≫ ae- ⇒ : _]]
   [⊢ [ge ≫ ge- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:verify #:assume ae- #:guarantee ge-) ⇒ : CSolution]]])

(define-typed-syntax evaluate
  [(_ v s) ≫
   [⊢ [v ≫ v- ⇒ : (~Constant* ty)]]
   [⊢ [s ≫ s- ⇐ : CSolution]]
   --------
   [⊢ [_ ≫ (ro:evaluate v- s-) ⇒ : ty]]]
  [(_ v s) ≫
   [⊢ [v ≫ v- ⇒ : ty]]
   [⊢ [s ≫ s- ⇐ : CSolution]]
   --------
   [⊢ [_ ≫ (ro:evaluate v- s-) ⇒ : #,(remove-Constant #'ty)]]])

;; TODO: enforce list of constants?
(define-typed-syntax synthesize
  [(_ #:forall ie #:guarantee ge) ≫
   [⊢ [ie ≫ ie- ⇐ : (CListof Any)]]
   [⊢ [ge ≫ ge- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:synthesize #:forall ie- #:guarantee ge-) ⇒ : CSolution]]]
  [(_ #:forall ie #:assume ae #:guarantee ge) ≫
   [⊢ [ie ≫ ie- ⇐ : (CListof Any)]]
   [⊢ [ae ≫ ae- ⇒ : _]]
   [⊢ [ge ≫ ge- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:synthesize #:forall ie- #:assume ae- #:guarantee ge-) ⇒ : CSolution]]])

(define-typed-syntax solve
  [(_ e) ≫
   [⊢ [e ≫ e- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:solve e-) ⇒ : CSolution]]])

(define-typed-syntax optimize
  [(_ #:guarantee ge) ≫
   [⊢ [ge ≫ ge- ⇒ : _]]
   --------
   [⊢ [_ ≫ (ro:optimize #:guarantee ge-) ⇒ : CSolution]]]
  [(_ #:minimize mine #:guarantee ge) ≫
   [⊢ [ge ≫ ge- ⇒ : _]]
   [⊢ [mine ≫ mine- ⇐ : (CListof (U Num BV))]]
   --------
   [⊢ [_ ≫ (ro:optimize #:minimize mine- #:guarantee ge-) ⇒ : CSolution]]]
  [(_ #:maximize maxe #:guarantee ge) ≫
   [⊢ [ge ≫ ge- ⇒ : _]]
   [⊢ [maxe ≫ maxe- ⇐ : (CListof (U Num BV))]]
   --------
   [⊢ [_ ≫ (ro:optimize #:maximize maxe- #:guarantee ge-) ⇒ : CSolution]]]
  [(_ #:minimize mine #:maximize maxe #:guarantee ge) ≫
   [⊢ [ge ≫ ge- ⇒ : _]]
   [⊢ [maxe ≫ maxe- ⇐ : (CListof (U Num BV))]]
   [⊢ [mine ≫ mine- ⇐ : (CListof (U Num BV))]]
   --------
   [⊢ [_ ≫ (ro:optimize #:minimize mine- #:maximize maxe- #:guarantee ge-) ⇒ : CSolution]]]
  [(_ #:maximize maxe #:minimize mine #:guarantee ge) ≫
   [⊢ [ge ≫ ge- ⇒ : _]]
   [⊢ [maxe ≫ maxe- ⇐ : (CListof (U Num BV))]]
   [⊢ [mine ≫ mine- ⇐ : (CListof (U Num BV))]]
   --------
   [⊢ [_ ≫ (ro:optimize #:maximize maxe- #:minimize mine- #:guarantee ge-) ⇒ : CSolution]]])

;; this must be a macro in order to support Racket's overloaded set/get
;; parameter patterns
(define-typed-syntax current-solver
  [_:id ≫
   --------
   [⊢ [_ ≫ ro:current-solver ⇒ : (CParamof CSolver)]]]
  [(_) ≫
   --------
   [⊢ [_ ≫ (ro:current-solver) ⇒ : CSolver]]]
  [(_ e) ≫
   [⊢ [e ≫ e- ⇐ : CSolver]]
   --------
   [⊢ [_ ≫ (ro:current-solver e-) ⇒ : CUnit]]])

;(define-rosette-primop gen:solver : CSolver)
(provide (typed-out
          [solver? : UnliftedPred]
          [solver-assert : (C→ CSolver (CListof Bool) CUnit)]
          [solver-clear : (C→ CSolver CUnit)]
          [solver-minimize : (C→ CSolver (CListof (U Int Num BV)) CUnit)]
          [solver-maximize : (C→ CSolver (CListof (U Int Num BV)) CUnit)]
          [solver-check : (C→ CSolver CSolution)]
          [solver-debug : (C→ CSolver CSolution)]
          [solver-shutdown : (C→ CSolver CUnit)]))
;; this is in rosette/solver/smt/z3 (is not in #lang rosette)
;; make this part of base typed/rosette or separate lib?
;(define-rosette-primop z3 : (C→ CSolver))

;; ---------------------------------
;; Reflecting on symbolic values

(provide (typed-out
          [term? : UnliftedPred]
          [expression? : UnliftedPred]
          [constant? : UnliftedPred]
          [type? : UnliftedPred]
          [solvable? : UnliftedPred]
          [union? : UnliftedPred]))

(define-typed-syntax union-contents
  [(_ u) ≫
   ;; TODO: can U sometimes be converted to CU?
   [⊢ [u ≫ u- ⇒ : (~and τ (~U* _ ...))]] ; input must be symbolic, and not constant
   --------
   [⊢ [_ ≫ (ro:union-contents u-) ⇒ : (CListof (CPair Bool τ))]]])

;; TODO: add match and match expanders

;; TODO: should a type-of expression have a solvable stx prop?
(provide (typed-out [type-of : (Ccase-> (C→ Any LiftedPred)
                                        (C→ Any Any LiftedPred))]
                    [any/c : (C→ Any CTrue)]))

(define-typed-syntax for/all
  ;; symbolic e
  [(_ ([x:id e]) e_body) ≫
   [⊢ [e ≫ e- ⇒ : (~U* τ_x)]]
   [() ([x ≫ x- : τ_x]) ⊢ [e_body ≫ e_body- ⇒ : τ_body]]
   --------
   [⊢ [_ ≫ (ro:for/all ([x- e-]) e_body-) ⇒ : (U τ_body)]]]
  [(_ ([x:id e]) e_body) ≫
   [⊢ [e ≫ e- ⇒ : τ_x]]
   [() ([x ≫ x- : τ_x]) ⊢ [e_body ≫ e_body- ⇒ : τ_body]]
   --------
   [⊢ [_ ≫ (ro:for/all ([x- e-]) e_body-) ⇒ : (U τ_body)]]])

(define-typed-syntax for*/all
  [(_ () e_body) ≫
   --------
   [_ ≻ e_body]]
  [(_ ([x e] [x_rst e_rst] ...) e_body) ≫
   --------
   [_ ≻ (for/all ([x e]) (for*/all ([x_rst e_rst] ...) e_body))]])


