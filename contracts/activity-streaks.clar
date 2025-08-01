(define-constant ERR_STREAK_ALREADY_RECORDED (err u400))
(define-constant ERR_STREAK_BROKEN (err u401))
(define-constant ERR_NOT_REGISTERED (err u107))

(define-data-var streak-bonus-threshold-1 uint u7)
(define-data-var streak-bonus-threshold-2 uint u30)
(define-data-var streak-bonus-threshold-3 uint u90)
(define-data-var streak-multiplier-1 uint u110)
(define-data-var streak-multiplier-2 uint u125)
(define-data-var streak-multiplier-3 uint u150)
(define-data-var base-ubi-amount uint u100000)

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

(define-map activity-streaks
  principal
  {
    current-streak: uint,
    longest-streak: uint,
    last-activity-day: uint,
    total-activities: uint,
    streak-bonus-earned: uint
  }
)

(define-public (record-activity)
  (let
    (
      (participant tx-sender)
      (current-day (/ stacks-block-height u144))
      (streak-data (default-to 
        { current-streak: u0, longest-streak: u0, last-activity-day: u0, total-activities: u0, streak-bonus-earned: u0 }
        (map-get? activity-streaks participant)
      ))
      (last-day (get last-activity-day streak-data))
      (current-streak-val (get current-streak streak-data))
    )
    (if (get registered (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
      (if (is-eq current-day last-day)
        ERR_STREAK_ALREADY_RECORDED
        (let
          (
            (new-streak (if (is-eq current-day (+ last-day u1))
              (+ current-streak-val u1)
              u1
            ))
            (new-longest (if (> new-streak (get longest-streak streak-data))
              new-streak
              (get longest-streak streak-data)
            ))
          )
          (map-set activity-streaks participant {
            current-streak: new-streak,
            longest-streak: new-longest,
            last-activity-day: current-day,
            total-activities: (+ (get total-activities streak-data) u1),
            streak-bonus-earned: (get streak-bonus-earned streak-data)
          })
          (ok new-streak)
        )
      )
      ERR_NOT_REGISTERED
    )
  )
)

(define-read-only (get-streak-multiplier (participant principal))
  (let
    (
      (streak-data (map-get? activity-streaks participant))
    )
    (if (is-some streak-data)
      (let
        (
          (current-streak (get current-streak (unwrap-panic streak-data)))
        )
        (if (>= current-streak (var-get streak-bonus-threshold-3))
          (var-get streak-multiplier-3)
          (if (>= current-streak (var-get streak-bonus-threshold-2))
            (var-get streak-multiplier-2)
            (if (>= current-streak (var-get streak-bonus-threshold-1))
              (var-get streak-multiplier-1)
              u100
            )
          )
        )
      )
      u100
    )
  )

)

(define-read-only (get-activity-streak (participant principal))
  (map-get? activity-streaks participant)
)

(define-read-only (calculate-streak-enhanced-ubi (participant principal))
  (let
    (
      (base-ubi (var-get base-ubi-amount))
      (streak-multiplier (get-streak-multiplier participant))
    )
    (/ (* base-ubi streak-multiplier) u100)
  )
)