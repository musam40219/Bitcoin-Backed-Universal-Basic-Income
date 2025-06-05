
;; title: Bitcoin-Backed-Universal
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;


(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u102))
(define-constant ERR_NOT_ELIGIBLE (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_POOL_EMPTY (err u105))
(define-constant ERR_ALREADY_REGISTERED (err u106))
(define-constant ERR_NOT_REGISTERED (err u107))
(define-constant ERR_VERIFICATION_FAILED (err u108))

(define-data-var total-pool uint u0)
(define-data-var distribution-period uint u144)
(define-data-var current-round uint u1)
(define-data-var min-stake-amount uint u1000000)
(define-data-var base-ubi-amount uint u100000)
(define-data-var total-participants uint u0)

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

(define-map round-claims
  { participant: principal, round: uint }
  { claimed: bool, amount: uint }
)

(define-map verification-requests
  principal
  {
    requested-at: uint,
    verified: bool,
    verifier: (optional principal),
    score: uint
  }
)

(define-map staking-rewards
  principal
  {
    staked-amount: uint,
    reward-multiplier: uint,
    stake-start-block: uint
  }
)

(define-public (register-participant)
  (let 
    (
      (participant tx-sender)
      (existing-participant (map-get? participants participant))
    )
    (if (is-some existing-participant)
      ERR_ALREADY_REGISTERED
      (begin
        (map-set participants participant {
          registered: true,
          stake-amount: u0,
          verification-score: u1,
          last-claim-round: u0,
          total-claimed: u0,
          participation-score: u1
        })
        (var-set total-participants (+ (var-get total-participants) u1))
        (ok true)
      )
    )
  )
)

(define-public (stake-tokens (amount uint))
  (let
    (
      (participant tx-sender)
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
    )
    (if (>= amount (var-get min-stake-amount))
      (begin
        (try! (stx-transfer? amount participant (as-contract tx-sender)))
        (map-set participants participant 
          (merge participant-data { stake-amount: (+ (get stake-amount participant-data) amount) })
        )
        (map-set staking-rewards participant {
          staked-amount: amount,
          reward-multiplier: (calculate-stake-multiplier amount),
          stake-start-block: stacks-block-height
        })
        (var-set total-pool (+ (var-get total-pool) amount))
        (ok true)
      )
      ERR_INVALID_AMOUNT
    )
  )
)

(define-public (request-verification)
  (let
    (
      (participant tx-sender)
    )
    (if (is-some (map-get? participants participant))
      (begin
        (map-set verification-requests participant {
          requested-at: stacks-block-height,
          verified: false,
          verifier: none,
          score: u0
        })
        (ok true)
      )
      ERR_NOT_REGISTERED
    )
  )
)

(define-public (verify-participant (participant principal) (score uint))
  (let
    (
      (verifier tx-sender)
      (request-data (unwrap! (map-get? verification-requests participant) ERR_NOT_REGISTERED))
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
    )
    (if (is-eq verifier CONTRACT_OWNER)
      (begin
        (map-set verification-requests participant 
          (merge request-data { 
            verified: true, 
            verifier: (some verifier),
            score: score
          })
        )
        (map-set participants participant 
          (merge participant-data { verification-score: score })
        )
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (claim-ubi)
  (let
    (
      (participant tx-sender)
      (current-round-val (var-get current-round))
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
      (claim-key { participant: participant, round: current-round-val })
      (existing-claim (map-get? round-claims claim-key))
    )
    (if (and 
          (get registered participant-data)
          (is-none existing-claim)
          (> current-round-val (get last-claim-round participant-data))
        )
      (let
        (
          (ubi-amount (calculate-ubi-amount participant))
          (pool-balance (var-get total-pool))
        )
        (if (>= pool-balance ubi-amount)
          (begin
            (try! (as-contract (stx-transfer? ubi-amount tx-sender participant)))
            (map-set round-claims claim-key { claimed: true, amount: ubi-amount })
            (map-set participants participant 
              (merge participant-data { 
                last-claim-round: current-round-val,
                total-claimed: (+ (get total-claimed participant-data) ubi-amount)
              })
            )
            (var-set total-pool (- pool-balance ubi-amount))
            (ok ubi-amount)
          )
          ERR_POOL_EMPTY
        )
      )
      ERR_ALREADY_CLAIMED
    )
  )
)

(define-public (contribute-to-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-pool (+ (var-get total-pool) amount))
    (ok true)
  )
)

(define-public (update-participation-score (participant principal) (score uint))
  (let
    (
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
    )
    (if (is-eq tx-sender CONTRACT_OWNER)
      (begin
        (map-set participants participant 
          (merge participant-data { participation-score: score })
        )
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (advance-round)
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set current-round (+ (var-get current-round) u1))
      (ok (var-get current-round))
    )
    ERR_NOT_AUTHORIZED
  )
)

(define-public (withdraw-stake)
  (let
    (
      (participant tx-sender)
      (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
      (stake-amount (get stake-amount participant-data))
    )
    (if (> stake-amount u0)
      (begin
        (try! (as-contract (stx-transfer? stake-amount tx-sender participant)))
        (map-set participants participant 
          (merge participant-data { stake-amount: u0 })
        )
        (map-delete staking-rewards participant)
        (ok stake-amount)
      )
      ERR_INSUFFICIENT_BALANCE
    )
  )
)

(define-read-only (get-participant-info (participant principal))
  (map-get? participants participant)
)

(define-read-only (get-pool-balance)
  (var-get total-pool)
)

(define-read-only (get-current-round)
  (var-get current-round)
)

(define-read-only (get-total-participants)
  (var-get total-participants)
)

(define-read-only (calculate-ubi-amount (participant principal))
  (let
    (
      (participant-data (unwrap! (map-get? participants participant) u0))
      (base-amount (var-get base-ubi-amount))
      (verification-multiplier (get verification-score participant-data))
      (participation-multiplier (get participation-score participant-data))
      (stake-data (map-get? staking-rewards participant))
    )
    (if (is-some stake-data)
      (let
        (
          (stake-multiplier (get reward-multiplier (unwrap-panic stake-data)))
        )
        (* base-amount (+ verification-multiplier participation-multiplier stake-multiplier))
      )
      (* base-amount (+ verification-multiplier participation-multiplier))
    )
  )
)

(define-read-only (calculate-stake-multiplier (amount uint))
  (if (>= amount (* (var-get min-stake-amount) u10))
    u3
    (if (>= amount (* (var-get min-stake-amount) u5))
      u2
      u1
    )
  )
)

(define-read-only (get-claim-status (participant principal) (round uint))
  (map-get? round-claims { participant: participant, round: round })
)

(define-read-only (is-eligible-for-claim (participant principal))
  (let
    (
      (participant-data (map-get? participants participant))
      (current-round-val (var-get current-round))
    )
    (if (is-some participant-data)
      (let
        (
          (data (unwrap-panic participant-data))
          (claim-key { participant: participant, round: current-round-val })
        )
        (and 
          (get registered data)
          (is-none (map-get? round-claims claim-key))
          (> current-round-val (get last-claim-round data))
        )
      )
      false
    )
  )
)

(define-read-only (get-verification-status (participant principal))
  (map-get? verification-requests participant)
)
