;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-POOL (err u1001))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u1002))
(define-constant ERR-INVALID-POSITION (err u1003))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u1004))
(define-constant ERR-INVALID-AMOUNT (err u1005))
(define-constant ERR-POOL-EXISTS (err u1006))
(define-constant ERR-MATH-ERROR (err u1007))

(define-constant MIN-LIQUIDITY u1000000)
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant MAX-FEE u10000) ;; 1% = 100 basis points
(define-constant MIN-FEE u100) ;; 0.01% = 1 basis point

;; Data Variables
(define-data-var next-pool-id uint u1)
(define-data-var next-position-id uint u1)
(define-data-var protocol-fee-on bool false)
(define-data-var emergency-shutdown bool false)

;; Data Maps
(define-map pools
    { pool-id: uint }
    {
        token-x: principal,
        token-y: principal,
        reserve-x: uint,
        reserve-y: uint,
        fee-rate: uint,
        total-shares: uint,
        sqrt-price: uint,
        tick-spacing: uint,
        last-updated: uint
    }
)

(define-map positions
    { position-id: uint }
    {
        owner: principal,
        pool-id: uint,
        lower-tick: int,
        upper-tick: int,
        liquidity: uint,
        tokens-owed-x: uint,
        tokens-owed-y: uint,
        fee-growth-inside-x: uint,
        fee-growth-inside-y: uint
    }
)

(define-map tick-bitmap
    { pool-id: uint, word-pos: int }
    { bitmap: uint }
)

(define-map ticks
    { pool-id: uint, tick: int }
    {
        liquidity-net: int,
        liquidity-gross: uint,
        fee-growth-outside-x: uint,
        fee-growth-outside-y: uint,
        seconds-outside: uint
    }
)

;; Price Oracle Data
(define-map price-oracle
    { pool-id: uint }
    {
        price-cumulative: uint,
        price-average: uint,
        timestamp: uint
    }
)

;; Private Functions

;; Calculate square root price from tick
(define-private (tick-to-sqrt-price (tick int))
    (let
        (
            (abs-tick (if (< tick 0) (* tick -1) tick))
            (base (+ u1000000000 (to-uint (* abs-tick 1000)))) ;; 1.0001 in fixed point
        )
        (if (< tick 0)
            (/ PRECISION (pow base u2))
            (* base base)
        )
    )
)

;; Calculate liquidity from amounts and price range
(define-private (calculate-liquidity (amount-x uint) (amount-y uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
    (let
        (
            (price-diff (- sqrt-price-upper sqrt-price-lower))
            (liquidity-x (/ (* amount-x sqrt-price-upper) price-diff))
            (liquidity-y (/ amount-y price-diff))
        )
        (if (<= liquidity-x liquidity-y)
            liquidity-x
            liquidity-y)
    )
)

;; Calculate dynamic fee based on volatility
(define-private (calculate-dynamic-fee (pool-id uint))
    (match (map-get? pools { pool-id: pool-id })
        pool (match (map-get? price-oracle { pool-id: pool-id })
            oracle (let
                (
                    (time-elapsed (- block-height (get timestamp oracle)))
                    (raw-diff (- (get price-average oracle) (get sqrt-price pool)))
                    ;; Handle absolute value calculation with uint
                    (price-diff (if (< raw-diff (get sqrt-price pool)) 
                                (- (get sqrt-price pool) (get price-average oracle))
                                raw-diff))
                    (volatility (/ (* price-diff PRECISION) (* (get price-average oracle) time-elapsed)))
                    (base-fee (+ (get fee-rate pool) (* volatility u10)))
                )
                (ok (if (< base-fee MIN-FEE)
                    MIN-FEE
                    (if (> base-fee MAX-FEE)
                        MAX-FEE
                        base-fee))))
            ERR-INVALID-POOL)
        ERR-INVALID-POOL))

;; Update oracle prices
(define-private (update-oracle (pool-id uint))
    (match (map-get? pools { pool-id: pool-id })
        pool (let
            (
                (current-price (get sqrt-price pool))
                (oracle (default-to 
                    { 
                        price-cumulative: u0,
                        price-average: current-price,
                        timestamp: block-height
                    }
                    (map-get? price-oracle { pool-id: pool-id })
                ))
                (time-elapsed (- block-height (get timestamp oracle)))
            )
            (begin
                (map-set price-oracle
                    { pool-id: pool-id }
                    {
                        price-cumulative: (+ (get price-cumulative oracle) (* current-price time-elapsed)),
                        price-average: (/ (+ (* (get price-average oracle) u95) (* current-price u5)) u100),
                        timestamp: block-height
                    }
                )
                (ok true)
            ))
        ERR-INVALID-POOL))

;; Public Functions

;; Create new liquidity pool
(define-public (create-pool (token-x principal) (token-y principal) (initial-sqrt-price uint) (tick-spacing uint))
    (let
        (
            (pool-id (var-get next-pool-id))
            (existing-pool (map-get? pools { pool-id: pool-id }))
        )
        (asserts! (is-none existing-pool) ERR-POOL-EXISTS)
        (asserts! (>= initial-sqrt-price PRECISION) ERR-INVALID-AMOUNT)
        (asserts! (> tick-spacing u0) ERR-INVALID-AMOUNT)
        
        (map-set pools
            { pool-id: pool-id }
            {
                token-x: token-x,
                token-y: token-y,
                reserve-x: u0,
                reserve-y: u0,
                fee-rate: MIN-FEE,
                total-shares: u0,
                sqrt-price: initial-sqrt-price,
                tick-spacing: tick-spacing,
                last-updated: block-height
            }
        )
        
        (var-set next-pool-id (+ pool-id u1))
        (ok pool-id)
    )
)

;; Create new position
(define-public (create-position 
    (pool-id uint)
    (amount-x uint)
    (amount-y uint)
    (lower-tick int)
    (upper-tick int)
)
    (let
        (
            (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-INVALID-POOL))
            (position-id (var-get next-position-id))
            (sqrt-price-lower (tick-to-sqrt-price lower-tick))
            (sqrt-price-upper (tick-to-sqrt-price upper-tick))
            (liquidity (calculate-liquidity amount-x amount-y sqrt-price-lower sqrt-price-upper))
        )
        ;; Checks
        (asserts! (not (var-get emergency-shutdown)) ERR-NOT-AUTHORIZED)
        (asserts! (>= liquidity MIN-LIQUIDITY) ERR-INSUFFICIENT-LIQUIDITY)
        (asserts! (< lower-tick upper-tick) ERR-INVALID-POSITION)
        
        ;; Create position
        (map-set positions
            { position-id: position-id }
            {
                owner: tx-sender,
                pool-id: pool-id,
                lower-tick: lower-tick,
                upper-tick: upper-tick,
                liquidity: liquidity,
                tokens-owed-x: u0,
                tokens-owed-y: u0,
                fee-growth-inside-x: u0,
                fee-growth-inside-y: u0
            }
        )
        
        ;; Update pool state
        (map-set pools
            { pool-id: pool-id }
            (merge pool
                {
                    reserve-x: (+ (get reserve-x pool) amount-x),
                    reserve-y: (+ (get reserve-y pool) amount-y),
                    total-shares: (+ (get total-shares pool) liquidity)
                }
            )
        )
        
        (var-set next-position-id (+ position-id u1))
        (ok position-id)
    )
)

;; Swap tokens
(define-public (swap (pool-id uint) (token-in principal) (amount-in uint) (min-amount-out uint))
    (let
        (
            (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-INVALID-POOL))
            (fee-rate-response (calculate-dynamic-fee pool-id))
            (fee-rate (unwrap! fee-rate-response ERR-INVALID-POOL))
            (amount-in-after-fee (- amount-in (/ (* amount-in fee-rate) PRECISION)))
            (reserve-in (if (is-eq token-in (get token-x pool)) 
                          (get reserve-x pool) 
                          (get reserve-y pool)))
            (reserve-out (if (is-eq token-in (get token-x pool))
                           (get reserve-y pool)
                           (get reserve-x pool)))
            (amount-out (/ (* amount-in-after-fee reserve-out) (+ reserve-in amount-in-after-fee)))
            (token-out (if (is-eq token-in (get token-x pool))
                         (get token-y pool)
                         (get token-x pool)))
        )
        ;; Checks
        (asserts! (not (var-get emergency-shutdown)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq token-in (get token-x pool)) (is-eq token-in (get token-y pool))) ERR-INVALID-POOL)
        (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-TOO-HIGH)
        
        ;; Update pool state
        (map-set pools
            { pool-id: pool-id }
            (merge pool
                {
                    reserve-x: (if (is-eq token-in (get token-x pool))
                                (+ (get reserve-x pool) amount-in)
                                (- (get reserve-x pool) amount-out)),
                    reserve-y: (if (is-eq token-in (get token-y pool))
                                (+ (get reserve-y pool) amount-in)
                                (- (get reserve-y pool) amount-out)),
                    fee-rate: fee-rate,
                    last-updated: block-height
                }
            )
        )
        
        (try! (update-oracle pool-id))
        (ok amount-out)
    )
)

;; Collect fees from position
(define-public (collect-fees (position-id uint))
    (let
        (
            (position (unwrap! (map-get? positions { position-id: position-id }) ERR-INVALID-POSITION))
            (pool (unwrap! (map-get? pools { pool-id: (get pool-id position) }) ERR-INVALID-POOL))
        )
        (asserts! (is-eq tx-sender (get owner position)) ERR-NOT-AUTHORIZED)
        
        ;; Reset owed amounts
        (map-set positions
            { position-id: position-id }
            (merge position
                {
                    tokens-owed-x: u0,
                    tokens-owed-y: u0
                }
            )
        )
        
        (ok true)
    )
)

;; Emergency Functions

;; Toggle emergency shutdown
(define-public (toggle-emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set emergency-shutdown (not (var-get emergency-shutdown)))
        (ok true)
    )
)

;; Toggle protocol fee
(define-public (toggle-protocol-fee)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set protocol-fee-on (not (var-get protocol-fee-on)))
        (ok true)
    )
)

;; Read-Only Functions

;; Get pool info
(define-read-only (get-pool-info (pool-id uint))
    (map-get? pools { pool-id: pool-id })
)

;; Get position info
(define-read-only (get-position-info (position-id uint))
    (map-get? positions { position-id: position-id })
)

;; Get current price from oracle
(define-read-only (get-oracle-price (pool-id uint))
    (match (map-get? price-oracle { pool-id: pool-id })
        oracle (ok (get price-average oracle))
        ERR-INVALID-POOL
    )
)