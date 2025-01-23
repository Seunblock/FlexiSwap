;; FlexiSwap Math Library
;; Handles fixed-point arithmetic and price calculations

(define-constant ERR-MATH-OVERFLOW (err u2000))
(define-constant ERR-DIV-BY-ZERO (err u2001))
(define-constant ERR-INVALID-INPUT (err u2002))

(define-constant PRECISION u1000000)
(define-constant SQRT-PRECISION u1000)
(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant LOG-MAX-ITER u255)
(define-constant BASE-RATE u1000100)

(define-private (min-uint (a uint) (b uint))
    (if (<= a b) a b)
)

(define-read-only (mul-fixed (a uint) (b uint))
    (begin
        (asserts! (and (<= a MAX-UINT) (<= b MAX-UINT)) ERR-MATH-OVERFLOW)
        (let
            (
                (result (/ (* a b) PRECISION))
            )
            (ok result)
        )
    )
)

(define-read-only (div-fixed (a uint) (b uint))
    (begin
        (asserts! (> b u0) ERR-DIV-BY-ZERO)
        (asserts! (<= a MAX-UINT) ERR-MATH-OVERFLOW)
        (let
            (
                (result (/ (* a PRECISION) b))
            )
            (ok result)
        )
    )
)

(define-read-only (sqrt-fixed (x uint))
    (begin 
        (asserts! (<= x MAX-UINT) ERR-MATH-OVERFLOW)
        (let
            (
                (next (+ (/ x u2) u1))
                (result (/ (+ next (/ x next)) u2))
            )
            (ok result)
        )
    )
)

(define-read-only (tick-to-sqrt-price (tick int))
    (begin
        (let
            (
                (abs-tick (if (< tick 0) (* tick -1) tick))
            )
            (asserts! (<= abs-tick (to-int LOG-MAX-ITER)) ERR-INVALID-INPUT)
            (let
                (
                    (price-value (if (< tick 0)
                        (/ PRECISION (* BASE-RATE (to-uint abs-tick)))
                        (* BASE-RATE (to-uint tick))))
                )
                (ok price-value)
            )
        )
    )
)

(define-read-only (sqrt-price-to-tick (sqrt-price uint))
    (begin
        (asserts! (> sqrt-price u0) ERR-INVALID-INPUT)
        (let
            (
                (tick (/ (- sqrt-price PRECISION) BASE-RATE))
            )
            (ok (to-int tick))
        )
    )
)

(define-read-only (calculate-liquidity (amount-x uint) (amount-y uint) (sqrt-price-current uint) (sqrt-price-low uint) (sqrt-price-high uint))
    (begin
        (asserts! (and (> sqrt-price-low u0) (> sqrt-price-high u0)) ERR-DIV-BY-ZERO)
        (asserts! (< sqrt-price-low sqrt-price-high) ERR-INVALID-INPUT)
        (let
            (
                (price-diff (- sqrt-price-high sqrt-price-low))
                (liquidity-x (unwrap! (div-fixed (* amount-x sqrt-price-high) price-diff) ERR-MATH-OVERFLOW))
                (liquidity-y (unwrap! (div-fixed amount-y price-diff) ERR-MATH-OVERFLOW))
            )
            (ok (if (> sqrt-price-current sqrt-price-low)
                    (if (< sqrt-price-current sqrt-price-high)
                        (min-uint liquidity-x liquidity-y)
                        liquidity-y)
                    liquidity-x))
        )
    )
)

(define-read-only (get-amounts-from-liquidity (liquidity uint) (sqrt-price-current uint) (sqrt-price-low uint) (sqrt-price-high uint))
    (begin
        (asserts! (and (> sqrt-price-low u0) (> sqrt-price-high u0)) ERR-DIV-BY-ZERO)
        (asserts! (< sqrt-price-low sqrt-price-high) ERR-INVALID-INPUT)
        (let
            (
                (price-diff (- sqrt-price-high sqrt-price-low))
                (amount-x (unwrap! (div-fixed (* liquidity price-diff) sqrt-price-high) ERR-MATH-OVERFLOW))
                (amount-y (unwrap! (mul-fixed liquidity price-diff) ERR-MATH-OVERFLOW))
            )
            (ok {
                amount-x: amount-x,
                amount-y: amount-y
            })
        )
    )
)