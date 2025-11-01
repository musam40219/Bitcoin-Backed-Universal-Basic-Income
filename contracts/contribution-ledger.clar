(define-constant ERR_INVALID_AMOUNT (err u700))
(define-constant ERR_INSUFFICIENT_BALANCE (err u701))

(define-data-var contribution-pool uint u0)
(define-data-var total-contributions-count uint u0)
(define-data-var bronze-tier-threshold uint u1000000)
(define-data-var silver-tier-threshold uint u5000000)
(define-data-var gold-tier-threshold uint u20000000)
(define-data-var diamond-tier-threshold uint u100000000)

(define-map contributor-profiles
  principal
  {
    total-contributed: uint,
    contribution-count: uint,
    first-contribution-block: uint,
    last-contribution-block: uint,
    current-tier: (string-ascii 10),
    reputation-points: uint
  }
)

(define-map contribution-history
  { contributor: principal, contribution-id: uint }
  {
    amount: uint,
    block-height: uint,
    timestamp: uint
  }
)

(define-map tier-badges
  principal
  (list 10 (string-ascii 10))
)

(define-public (record-contribution (amount uint))
  (let
    (
      (contributor tx-sender)
      (profile-data (default-to {
        total-contributed: u0, contribution-count: u0,
        first-contribution-block: u0, last-contribution-block: u0,
        current-tier: "None", reputation-points: u0
      } (map-get? contributor-profiles contributor)))
      (new-total (+ (get total-contributed profile-data) amount))
      (new-count (+ (get contribution-count profile-data) u1))
      (new-tier (calculate-tier new-total))
      (reputation-boost (/ amount u100000))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount contributor (as-contract tx-sender)))
    (var-set contribution-pool (+ (var-get contribution-pool) amount))
    (map-set contribution-history 
      { contributor: contributor, contribution-id: new-count }
      { amount: amount, block-height: stacks-block-height, timestamp: stacks-block-height }
    )
    (map-set contributor-profiles contributor {
      total-contributed: new-total,
      contribution-count: new-count,
      first-contribution-block: (if (is-eq (get first-contribution-block profile-data) u0)
        stacks-block-height
        (get first-contribution-block profile-data)
      ),
      last-contribution-block: stacks-block-height,
      current-tier: new-tier,
      reputation-points: (+ (get reputation-points profile-data) reputation-boost)
    })
    (var-set total-contributions-count (+ (var-get total-contributions-count) u1))
    (ok new-total)
  )
)

(define-read-only (calculate-tier (total-amount uint))
  (if (>= total-amount (var-get diamond-tier-threshold))
    "Diamond"
    (if (>= total-amount (var-get gold-tier-threshold))
      "Gold"
      (if (>= total-amount (var-get silver-tier-threshold))
        "Silver"
        (if (>= total-amount (var-get bronze-tier-threshold))
          "Bronze"
          "None"
        )
      )
    )
  )
)

(define-read-only (get-contributor-profile (contributor principal))
  (map-get? contributor-profiles contributor)
)

(define-read-only (get-contribution-record (contributor principal) (contribution-id uint))
  (map-get? contribution-history { contributor: contributor, contribution-id: contribution-id })
)

(define-read-only (get-pool-total)
  (var-get contribution-pool)
)

(define-read-only (get-total-contributions-count)
  (var-get total-contributions-count)
)
