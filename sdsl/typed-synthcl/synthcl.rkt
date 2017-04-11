#lang turnstile
(extends typed/main #:prefix rosette:
 #:except : ! #%app || && void = * + - / #%datum if assert verify < <= > >= for range)
(require (prefix-in ro: (combine-in rosette rosette/lib/synthax))
         (prefix-in cl: "synthcl-model.rkt")
         (only-in "../../typed/rosette.rkt" ~CUnit))

(begin-for-syntax
  (define (mk-cl id) (format-id #'here "cl:~a" id))
  (current-host-lang mk-cl))

(provide
 (rename-out [synth-app #%app])
 procedure kernel grammar #%datum if range for print
 choose ?? @ locally-scoped assert synth verify
 int int2 int3 int4 int16 float float2 float3 float4 float16
 int* int2* int3* int4* int16* float* float2* float3* float4* float16*
 bool void void* char*
 cl_context cl_command_queue cl_program cl_kernel cl_mem
 : ! ?: == + * / - sqrt || && % << $ & > >= < <= != = += -= *= /= %= $= &=
 sizeof clCreateProgramWithSource
 (typed-out
  [clCreateContext : (C→ cl_context)]
  [clCreateCommandQueue : (C→ cl_context cl_command_queue)]
  [clCreateBuffer : (C→ cl_context int int cl_mem)]
  [clEnqueueReadBuffer : (C→ cl_command_queue cl_mem int int void* void)]
  [clEnqueueWriteBuffer : (C→ cl_command_queue cl_mem int int void* void)]
  [clEnqueueNDRangeKernel : (C→ cl_command_queue cl_kernel int int* int* int* void)]
  [clCreateKernel : (C→ cl_program char* cl_kernel)]
  [clSetKernelArg : (Ccase-> (C→ cl_kernel int cl_mem void)
                             (C→ cl_kernel int int void)
                             (C→ cl_kernel int float void))]
  [get_global_id : (C→ int int)]
  [CL_MEM_READ_ONLY : int] [CL_MEM_WRITE_ONLY : int] [CL_MEM_READ_WRITE : int]
  [malloc : (C→ int void*)]
  [memset : (C→ void* int int void*)]
  [convert_float4 : (Ccase-> (C→ int4 float4) (C→ float4 float4))]
  [convert_int4   : (Ccase-> (C→ int4 int4)   (C→ float4 int4))]
  [get_work_dim : (C→ int)]
  [NULL : void*]))

(begin-for-syntax
  (current-typecheck-relation (current-type=?)) ; no subtyping
  (define (typecheck/un? t1 t2) ; typecheck unexpanded types
    (typecheck? ((current-type-eval) t1) ((current-type-eval) t2)))
  (define (pointer-type? t) (Pointer? t))
  (define (real-type? t)
    (and (not (pointer-type? t)) (not (typecheck/un? t #'char*))))
  (define (real-type<=? t1 t2)
    (and (real-type? t1) (real-type? t2)
         (or (typecheck? t1 t2) ; need type= to distinguish reals/ints
             (typecheck/un? t1 #'bool)
             (and (typecheck/un? t1 #'int) (not (typecheck/un? t2 #'bool)))
             (and (typecheck/un? t1 #'float)
                  (typecheck/un? (get-base/un t2) #'float)))))
  ;; same as common-real-type from model/reals.rkt
  ;; Returns the common real type of the given types, as specified in
  ;; Ch. 6.2.6 of opencl-1.2 specification.  returns #f if none
  (define common-real-type
    (case-lambda 
      [(t) (and (real-type? t) t)]
      [(t1 t2) (or (and (real-type<=? t1 t2) t2)
                   (and (real-type<=? t2 t1) t1))]
      [ts (common-real-type (car ts) (apply common-real-type (cdr ts)))]))
  (current-join common-real-type)
  ;; copied from check-implicit-conversion in lang/types.rkt
  ;; TODO: should this exn? it is used in stx-parse that may want to backtrack
  (define (cast-ok? from to [expr #f] [subexpr #f])
    (unless (or (typecheck/un? from to)
                (and (scalar-type? from) (scalar-type? to))
                (and (scalar-type? from) (vector-type? to))
                (and (pointer-type? from) (pointer-type? to))
                #;(and (equal? from cl_mem) (pointer-type? to)))
      (raise-syntax-error #f
        (format "no implicit conversion from ~a to ~a"
                (type->str from) (type->str to)) expr subexpr)))
  (define (mk-ptr id) (format-id id "~a*" id))
  (define (mk-mk id [ctx id]) (format-id ctx "mk-~a" id))
  (define (mk-to id) (format-id id "to-~a" id))
  (define (add-construct stx fn) (set-stx-prop/preserved stx 'construct fn))
  (define (add-convert stx fn)   (set-stx-prop/preserved stx 'convert fn))
  (define (get-construct stx)    (syntax-property stx 'construct))
  (define (get-convert stx)
    (let ([conv (syntax-property stx 'convert)]) (or conv #'(λ (x) x))))
  (define (ty->len ty) (regexp-match #px"([a-z]+)([0-9]+)" (type->str ty)))
  (define (real-type-length t)
    (define split-ty (ty->len t))
    (string->number
     (or (and split-ty (third split-ty)) "1")))
  (define (uneval ty #:ctx [ctx #'here] #:str-fn [str-fn (λ (x) x)])
    (datum->syntax ctx (string->symbol (str-fn (type->str ty)))))
  (define (get-base/un ty [ctx #'here]) ; returns unexpanded base type
    (uneval ty #:ctx ctx #:str-fn (λ (s) (car (regexp-match #px"[a-z]+" s)))))
  (define (get-base ty [ctx #'here]) ((current-type-eval) (get-base/un ty ctx)))
  (define (get-pointer-base ty [ctx #'here]) ; returns unexpanded ptr base
    (uneval ty #:ctx ctx #:str-fn (λ (s) (string-trim s "*"))))
  (define (vector-type? ty)
    (define tstr (type->str ty))
    (ormap (λ (x) (string=? x tstr)) '("int2" "int3" "int4" "int16" "float2" "float3" "float4" "float16")))
  (define (scalar-type? ty)
    (or (typecheck/un? ty #'bool)
        (and (real-type? ty) (not (vector-type? ty))))))

(define-syntax-parser add-convertm   [(_ stx fn) (add-convert #'stx #'fn)])
(define-syntax-parser add-constructm [(_ stx fn) (add-construct #'stx #'fn)])

(ro:define (to-bool v) (ro:#%app (ro:#%app cl:bool) v))

(define-named-type-alias void rosette:CUnit)
(begin-for-syntax
  (define-syntax ~void
    (pattern-expander
     (syntax-parser
       [_:id #'~CUnit][(_:id) #'(~CUnit)])))
  (define void? rosette:CUnit?))
(define-base-types #;void cl_context cl_command_queue cl_program cl_kernel cl_mem)
(define-type-constructor Pointer #:arity = 1)
(define-named-type-alias void* (Pointer void))
(define-named-type-alias char* rosette:CString)
(define-named-type-alias bool  (add-convertm rosette:Bool to-bool))

(define-simple-macro (define-scalar-type TY #:from BASE)
 #:with define-TY (format-id #'TY "define-~a" #'TY)
 #:with define-TYs (format-id #'TY "define-~as" #'TY)
 #:with TY* (mk-ptr #'TY)
 #:with to-TY (mk-to #'TY)
 #:with to-TY* (mk-ptr #'to-TY)
 #:with mk-TY (mk-mk #'TY)
 #:with cl-TY (mk-cl #'TY)
 (begin-
  (ro:define (to-TY v)  (ro:#%app (ro:#%app cl-TY) v))
  (ro:define (to-TY* v) (cl:pointer-cast v cl-TY))
  (ro:define (mk-TY v)  (ro:#%app cl-TY v))
  (define-named-type-alias TY  (add-convertm BASE to-TY))
  (define-named-type-alias TY* (add-convertm (Pointer TY) to-TY*))
  (define-syntax define-TY ; defines a TY vector type of length n
   (syntax-parser
    [(_ n)
     #:with TYn (format-id #'n "~a~a" #'TY (syntax->datum #'n))
     #:with TYn* (mk-ptr #'TYn)
     #:with to-TYn (mk-to #'TYn)
     #:with mk-TYn (mk-mk #'TYn)
     #:with to-TYn* (mk-ptr #'to-TYn)
     #:with mk-TYn* (mk-ptr #'mk-TYn)
     #:with cl-TYn (mk-cl #'TYn)
     #:with TYs (build-list (stx->datum #'n) (λ _ #'TY))
     #'(begin-
        (define-named-type-alias TYn
         (add-constructm (add-convertm (rosette:CVector . TYs) to-TYn) mk-TYn))
        (define-named-type-alias TYn* (add-convertm (Pointer TYn) to-TYn*))
        (ro:define (to-TYn v) ; not using cl-Tyn bc I need to handle lists
         (ro:cond
          [(ro:list? v)
           (ro:apply mk-TYn (ro:for/list ([i n]) (to-TY (ro:list-ref v i))))]
          [(ro:vector? v)
           (ro:apply mk-TYn (ro:for/list ([i n]) (to-TY (ro:vector-ref v i))))]
          [else (ro:apply mk-TYn (ro:make-list n (to-TY v)))]))
        (ro:define (to-TYn* v) (cl:pointer-cast v cl-TYn))
        (ro:define (mk-TYn . ns) (ro:apply cl-TYn ns)))]))
  (... (define-simple-macro (define-TYs n ...) (begin- (define-TY n) ...)))))

(define-scalar-type int #:from rosette:Int)
(define-ints 2 3 4 16)
(define-scalar-type float #:from rosette:Num)
(define-floats 2 3 4 16)

(define-typed-syntax synth-app
  [(_ (ty:type) e) ≫ ; cast
   [⊢ e ≫ e- ⇒ ty-e]
   #:when (cast-ok? #'ty-e #'ty.norm #'e) ; raises exn
   #:with convert (get-convert #'ty.norm)
   --------
   [⊢ (ro:#%app convert e-) ⇒ ty.norm]]
  [(_ ty:type e ...) ≫ ; construct
   [⊢ e ≫ e- ⇒ ty-e] ...
   #:with construct (get-construct #'ty.norm)
   #:fail-unless (syntax-e #'construct)
     (format "no constructor found for ~a type" (type->str #'ty.norm))
   --------
   [⊢ (ro:#%app construct e- ...) ⇒ ty.norm]]
  [(_ p _) ≫ ; applying ptr to one arg is selector
   [⊢ p ≫ _ ⇒ (~Pointer ~void)]
   -----------
   [#:error (type-error #:src this-syntax
       #:msg (fmt "cannot dereference a void* pointer: ~a\n"(stx->datum #'p)))]]
  [(_ ptr sel) ≫ ; applying ptr to one arg is selector
   [⊢ ptr ≫ ptr- ⇒ ty-ptr]
   #:when (pointer-type? #'ty-ptr) #:with ~! #'dummy ; commit
   [⊢ sel ≫ sel- ⇐ int]
   --------
   [⊢ (cl:pointer-ref ptr- sel-) ⇒ #,(get-pointer-base #'ty-ptr)]]
  [(_ vec sel) ≫ ; applying vector to one arg is selector
   [⊢ vec ≫ vec- ⇒ ty-vec]
   #:when (vector-type? #'ty-vec)
   #:with selector (cl:parse-selector #t #'sel this-syntax)
   #:do [(define split-ty (ty->len #'ty-vec))]
   #:when (and split-ty (= 3 (length split-ty)))
   #:do [(define base-str (cadr split-ty))
         (define len-str (caddr split-ty))]
   #:do [(define sels (length (stx->list #'selector)))]
   #:with e-out (if (= sels 1) #'(ro:vector-ref vec- (ro:car 'selector))
                               #'(ro:for/list ([idx 'selector])
                                   (ro:vector-ref vec- idx)))
   #:with ty-out ((current-type-eval)
                  (if (= sels 1) (format-id #'here "~a" base-str)
                                 (format-id #'here "~a~a"
                                   base-str (length (stx->list #'selector)))))
   #:with convert (get-convert #'ty-out)
   --------
   [⊢ (ro:#%app convert e-out) ⇒ ty-out]]
  [(_ f e ...) ≫
   [⊢ f ≫ f- ⇒ (~C→ ty-in ... ty-out)]
   [⊢ e ≫ e- ⇒ ty-e] ...
   #:when (stx-andmap cast-ok? #'(ty-e ...) #'(ty-in ...))
   --------
   [⊢ (ro:#%app f- e- ...) ⇒ ty-out]]
  [(_ . es) ≫ --- [≻ (rosette:#%app . es)]])

;; top-level fns --------------------------------------------------
(define-typed-syntax procedure
  [(~and (_ ty-out:type (f [ty:type x:id] ...)) ~!) ≫ ; empty body
   #:fail-unless (void? #'ty-out.norm)
                 (format "expected void, given ~a" (type->str #'ty-out.norm))
   --------
   [≻ (rosette:define (f [x : ty] ...) -> void (⊢m (ro:void) void))]]
  [(_ ty-out:type (f [ty:type x:id] ...) e ... e-body) ≫
   #:with (conv ...) (stx-map get-convert #'(ty.norm ...))
   #:with f- (add-orig (generate-temporary #'f) #'f)
   --------
   [≻ (begin-
        (define-syntax- f (make-rename-transformer (⊢ f- : (C→ ty ... ty-out))))
        (define- f-
          (lambda- (x ...)
            (rosette:let ([x (⊢m (ro:#%app conv x) ty)] ...)
              (⊢m (ro:let () e ... (rosette:ann e-body : ty-out)) ty-out))))
        (provide- f))]])

(define-typed-syntax (kernel ty-out:type (f [ty:type x:id] ...) e ...) ≫
  #:fail-unless (void? #'ty-out.norm)
                (format "expected void, given ~a" (type->str #'ty-out.norm))
   --- [≻ (procedure void (f [ty x] ...) e ...)])

(define-typed-syntax grammar
  [(_ ty-out:type (f [ty:type x:id] ... [ty-depth k]) #:base be #:else ee) ≫
   #:with f- (generate-temporary #'f)
   #:with (a ...) (generate-temporaries #'(x ...))
   --------
   [≻ (ro:begin
       (ro:define-synthax (f- x ... k) #:base (rosette:ann be : ty-out)
                                       #:else (rosette:ann ee : ty-out))
       (define-typed-syntax f
         [(ff a ... j) ≫
          [⊢ a ≫ _ ⇐ ty] ...
          [⊢ j ≫ _ ⇐ ty-depth] ; j will be eval'ed, so strip its context
          #:with j- (assign-type (datum->syntax #'H (stx->datum #'j)) #'int)
          #:with f-- (replace-stx-loc #'f- #'ff)
          -----------
          [⊢ (f-- a ... j-) ⇒ ty-out]]))]]
  [(_ ty-out:type (f [ty:type x:id] ...) e) ≫
   #:with f- (generate-temporary #'f)
   --------
   [≻ (ro:begin
       (define-typed-syntax f
         [(ff . args) ≫
          #:with (a- (... ...)) (stx-map expand/ro #'args)
          #:with tys (stx-map typeof #'(a- (... ...)))
          #:with tys-expected (stx-map (current-type-eval) #'(ty ...))
          #:when (typechecks? #'tys #'tys-expected)
          #:with f-- (replace-stx-loc #'f- #'ff)
          -----------
          [⊢ (f-- a- (... ...)) ⇒ ty-out.norm]])
       (ro:define-synthax f- ([(_ x ...) e])))]])
   
;; for and if statement --------------------------------------------------
(define-typed-syntax if
  [(_ e-test {e1 ...}  {e2 ...}) ≫
   --------
   [⊢ (ro:if (to-bool e-test)
             (ro:let () e1 ... (ro:void))
             (ro:let () e2 ... (ro:void))) ⇒ void]]
  [(_ e-test es) ≫ --- [≻ (if e-test es {})]])

(define-typed-syntax (range e ...) ≫
  [⊢ e ≫ e- ⇐ int] ...
  --- [⊢ (ro:#%app ro:in-range e- ...) ⇒ int]) 
(define-typed-syntax for
  [(_ [((~literal :) ty:type x:id (~datum in) rangeExpr) ...] e ...) ≫
   #:with (x- ...) (generate-temporaries #'(x ...))
  #:with (typed-seq ...) #'((with-ctx ([x x- ty] ...) rangeExpr) ...)
   --------
   [⊢ (ro:let ([x- 1] ...) ; dummy ensuring id- bound, simplifies stx template
        (ro:for* ([x- typed-seq] ...)
          (with-ctx ([x x- ty] ...)
          (⊢m (ro:let () e ... (ro:void)) void)))) ⇒ void]])

(define-typed-syntax #%datum ; redefine bc rosette:#%datum is too precise
 [(_ . b:boolean) ≫ --- [⊢ (ro:#%datum . b) ⇒ bool]]
 [(_ . s:str)     ≫ --- [⊢ (ro:#%datum . s) ⇒ char*]]
 [(_ . n:integer) ≫ --- [⊢ (ro:#%datum . n) ⇒ int]]
 [(_ . n:number) ≫
  #:when (real? (syntax-e #'n))
   --------
   [⊢ (ro:#%datum . n) ⇒ float]]
  [(_ . x) ≫
   --------
   [_ #:error (type-error #:src #'x #:msg "Unsupported literal: ~v" #'x)]])

;; : (var declaration) --------------------------------------------------
(define-typed-syntax :
  [(_ ty:type x:id ...) ≫ ; special String case
   #:when (rosette:CString? #'ty.norm)
   #:with (x- ...) (generate-temporaries #'(x ...))
   --------
   [≻ (begin- (define-syntax- x
                (make-rename-transformer (assign-type #'x- #'ty.norm))) ...
                (ro:define x- (ro:#%datum . "")) ...)]]
  [(_ ty:type x:id ...) ≫
   #:when (real-type? #'ty.norm)
   #:do [(define split-ty (ty->len #'ty))]
   #:when (and split-ty (= 3 (length split-ty)))
   #:do [(define base-str (cadr split-ty)) 
         (define len-str (caddr split-ty))]
   #:with ty-base (datum->syntax #'ty (string->symbol base-str))
   #:with pred (get-pred ((current-type-eval) #'ty-base))
   #:fail-unless (syntax-e #'pred) (format "no pred for ~a" (type->str #'ty))
   #:with (x- ...) (generate-temporaries #'(x ...))
   #:with (x-- ...) (generate-temporaries #'(x ...))
   #:with mk-ty (mk-mk #'ty #'here)
   --------
   [≻ (begin- (ro:define-symbolic* x-- pred [#,(string->number len-str)]) ...
              (ro:define x- (ro:apply mk-ty x--)) ...
              (define-syntax- x
                (make-rename-transformer (assign-type #'x- #'ty.norm))) ...)]]
  [(_ ty:type [len] x:id ...) ≫ ; array of vector types
   #:when (real-type? #'ty.norm)
   [⊢ len ≫ len- ⇐ int]
   #:with ty-base (get-base #'ty.norm)
   #:with base-len (datum->syntax #'ty (real-type-length #'ty.norm))
   #:with ty* (format-id #'ty "~a*" #'ty)
   #:with to-ty* (format-id #'here "to-~a" #'ty*)
   #:with pred (get-pred ((current-type-eval) #'ty-base))
   #:fail-unless (syntax-e #'pred) (format "no pred for ~a" (type->str #'ty))
   #:with (x- ...) (generate-temporaries #'(x ...))
   #:with (*x ...) (generate-temporaries #'(x ...))
   #:with (x-- ...) (generate-temporaries #'(x ...))
   #:with mk-ty (format-id #'here "mk-~a" #'ty)
   --------
   [≻ (begin- (ro:define-symbolic* x-- pred [len base-len]) ...
              (ro:define x-
                (ro:let ([*x (to-ty* (cl:malloc (ro:* len base-len)))])
                  (ro:for ([i len][v x--]) 
                    (cl:pointer-set! *x i (ro:apply mk-ty v)))
                  *x)) ...
              (define-syntax- x
                (make-rename-transformer (assign-type #'x- #'ty*))) ...)]]
  ;; real, scalar (ie non-vector) types
  [(_ ty:type x:id ...) ≫
   #:when (real-type? #'ty.norm)
   #:with pred (get-pred #'ty.norm)
   #:fail-unless (syntax-e #'pred) (format "no pred for ~a" (type->str #'ty))
   #:with (x- ...) (generate-temporaries #'(x ...))
   --------
   [≻ (begin- (define-syntax- x
                (make-rename-transformer (assign-type #'x- #'ty.norm))) ...
              (ro:define-symbolic* x- pred) ...)]]
  ;; else init to NULLs
  [(_ ty:type x:id ...) ≫
   #:with (x- ...) (generate-temporaries #'(x ...))
   --------
   [≻ (begin- (define-syntax- x
                (make-rename-transformer (assign-type #'x- #'ty.norm))) ...
              (ro:define x- cl:NULL) ...)]])

;; ?: --------------------------------------------------
(define-typed-syntax ?:
  [(_ e e1 e2) ≫
   [⊢ e ≫ e- ⇒ ty] ; vector type
   #:do [(define split-ty (ty->len #'ty))]
   #:when (and split-ty (= 3 (length split-ty)))
   [⊢ e1 ≫ e1- ⇒ ty1]
   [⊢ e2 ≫ e2- ⇒ ty2]
   #:with ty-out (common-real-type #'ty #'ty1 #'ty2)
   #:with convert (get-convert #'ty-out)
   #:do [(define split-ty-out (ty->len #'ty-out))
         (define out-base-str (cadr split-ty-out))
         (define out-len-str (caddr split-ty-out))]
   #:with ty-base ((current-type-eval) (datum->syntax #'e (string->symbol out-base-str)))
   #:with base-convert (get-convert #'ty-base)
   -------
   [⊢ (convert (ro:let ([a (convert e-)][b (convert e1-)][c (convert e2-)])
                 (ro:for/list ([idx #,(string->number out-len-str)])
                   (ro:if (ro:< (ro:vector-ref a idx) 0)
                          (base-convert (ro:vector-ref b idx))
                          (base-convert (ro:vector-ref c idx)))))) ⇒ ty-out]]
  [(_ ~! e e1 e2) ≫ ; should be scalar and real
   [⊢ e ≫ e- ⇒ ty]
   #:fail-unless (real-type? #'ty) (format "not a real type: ~s has type ~a"
                                           (syntax->datum #'e) (type->str #'ty))
   #:when (cast-ok? #'ty #'bool #'e)
   [⊢ e1 ≫ e1- ⇒ ty1]
   [⊢ e2 ≫ e2- ⇒ ty2]
   #:with ty-out ((current-join) #'ty1 #'ty2)
   -------
   [⊢ (cl:?: (synth-app (bool) e-)
             (synth-app (ty-out) e1-)
             (synth-app (ty-out) e2-)) ⇒ ty-out]])

;; = (assignment) --------------------------------------------------
(define-typed-syntax =
  [(_ x:id e) ≫
   [⊢ x ≫ x- ⇒ ty-x]
   [⊢ e ≫ e- ⇒ ty-e]
   #:fail-unless (cast-ok? #'ty-e #'ty-x this-syntax)
           (format "cannot cast ~a to ~a" (type->str #'ty-e) (type->str #'ty-x))
   #:with conv (get-convert #'ty-x)
   --------
   [⊢ (ro:set! x- #,(if (syntax-e #'conv) #'(conv e-) #'e-)) ⇒ void]]
  ;; selector can be list of numbers or up to wxyz for vectors of length <=4
  [(_ [x:id sel] e) ≫
   [⊢ x ≫ x- ⇒ ty-x]
   [⊢ e ≫ e- ⇒ ty-e]
   #:with out-e (if (pointer-type? #'ty-x)
                    (with-syntax ([conv (mk-to (get-pointer-base #'ty-x))])
                      #'(ro:begin (cl:pointer-set! x- sel (conv e-)) x-))
                    (with-syntax ([selector (cl:parse-selector #f #'sel this-syntax)])
                      #`(ro:let ([out (ro:vector-copy x-)])
                        #,(if (= 1 (length (stx->list #'selector)))
                            #`(ro:vector-set! out (car 'selector) e-)
                            #'(ro:for ([idx 'selector] [v e-])
                                (ro:vector-set! out idx v)))
                        out))) ; TODO: need mk-ty here?
   --------
   [⊢ (ro:set! x- out-e) ⇒ void]])

(define-typed-syntax !
  [(_ e) ≫
   [⊢ e ≫ e- ⇐ bool]
   --------
   [⊢ (ro:#%app cl:! e-) ⇒ bool]]
  [(_ e) ≫ ; else try to coerce
   [⊢ e ≫ e- ⇒ ty]
   --------
   [⊢ (ro:#%app cl:! (to-bool e-)) ⇒ bool]])

;TODO: cmps should produce vec int result with same length as comm-real-ty
(define-simple-macro (mk-cmp cmp-op) 
  (define-typed-syntax cmp-op
    [(o e1 e2) ≫
     [⊢ e1 ≫ e1- ⇒ ty1]
     [⊢ e2 ≫ e2- ⇒ ty2]
     #:with conv (get-convert ((current-join) #'ty1 #'ty2))
     --------
     [⊢ (to-int (#,(mk-cl #'o) (conv e1-) (conv e2-))) ⇒ int]]))
(define-simple-macro (mk-cmps o ...) (begin- (mk-cmp o) ...))
(mk-cmps == < <= > >= !=)

(define-simple-macro (define-bool-ops o ...+) (ro:begin (define-bool-op o) ...))
(define-simple-macro (define-bool-op name)
  #:with name- (mk-cl #'name)
  (define-typed-syntax name
    [(_ e1 e2) ≫
     [⊢ e1 ≫ e1- ⇐ bool]
     [⊢ e2 ≫ e2- ⇐ bool]
     --------
     [⊢ (name- e1- e2-) ⇒ bool]]
    [(_ e1 e2) ≫ --- [⊢ (name- (to-bool e1) (to-bool e2)) ⇒ bool]])) ; coerce

(define-simple-macro (define-real-ops o ...) (ro:begin (define-real-op o) ...))
(define-simple-macro (define-real-op name (~optional (~seq #:extra-check p?)
                                           #:defaults ([p? #'(λ _ #t)])))
  #:with name- (mk-cl #'name)
  #:with name= (format-id #'name "~a=" #'name) ; assignment form
  (begin-
    (define-typed-syntax (name e (... ...)) ≫
      [⊢ e ≫ e- ⇒ ty] (... ...)
      #:with ty-out (apply common-real-type (stx->list #'(ty (... ...))))
      #:fail-unless (syntax-e #'ty-out)
                    (format "no common real type for operands; given ~a"
                            (types->str #'(ty (... ...))))
      #:when (p? #'ty-out #'(ty (... ...)))
      #:with convert (get-convert #'ty-out)
      #:with ty-base (get-base #'ty-out)
      #:with base-convert (get-convert #'ty-base)
      #:with (x (... ...)) (generate-temporaries #'(e (... ...)))
      --------
      [⊢ #,(if (scalar-type? #'ty-out)
               #'(convert (name- (convert e-) (... ...)))
               #'(convert (ro:let ([x (convert e-)] (... ...))
                           (ro:for/list ([x x] (... ...))
                            (base-convert (name- x (... ...))))))) ⇒ ty-out])
    (define-typed-syntax (name= x e) ≫ --- [≻ (= x (name x e))])))

(define-for-syntax (int? t givens)
  (or (typecheck/un? t #'int)
      (raise-syntax-error #f
        (format "no common integer type for operands; given ~a"
                (types->str givens)))))
(define-simple-macro (define-int-op o) (define-real-op o #:extra-check int?))
(define-simple-macro (define-int-ops o ...) (ro:begin (define-int-op o) ...))

(define-bool-ops || &&)
(define-real-ops + * - / sqrt)
(define-int-ops % << $ &)

(define-typerule (sizeof t:type) ≫ --- [⊢ #,(real-type-length #'t.norm) ⇒ int])
(define-typerule (print e ...)   ≫ --- [⊢ (ro:begin (display e) ...) ⇒ void])
(define-typerule (assert e)      ≫ --- [⊢ (ro:assert (to-bool e)) ⇒ void])
(define-typerule (clCreateProgramWithSource ctx f) ≫
 --- [⊢ (cl:clCreateProgramWithSource ctx f) ⇒ cl_program])

(define-typed-syntax choose
  [(ch e ...+) ≫
   #:with (e- ...) (stx-map expand/ro #'(e ...))
   #:with (ty ...) (stx-map typeof #'(e- ...))
   #:when (same-types? #'(ty ...))
   #:with ch- (replace-stx-loc #'ro:choose #'ch)
   --------
   [⊢ (ch- e- ...) ⇒ #,(stx-car #'(ty ...))]])

(define-typed-syntax ??
  [(qq ty:type) ≫
   #:with qq- (replace-stx-loc #'cl:?? #'qq)
   #:with cl-t (mk-cl (uneval #'ty.norm))
   --------
   [⊢ (qq- cl-t) ⇒ ty.norm]]
  [(qq) ≫ --- [⊢ (#,(replace-stx-loc #'cl:?? #'qq)) ⇒ int]])

(define-typed-syntax (@ x:id) ≫
  [⊢ x ≫ x- ⇒ ty+] ;; TODO: check ty = real, non-ptr type
  #:with ty (uneval #'ty+)
  ---------
  [⊢ (cl:address-of x- #,(mk-cl #'ty)) ⇒ #,(mk-ptr #'ty)])
  
(define-typed-syntax locally-scoped
  [(_ e ...) ⇐ ty ≫ --- [⊢ (ro:let () e ...)]]
  [(_ e ...) ≫ ---  [≻ (⊢m (ro:let () e ...) void)]])

(define-for-syntax (decl->seq stx)
  (syntax-parse stx
    [((~datum :) ty:type id (~datum in) rangeExpr) 
     (syntax/loc stx (id rangeExpr ty.norm))]
    [((~datum :) ty:type [len] id)
     #:with tyout (mk-ptr #'ty)
     (syntax/loc stx (id (ro:in-value (ro:let () (: ty [len] id) id)) tyout))]
    [((~datum :) ty id)
     (syntax/loc stx (id (ro:in-value (ro:let () (: ty id) id)) ty))]))

(define-typed-syntax synth
  [(_ #:forall [decl ...] #:bitwidth bw #:ensure e) ≫
  #:with ([id seq ty] ...) (stx-map decl->seq #'(decl ...))
  #:with (id- ...) (generate-temporaries #'(id ...))
  #:with (typed-seq ...) #'((with-ctx ([id id- ty] ...) seq) ...)
  #:with (tmp ...) (generate-temporaries #'(id ...))
  --------
  [⊢ (ro:let ([id- 1] ...) ; dummy ensuring id- bound, simplifies stx template
      (ro:define-values (tmp ...)
        (ro:for*/lists (tmp ...) ([id- typed-seq] ...) (ro:values id- ...)))
      (ro:parameterize ([ro:current-bitwidth bw] ; matrix mult unsat w/o this
                        [ro:current-oracle (ro:oracle (ro:current-oracle))]
                        [ro:term-cache (ro:hash-copy (ro:term-cache))])
       (ro:print-forms
        (ro:synthesize
         #:forall (ro:append tmp ...)
         #:guarantee (ro:for ([id- tmp] ...)
                             (with-ctx ([id id- ty] ...) e)))))) ⇒ void]]
  [(_ #:forall [decl ...] #:ensure e) ≫
   --- [≻ (synth #:forall [decl ...] #:bitwidth 8 #:ensure e)]])

(define-typed-syntax verify
 [(_ #:forall [decl ...] #:ensure e) ≫
  #:with ([id seq ty] ...) (stx-map decl->seq #'(decl ...))
  #:with (id- ...) (generate-temporaries #'(id ...))
  #:with (typed-seq ...) #'((with-ctx ([id id- ty] ...) seq) ...)
  --------
  [⊢ (ro:let ([id- 1] ...) ; dummy, enables simplifying stx template
      (ro:parameterize ([ro:current-bitwidth 32]
                        [ro:term-cache (ro:hash-copy (ro:term-cache))])
       (ro:or (ro:for*/or ([id- typed-seq] ...)
               (ro:define cex (with-ctx ([id id- ty] ...) (ro:verify e)))
               (ro:and (ro:sat? cex)
                       (displayln "counterexample found:")
                       (ro:for ([i '(id ...)] [i- (ro:list id- ...)])
                               (printf "~a = ~a\n" i (ro:evaluate i- cex)))
                       cex))
              (begin (displayln "no counterexample found") (ro:unsat))))) ⇒ void]])
