(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_REGISTERED (err u107))
(define-constant ERR_INSUFFICIENT_POOL (err u600))
(define-constant ERR_COOLDOWN_ACTIVE (err u601))
(define-constant ERR_AMOUNT_EXCEEDS_TIER (err u602))
(define-constant ERR_PENDING_APPROVAL (err u603))
(define-constant ERR_NOT_AUTHORIZED (err u604))

(define-data-var emergency-pool uint u0)
(define-data-var cooldown-period uint u12960)
(define-data-var auto-approval-limit uint u500000)
(define-data-var tier-1-limit uint u200000)
(define-data-var tier-2-limit uint u500000)
(define-data-var tier-3-limit uint u1000000)

(define-map participants 
  principal 
  {
    registered: bool,
    verification-score: uint
  }
)

(define-map emergency-requests
  principal
  {
    last-request-block: uint,
    total-emergency-received: uint,
    requests-count: uint,
    pending-amount: uint,
    pending-approval: bool
  }
)

(define-public (fund-emergency-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set emergency-pool (+ (var-get emergency-pool) amount))
    (ok true)
  )
)

(define-public (request-emergency-relief (amount uint))
  (let
    (
      (participant tx-sender)
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
      (request-data (default-to {
        last-request-block: u0, total-emergency-received: u0,
        requests-count: u0, pending-amount: u0, pending-approval: false
      } (map-get? emergency-requests participant)))
      (verification-score (get verification-score participant-data))
      (max-allowed (get-tier-limit verification-score))
      (pool-balance (var-get emergency-pool))
    )
    (asserts! (>= (- stacks-block-height (get last-request-block request-data)) (var-get cooldown-period)) ERR_COOLDOWN_ACTIVE)
    (asserts! (<= amount max-allowed) ERR_AMOUNT_EXCEEDS_TIER)
    (asserts! (>= pool-balance amount) ERR_INSUFFICIENT_POOL)
    (if (<= amount (var-get auto-approval-limit))
      (begin
        (try! (as-contract (stx-transfer? amount tx-sender participant)))
        (var-set emergency-pool (- pool-balance amount))
        (map-set emergency-requests participant (merge request-data {
          last-request-block: stacks-block-height,
          total-emergency-received: (+ (get total-emergency-received request-data) amount),
          requests-count: (+ (get requests-count request-data) u1)
        }))
        (ok amount)
      )
      (begin
        (map-set emergency-requests participant (merge request-data {
          pending-amount: amount, pending-approval: true
        }))
        (ok u0)
      )
    )
  )
)

(define-public (approve-emergency-request (participant principal))
  (let
    (
      (request-data (unwrap! (map-get? emergency-requests participant) ERR_NOT_REGISTERED))
      (pending-amount (get pending-amount request-data))
      (pool-balance (var-get emergency-pool))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (get pending-approval request-data) ERR_PENDING_APPROVAL)
    (asserts! (>= pool-balance pending-amount) ERR_INSUFFICIENT_POOL)
    (try! (as-contract (stx-transfer? pending-amount tx-sender participant)))
    (var-set emergency-pool (- pool-balance pending-amount))
    (map-set emergency-requests participant (merge request-data {
      last-request-block: stacks-block-height,
      total-emergency-received: (+ (get total-emergency-received request-data) pending-amount),
      requests-count: (+ (get requests-count request-data) u1),
      pending-amount: u0, pending-approval: false
    }))
    (ok pending-amount)
  )
)

(define-read-only (get-tier-limit (verification-score uint))
  (if (>= verification-score u8)
    (var-get tier-3-limit)
    (if (>= verification-score u5)
      (var-get tier-2-limit)
      (var-get tier-1-limit)
    )
  )
)

(define-read-only (get-emergency-status (participant principal))
  (map-get? emergency-requests participant)
)

(define-read-only (get-emergency-pool-balance)
  (var-get emergency-pool)
)

(define-read-only (can-request-emergency (participant principal))
  (let
    (
      (request-data (map-get? emergency-requests participant))
    )
    (if (is-some request-data)
      (>= (- stacks-block-height (get last-request-block (unwrap-panic request-data))) (var-get cooldown-period))
      true
    )
  )
)