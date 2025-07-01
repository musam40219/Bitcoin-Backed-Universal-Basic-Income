
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
(define-constant ERR_PROPOSAL_NOT_FOUND (err u200))
(define-constant ERR_VOTING_ENDED (err u201))
(define-constant ERR_ALREADY_VOTED (err u202))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u203))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u204))
(define-constant ERR_INVALID_REFERRER (err u300))
(define-constant ERR_SELF_REFERRAL (err u301))
(define-constant ERR_REFERRAL_LIMIT_REACHED (err u302))

(define-data-var referral-bonus-rate uint u10)
(define-data-var max-referrals-per-user uint u50)
(define-data-var impact-multiplier uint u5)

(define-data-var next-proposal-id uint u1)
(define-data-var voting-period uint u1008)
(define-data-var min-proposal-stake uint u5000000)

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




(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    parameter: (string-ascii 50),
    new-value: uint,
    created-at: uint,
    voting-ends-at: uint,
    yes-votes: uint,
    no-votes: uint,
    total-voting-power: uint,
    executed: bool,
    approved: bool
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-public (create-proposal (title (string-ascii 100)) (parameter (string-ascii 50)) (new-value uint))
  (let
    (
      (proposer tx-sender)
      (participant-data (unwrap! (map-get? participants proposer) ERR_NOT_REGISTERED))
      (proposal-id (var-get next-proposal-id))
      (current-block stacks-block-height)
    )
    (if (>= (get stake-amount participant-data) (var-get min-proposal-stake))
      (begin
        (map-set proposals proposal-id {
          proposer: proposer,
          title: title,
          parameter: parameter,
          new-value: new-value,
          created-at: current-block,
          voting-ends-at: (+ current-block (var-get voting-period)),
          yes-votes: u0,
          no-votes: u0,
          total-voting-power: u0,
          executed: false,
          approved: false
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
      )
      ERR_INVALID_AMOUNT
    )
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (voter tx-sender)
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (participant-data (unwrap! (map-get? participants voter) ERR_NOT_REGISTERED))
      (vote-key { proposal-id: proposal-id, voter: voter })
      (existing-vote (map-get? proposal-votes vote-key))
      (voting-power (+ (get stake-amount participant-data) (get verification-score participant-data)))
    )
    (if (and 
          (is-none existing-vote)
          (<= stacks-block-height (get voting-ends-at proposal-data))
          (get registered participant-data)
        )
      (begin
        (map-set proposal-votes vote-key { vote: vote, voting-power: voting-power })
        (map-set proposals proposal-id 
          (merge proposal-data {
            yes-votes: (if vote (+ (get yes-votes proposal-data) voting-power) (get yes-votes proposal-data)),
            no-votes: (if vote (get no-votes proposal-data) (+ (get no-votes proposal-data) voting-power)),
            total-voting-power: (+ (get total-voting-power proposal-data) voting-power)
          })
        )
        (ok true)
      )
      (if (is-some existing-vote) ERR_ALREADY_VOTED ERR_VOTING_ENDED)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (yes-votes (get yes-votes proposal-data))
      (total-votes (get total-voting-power proposal-data))
    )
    (if (and 
          (> stacks-block-height (get voting-ends-at proposal-data))
          (not (get executed proposal-data))
          (> yes-votes (/ total-votes u2))
        )
      (begin
        (map-set proposals proposal-id (merge proposal-data { executed: true, approved: true }))
        (if (is-eq (get parameter proposal-data) "base-ubi-amount")

          (ok (var-set base-ubi-amount (get new-value proposal-data)))
          (if (is-eq (get parameter proposal-data) "min-stake-amount")

            (ok (var-set min-stake-amount (get new-value proposal-data)))
            (ok true)
          )
        )

      )
      ERR_PROPOSAL_NOT_APPROVED
    )
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)





(define-map referrals
  principal
  {
    referrer: (optional principal),
    referral-count: uint,
    total-referral-bonus: uint,
    impact-score: uint,
    referred-at: uint
  }
)

(define-map referrer-stats
  principal
  {
    total-referrals: uint,
    active-referrals: uint,
    total-bonus-earned: uint,
    impact-contribution: uint
  }
)

(define-map social-impact
  principal
  {
    community-contributions: uint,
    verification-assists: uint,
    governance-participation: uint,
    total-impact-score: uint
  }
)

(define-public (register-with-referral (referrer principal))
  (let
    (
      (participant tx-sender)
      (existing-participant (map-get? participants participant))
      (referrer-data (map-get? participants referrer))
      (referrer-stats-data (default-to { total-referrals: u0, active-referrals: u0, total-bonus-earned: u0, impact-contribution: u0 } (map-get? referrer-stats referrer)))
    )
    (if (and 
          (is-none existing-participant)
          (is-some referrer-data)
          (not (is-eq participant referrer))
          (< (get total-referrals referrer-stats-data) (var-get max-referrals-per-user))
        )
      (begin
        (try! (register-participant))
        (map-set referrals participant {
          referrer: (some referrer),
          referral-count: u0,
          total-referral-bonus: u0,
          impact-score: u1,
          referred-at: stacks-block-height
        })
        (map-set referrer-stats referrer 
          (merge referrer-stats-data {
            total-referrals: (+ (get total-referrals referrer-stats-data) u1),
            active-referrals: (+ (get active-referrals referrer-stats-data) u1)
          })
        )
        (try! (distribute-referral-bonus referrer))
        (ok true)
      )
      (if (is-none referrer-data) ERR_INVALID_REFERRER
        (if (is-eq participant referrer) ERR_SELF_REFERRAL
          ERR_REFERRAL_LIMIT_REACHED
        )
      )
    )
  )
)

(define-private (distribute-referral-bonus (referrer principal))
  (let
    (
      (bonus-amount (* (var-get base-ubi-amount) (var-get referral-bonus-rate)))
      (pool-balance (var-get total-pool))
      (referrer-stats-data (unwrap! (map-get? referrer-stats referrer) ERR_NOT_REGISTERED))
    )
    (if (>= pool-balance bonus-amount)
      (begin
        (try! (as-contract (stx-transfer? bonus-amount tx-sender referrer)))
        (map-set referrer-stats referrer 
          (merge referrer-stats-data {
            total-bonus-earned: (+ (get total-bonus-earned referrer-stats-data) bonus-amount)
          })
        )
        (var-set total-pool (- pool-balance bonus-amount))
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (update-social-impact (participant principal) (contribution-type (string-ascii 20)) (points uint))
  (let
    (
      (impact-data (default-to { community-contributions: u0, verification-assists: u0, governance-participation: u0, total-impact-score: u0 } (map-get? social-impact participant)))
      (referral-data (map-get? referrals participant))
    )
    (if (is-eq tx-sender CONTRACT_OWNER)
      (begin
        (map-set social-impact participant 
          (if (is-eq contribution-type "community")
            (merge impact-data { 
              community-contributions: (+ (get community-contributions impact-data) points),
              total-impact-score: (+ (get total-impact-score impact-data) points)
            })
            (if (is-eq contribution-type "verification")
              (merge impact-data { 
                verification-assists: (+ (get verification-assists impact-data) points),
                total-impact-score: (+ (get total-impact-score impact-data) points)
              })
              (merge impact-data { 
                governance-participation: (+ (get governance-participation impact-data) points),
                total-impact-score: (+ (get total-impact-score impact-data) points)
              })
            )
          )
        )
        (if (is-some referral-data)
          (let
            (
              (referral-info (unwrap-panic referral-data))
              (impact-bonus (* points (var-get impact-multiplier)))
            )
            (map-set referrals participant 
              (merge referral-info { impact-score: (+ (get impact-score referral-info) impact-bonus) })
            )
            (ok true)
          )
          (ok true)
        )
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-read-only (get-referral-info (participant principal))
  (map-get? referrals participant)
)

(define-read-only (get-referrer-stats (referrer principal))
  (map-get? referrer-stats referrer)
)

(define-read-only (get-social-impact (participant principal))
  (map-get? social-impact participant)
)

(define-read-only (calculate-enhanced-ubi-amount (participant principal))
  (let
    (
      (base-ubi (calculate-ubi-amount participant))
      (referral-data (map-get? referrals participant))
      (impact-data (map-get? social-impact participant))
    )
    (if (is-some referral-data)
      (let
        (
          (referral-info (unwrap-panic referral-data))
          (impact-info (default-to { community-contributions: u0, verification-assists: u0, governance-participation: u0, total-impact-score: u0 } impact-data))
          (referral-bonus (/ (get impact-score referral-info) u10))
          (social-bonus (/ (get total-impact-score impact-info) u20))
        )
        (+ base-ubi referral-bonus social-bonus)
      )
      base-ubi
    )
  )
)

