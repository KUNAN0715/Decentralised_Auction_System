(define-data-var reward-rate uint u100)
(define-data-var total-staked uint u0)
(define-data-var last-update-block uint u0)
(define-data-var reward-per-token-stored uint u0)

(define-map user-stakes principal {
    amount: uint,
    reward-per-token-paid: uint,
    rewards: uint,
    stake-timestamp: uint,
    last-bid-block: uint
})

(define-map staking-pools uint {
    total-staked: uint,
    reward-rate: uint,
    last-update: uint,
    pool-active: bool
})

(define-map bid-rewards principal {
    total-bid-time: uint,
    accumulated-rewards: uint,
    active-bids: uint,
    last-reward-claim: uint
})

(define-data-var pool-count uint u0)
(define-data-var reward-token-supply uint u1000000)

(define-public (create-staking-pool (rate uint))
    (begin
        (map-set staking-pools (var-get pool-count) {
            total-staked: u0,
            reward-rate: rate,
            last-update: stacks-block-height,
            pool-active: true
        })
        (var-set pool-count (+ (var-get pool-count) u1))
        (ok "Staking pool created")
    ))

(define-public (stake-on-bid (amount uint))
    (let ((current-stake (default-to {
        amount: u0,
        reward-per-token-paid: u0,
        rewards: u0,
        stake-timestamp: u0,
        last-bid-block: u0
    } (map-get? user-stakes tx-sender))))
        (begin
            (asserts! (> amount u0) (err "Invalid stake amount"))
            (unwrap! (update-reward tx-sender) (err "Reward update failed"))
            (map-set user-stakes tx-sender {
                amount: (+ (get amount current-stake) amount),
                reward-per-token-paid: (var-get reward-per-token-stored),
                rewards: (get rewards current-stake),
                stake-timestamp: stacks-block-height,
                last-bid-block: stacks-block-height
            })
            (var-set total-staked (+ (var-get total-staked) amount))
            (ok "Staked on bid")
        )))

(define-public (calculate-bid-rewards (bidder principal))
    (let ((bid-info (default-to {
        total-bid-time: u0,
        accumulated-rewards: u0,
        active-bids: u0,
        last-reward-claim: u0
    } (map-get? bid-rewards bidder)))
          (stake-info (default-to {
        amount: u0,
        reward-per-token-paid: u0,
        rewards: u0,
        stake-timestamp: u0,
        last-bid-block: u0
    } (map-get? user-stakes bidder)))
          (time-since-bid (- stacks-block-height (get last-bid-block stake-info)))
          (reward-multiplier (/ (get amount stake-info) u100)))
        (begin
            (asserts! (> (get amount stake-info) u0) (err "No active stake"))
            (map-set bid-rewards bidder {
                total-bid-time: (+ (get total-bid-time bid-info) time-since-bid),
                accumulated-rewards: (+ (get accumulated-rewards bid-info) 
                                      (* time-since-bid reward-multiplier)),
                active-bids: (get active-bids bid-info),
                last-reward-claim: stacks-block-height
            })
            (ok (* time-since-bid reward-multiplier))
        )))

(define-public (claim-yield-rewards)
    (let ((stake-info (unwrap! (map-get? user-stakes tx-sender) (err "No stake found")))
          (reward-info (default-to {
        total-bid-time: u0,
        accumulated-rewards: u0,
        active-bids: u0,
        last-reward-claim: u0
    } (map-get? bid-rewards tx-sender))))
        (begin
            (unwrap! (update-reward tx-sender) (err "Reward update failed"))
            (asserts! (> (get accumulated-rewards reward-info) u0) (err "No rewards available"))
            (map-set bid-rewards tx-sender 
                (merge reward-info {accumulated-rewards: u0, last-reward-claim: stacks-block-height}))
            (ok (get accumulated-rewards reward-info))
        )))

(define-public (compound-stake)
    (let ((rewards-earned (try! (claim-yield-rewards))))
        (begin
            (try! (stake-on-bid rewards-earned))
            (ok "Rewards compounded into stake")
        )))

(define-public (unstake (amount uint))
    (let ((stake-info (unwrap! (map-get? user-stakes tx-sender) (err "No stake found"))))
        (begin
            (asserts! (>= (get amount stake-info) amount) (err "Insufficient stake"))
            (unwrap! (update-reward tx-sender) (err "Reward update failed"))
            (map-set user-stakes tx-sender 
                (merge stake-info {amount: (- (get amount stake-info) amount)}))
            (var-set total-staked (- (var-get total-staked) amount))
            (ok "Unstaked successfully")
        )))

(define-public (update-reward-rate (new-rate uint))
    (begin
        (asserts! (<= new-rate u1000) (err "Rate too high"))
        (var-set reward-rate new-rate)
        (var-set last-update-block stacks-block-height)
        (ok "Reward rate updated")
    ))

(define-public (boost-rewards-for-duration (duration uint) (multiplier uint))
    (let ((boosted-rate (* (var-get reward-rate) multiplier)))
        (begin
            (asserts! (<= multiplier u5) (err "Multiplier too high"))
            (asserts! (> duration u0) (err "Invalid duration"))
            (var-set reward-rate boosted-rate)
            (ok "Rewards boosted temporarily")
        )))

(define-read-only (get-reward-per-token)
    (if (is-eq (var-get total-staked) u0)
        (var-get reward-per-token-stored)
        (+ (var-get reward-per-token-stored)
           (/ (* (- stacks-block-height (var-get last-update-block)) (var-get reward-rate))
              (var-get total-staked)))))

(define-read-only (earned (account principal))
    (let ((stake-info (default-to {
        amount: u0,
        reward-per-token-paid: u0,
        rewards: u0,
        stake-timestamp: u0,
        last-bid-block: u0
    } (map-get? user-stakes account))))
        (+ (get rewards stake-info)
           (/ (* (get amount stake-info) 
                 (- (get-reward-per-token) (get reward-per-token-paid stake-info)))
              u1000000))))

(define-private (update-reward (account principal))
    (let ((stake-info (default-to {
        amount: u0,
        reward-per-token-paid: u0,
        rewards: u0,
        stake-timestamp: u0,
        last-bid-block: u0
    } (map-get? user-stakes account))))
        (begin
            (var-set reward-per-token-stored (get-reward-per-token))
            (var-set last-update-block stacks-block-height)
            (map-set user-stakes account
                (merge stake-info {
                    rewards: (earned account),
                    reward-per-token-paid: (get-reward-per-token)
                }))
            (ok true)
        )))

(define-read-only (get-stake-info (account principal))
    (map-get? user-stakes account))

(define-read-only (get-bid-rewards-info (account principal))
    (map-get? bid-rewards account))

(define-read-only (get-total-staked)
    (var-get total-staked))

(define-read-only (get-current-reward-rate)
    (var-get reward-rate))

(define-public (emergency-pause-rewards)
    (begin
        (var-set reward-rate u0)
        (ok "Rewards paused for emergency")
    ))
