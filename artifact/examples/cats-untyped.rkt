#lang rosette
(require ocelot)

(define U (universe '(a b c d)))

; Declare a cats relation and create an interpretation for it
(define cats (declare-relation 1 "cats"))
(define bCats (make-upper-bound cats '((a) (b) (c) (d))))
(define allCatBounds (bounds U (list bCats)))
(define iCats (instantiate-bounds allCatBounds))

; Find an interesting model for the cats relation
(define F (and (some cats) (some (- univ cats))))

(define resultCats (solve (assert (interpret* F iCats))))

(evaluate iCats resultCats)
iCats
(interpretation->relations (evaluate iCats resultCats)) ; => cats: b
(interpretation->relations iCats) ; => cats: a,b,c,d (WRONG)