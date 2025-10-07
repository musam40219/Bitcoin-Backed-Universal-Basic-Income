(define-constant ERR_NOT_REGISTERED (err u107))
(define-constant ERR_MILESTONE_ALREADY_CLAIMED (err u500))
(define-constant ERR_MILESTONE_NOT_REACHED (err u501))
(define-constant ERR_INSUFFICIENT_POOL (err u502))

(define-data-var milestone-pool uint u0)
(define-data-var claims-milestone-1 uint u10)
(define-data-var claims-milestone-2 uint u50)
(define-data-var claims-milestone-3 uint u200)
(define-data-var referrals-milestone-1 uint u5)
(define-data-var referrals-milestone-2 uint u25)
(define-data-var referrals-milestone-3 uint u100)
(define-data-var governance-milestone-1 uint u3)
(define-data-var governance-milestone-2 uint u15)
(define-data-var governance-milestone-3 uint u50)

(define-map participants 
  principal 
  {
    registered: bool,
    stake-amount: uint,
    verification-score: uint,
    last-claim-round: uint,
    total-claimed: uint,
    participation-score: uint
  }
)

(define-map milestone-achievements
  principal
  {
    claims-count: uint,
    referrals-count: uint,
    governance-votes: uint,
    claims-milestones-claimed: (list 3 uint),
    referrals-milestones-claimed: (list 3 uint),
    governance-milestones-claimed: (list 3 uint),
    total-milestone-rewards: uint
  }
)

(define-public (fund-milestone-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set milestone-pool (+ (var-get milestone-pool) amount))
    (ok true)
  )
)

(define-public (record-claim-milestone)
  (let
    (
      (participant tx-sender)
      (achievement-data (default-to {
        claims-count: u0, referrals-count: u0, governance-votes: u0,
        claims-milestones-claimed: (list), referrals-milestones-claimed: (list),
        governance-milestones-claimed: (list), total-milestone-rewards: u0
      } (map-get? milestone-achievements participant)))
      (new-claims-count (+ (get claims-count achievement-data) u1))
    )
    (if (is-some (map-get? participants participant))
      (begin
        (map-set milestone-achievements participant 
          (merge achievement-data { claims-count: new-claims-count })
        )
        (unwrap! (check-and-award-claims-milestone participant new-claims-count) ERR_MILESTONE_NOT_REACHED)
        (ok new-claims-count)
      )
      ERR_NOT_REGISTERED
    )
  )
)

(define-private (check-and-award-claims-milestone (participant principal) (claims-count uint))
  (let
    (
      (achievement-data (unwrap! (map-get? milestone-achievements participant) ERR_NOT_REGISTERED))
      (claimed-milestones (get claims-milestones-claimed achievement-data))
    )
    (if (and (>= claims-count (var-get claims-milestone-1)) (is-none (index-of claimed-milestones u1)))
      (award-milestone participant u1 u50000 "claims")
      (if (and (>= claims-count (var-get claims-milestone-2)) (is-none (index-of claimed-milestones u2)))
        (award-milestone participant u2 u250000 "claims")
        (if (and (>= claims-count (var-get claims-milestone-3)) (is-none (index-of claimed-milestones u3)))
          (award-milestone participant u3 u1000000 "claims")
          (ok u0)
        )
      )
    )
  )
)

(define-private (award-milestone (participant principal) (milestone-tier uint) (reward-amount uint) (category (string-ascii 10)))
  (let
    (
      (pool-balance (var-get milestone-pool))
      (achievement-data (unwrap! (map-get? milestone-achievements participant) ERR_NOT_REGISTERED))
    )
    (if (>= pool-balance reward-amount)
      (begin
        (try! (as-contract (stx-transfer? reward-amount tx-sender participant)))
        (var-set milestone-pool (- pool-balance reward-amount))
        (map-set milestone-achievements participant 
          (merge achievement-data {
            claims-milestones-claimed: (if (is-eq category "claims")
              (unwrap! (as-max-len? (append (get claims-milestones-claimed achievement-data) milestone-tier) u3) ERR_MILESTONE_ALREADY_CLAIMED)
              (get claims-milestones-claimed achievement-data)
            ),
            total-milestone-rewards: (+ (get total-milestone-rewards achievement-data) reward-amount)
          })
        )
        (ok reward-amount)
      )
      ERR_INSUFFICIENT_POOL
    )
  )
)

(define-read-only (get-milestone-progress (participant principal))
  (map-get? milestone-achievements participant)
)

(define-read-only (get-milestone-pool-balance)
  (var-get milestone-pool)
)

(define-read-only (get-next-milestone-reward (participant principal))
  (let
    (
      (achievement-data (map-get? milestone-achievements participant))
    )
    (if (is-some achievement-data)
      (let
        (
          (data (unwrap-panic achievement-data))
          (claims-count (get claims-count data))
          (claimed-milestones (get claims-milestones-claimed data))
        )
        (if (and (>= claims-count (var-get claims-milestone-1)) (is-none (index-of claimed-milestones u1)))
          (some u50000)
          (if (and (>= claims-count (var-get claims-milestone-2)) (is-none (index-of claimed-milestones u2)))
            (some u250000)
            (if (and (>= claims-count (var-get claims-milestone-3)) (is-none (index-of claimed-milestones u3)))
              (some u1000000)
              none
            )
          )
        )
      )
      none
    )
  )
)
