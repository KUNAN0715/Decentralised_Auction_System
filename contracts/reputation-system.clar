;; Dynamic Reputation & Trust Scoring System for Decentralized Auctions
;; Tracks bidder behavior and creates trust scores for marketplace integrity

;; Data variables for system configuration
(define-data-var reputation-admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var base-trust-score uint u500)
(define-data-var max-trust-score uint u1000)
(define-data-var min-trust-score uint u0)
(define-data-var reputation-decay-rate uint u5)
(define-data-var scoring-active bool true)

;; Core reputation tracking map
(define-map user-reputation principal {
    trust-score: uint,
    total-auctions: uint,
    successful-payments: uint,
    failed-payments: uint,
    bid-reliability: uint,
    last-activity: uint,
    reputation-level: uint,
    bonus-points: uint,
    penalty-points: uint
})

;; Detailed behavior tracking
(define-map auction-behavior principal {
    total-bids: uint,
    winning-bids: uint,
    cancelled-bids: uint,
    on-time-payments: uint,
    late-payments: uint,
    disputed-transactions: uint,
    avg-payment-time: uint,
    consecutive-good-behavior: uint
})

;; Reputation tier definitions
(define-map reputation-tiers uint {
    name: (string-utf8 30),
    min-score: uint,
    max-score: uint,
    bid-limit-multiplier: uint,
    fee-discount: uint,
    early-access: bool,
    special-privileges: bool
})

;; Trust endorsements from other users
(define-map trust-endorsements (tuple (endorser principal) (endorsed principal)) {
    score-given: uint,
    timestamp: uint,
    verified: bool
})

;; Reputation milestones and achievements
(define-map user-achievements principal {
    first-successful-auction: bool,
    ten-successful-auctions: bool,
    hundred-successful-auctions: bool,
    perfect-payment-record: bool,
    trusted-by-community: bool,
    early-adopter: bool,
    high-value-bidder: bool
})

;; System counters and statistics
(define-data-var total-users-tracked uint u0)
(define-data-var tier-count uint u0)
(define-data-var endorsement-weight uint u20)
(define-data-var achievement-bonus uint u50)

;; Helper functions
(define-private (check-and-award-achievements (user principal))
    (let ((reputation (unwrap! (map-get? user-reputation user) (err "User not found"))))
        (begin
            (let ((achievements (default-to {
                    first-successful-auction: false,
                    ten-successful-auctions: false,
                    hundred-successful-auctions: false,
                    perfect-payment-record: false,
                    trusted-by-community: false,
                    early-adopter: false,
                    high-value-bidder: false
                  } (map-get? user-achievements user))))
                (let ((new-achievements (merge achievements {
                    first-successful-auction: (or (get first-successful-auction achievements) 
                                                 (>= (get successful-payments reputation) u1)),
                    ten-successful-auctions: (or (get ten-successful-auctions achievements) 
                                               (>= (get successful-payments reputation) u10)),
                    hundred-successful-auctions: (or (get hundred-successful-auctions achievements) 
                                                   (>= (get successful-payments reputation) u100)),
                    perfect-payment-record: (and (> (get successful-payments reputation) u5)
                                               (is-eq (get failed-payments reputation) u0)),
                    trusted-by-community: (>= (get trust-score reputation) u800)
                })))
                    (begin
                        (map-set user-achievements user new-achievements)
                        (ok true))))
        )))

(define-private (update-reputation-level (user principal))
    (let ((reputation (unwrap! (map-get? user-reputation user) (err "User not found")))
          (score (get trust-score reputation)))
        (begin
            (let ((new-level (if (and (>= score u800) (<= score u1000))
                               u3
                               (if (and (>= score u600) (< score u800))
                                 u2
                                 (if (and (>= score u300) (< score u600))
                                   u1
                                   u0)))))
                (map-set user-reputation user (merge reputation {reputation-level: new-level})))
            (ok true)
        )))

;; Initialize reputation tiers
(define-public (initialize-reputation-system)
    (begin
        (asserts! (is-eq tx-sender (var-get reputation-admin)) (err "Not authorized"))
        
        ;; Create basic reputation tiers
        (try! (create-reputation-tier u"Novice" u0 u299 u1 u0 false false))
        (try! (create-reputation-tier u"Trusted" u300 u599 u2 u5 true false))
        (try! (create-reputation-tier u"Expert" u600 u799 u3 u10 true true))
        (try! (create-reputation-tier u"Elite" u800 u1000 u5 u15 true true))
        
        (ok "Reputation system initialized")
    ))

;; Create new reputation tier
(define-public (create-reputation-tier (name (string-utf8 30)) (min-score uint) (max-score uint) (limit-mult uint) (discount uint) (early-access bool) (privileges bool))
    (begin
        (asserts! (is-eq tx-sender (var-get reputation-admin)) (err "Not authorized"))
        (asserts! (< min-score max-score) (err "Invalid score range"))
        (asserts! (<= discount u50) (err "Discount too high"))
        
        (map-set reputation-tiers (var-get tier-count) {
            name: name,
            min-score: min-score,
            max-score: max-score,
            bid-limit-multiplier: limit-mult,
            fee-discount: discount,
            early-access: early-access,
            special-privileges: privileges
        })
        (var-set tier-count (+ (var-get tier-count) u1))
        (ok "Reputation tier created")
    ))

;; Register new user in reputation system
(define-public (register-user)
    (let ((existing-rep (map-get? user-reputation tx-sender)))
        (begin
            (asserts! (is-none existing-rep) (err "User already registered"))
            (asserts! (var-get scoring-active) (err "System inactive"))
            
            (map-set user-reputation tx-sender {
                trust-score: (var-get base-trust-score),
                total-auctions: u0,
                successful-payments: u0,
                failed-payments: u0,
                bid-reliability: u100,
                last-activity: stacks-block-height,
                reputation-level: u0,
                bonus-points: u0,
                penalty-points: u0
            })
            
            (map-set auction-behavior tx-sender {
                total-bids: u0,
                winning-bids: u0,
                cancelled-bids: u0,
                on-time-payments: u0,
                late-payments: u0,
                disputed-transactions: u0,
                avg-payment-time: u0,
                consecutive-good-behavior: u0
            })
            
            (var-set total-users-tracked (+ (var-get total-users-tracked) u1))
            (ok "User registered in reputation system")
        )))

;; Record successful auction completion
(define-public (record-successful-auction (participant principal) (payment-time uint))
    (let ((reputation (unwrap! (map-get? user-reputation participant) (err "User not registered")))
          (behavior (unwrap! (map-get? auction-behavior participant) (err "Behavior data not found"))))
        (begin
            (asserts! (var-get scoring-active) (err "System inactive"))
            
            ;; Update reputation scores
            (map-set user-reputation participant (merge reputation {
                trust-score: (+ (get trust-score reputation) u25),
                total-auctions: (+ (get total-auctions reputation) u1),
                successful-payments: (+ (get successful-payments reputation) u1),
                last-activity: stacks-block-height,
                bonus-points: (+ (get bonus-points reputation) u10)
            }))
            
            ;; Update behavior tracking
            (map-set auction-behavior participant (merge behavior {
                winning-bids: (+ (get winning-bids behavior) u1),
                on-time-payments: (if (<= payment-time u10) 
                                    (+ (get on-time-payments behavior) u1) 
                                    (get on-time-payments behavior)),
                late-payments: (if (> payment-time u10) 
                                 (+ (get late-payments behavior) u1) 
                                 (get late-payments behavior)),
                consecutive-good-behavior: (+ (get consecutive-good-behavior behavior) u1),
                avg-payment-time: (/ (+ (* (get avg-payment-time behavior) (get winning-bids behavior)) payment-time) 
                                    (+ (get winning-bids behavior) u1))
            }))
            
            ;; Check for achievements and update level
            (try! (check-and-award-achievements participant))
            (try! (update-reputation-level participant))
            
            (ok "Successful auction recorded")
        )))

;; Record failed payment or auction violation
(define-public (record-auction-violation (participant principal) (violation-type uint))
    (let ((reputation (unwrap! (map-get? user-reputation participant) (err "User not registered")))
          (behavior (unwrap! (map-get? auction-behavior participant) (err "Behavior data not found")))
          (penalty-amount (if (is-eq violation-type u1)
                            u30 ;; failed payment
                            (if (is-eq violation-type u2)
                              u15 ;; cancelled bid
                              (if (is-eq violation-type u3)
                                u40 ;; dispute
                                u20))))) ;; default penalty
        (begin
            (asserts! (var-get scoring-active) (err "System inactive"))
            
            ;; Apply penalty to trust score
            (map-set user-reputation participant (merge reputation {
                trust-score: (if (>= (get trust-score reputation) penalty-amount)
                               (- (get trust-score reputation) penalty-amount)
                               (var-get min-trust-score)),
                failed-payments: (if (is-eq violation-type u1) 
                                   (+ (get failed-payments reputation) u1)
                                   (get failed-payments reputation)),
                last-activity: stacks-block-height,
                penalty-points: (+ (get penalty-points reputation) penalty-amount)
            }))
            
            ;; Update behavior tracking
            (map-set auction-behavior participant (merge behavior {
                cancelled-bids: (if (is-eq violation-type u2) 
                                  (+ (get cancelled-bids behavior) u1)
                                  (get cancelled-bids behavior)),
                disputed-transactions: (if (is-eq violation-type u3) 
                                         (+ (get disputed-transactions behavior) u1)
                                         (get disputed-transactions behavior)),
                consecutive-good-behavior: u0
            }))
            
            (try! (update-reputation-level participant))
            
            (ok "Violation recorded and penalty applied")
        )))

;; Allow users to endorse each other's trustworthiness
(define-public (endorse-user (endorsed-user principal) (endorsement-score uint))
    (begin
        (asserts! (not (is-eq tx-sender endorsed-user)) (err "Cannot endorse yourself"))
        (asserts! (<= endorsement-score u10) (err "Score too high"))
        (asserts! (>= endorsement-score u1) (err "Score too low"))
        (asserts! (var-get scoring-active) (err "System inactive"))
        
        ;; Check if endorser has sufficient reputation
        (let ((endorser-rep (unwrap! (map-get? user-reputation tx-sender) (err "Endorser not registered"))))
            (begin
                (asserts! (>= (get trust-score endorser-rep) u400) (err "Insufficient reputation to endorse"))
                
                (map-set trust-endorsements {endorser: tx-sender, endorsed: endorsed-user} {
                    score-given: endorsement-score,
                    timestamp: stacks-block-height,
                    verified: (>= (get trust-score endorser-rep) u600)
                })
                
                ;; Apply endorsement boost to endorsed user
                (let ((endorsed-rep (unwrap! (map-get? user-reputation endorsed-user) (err "Endorsed user not registered")))
                      (boost-amount (/ (* endorsement-score (var-get endorsement-weight)) u10)))
                    (map-set user-reputation endorsed-user (merge endorsed-rep {
                        trust-score: (+ (get trust-score endorsed-rep) boost-amount),
                        bonus-points: (+ (get bonus-points endorsed-rep) boost-amount)
                    })))
                
                (ok "Endorsement recorded")
            ))))

;; Apply natural reputation decay over time
(define-public (apply-reputation-decay (user principal))
    (let ((reputation (unwrap! (map-get? user-reputation user) (err "User not found")))
          (blocks-since-activity (- stacks-block-height (get last-activity reputation)))
          (decay-amount (/ (* blocks-since-activity (var-get reputation-decay-rate)) u1000)))
        (begin
            (asserts! (> blocks-since-activity u1000) (err "Too early for decay"))
            
            (map-set user-reputation user (merge reputation {
                trust-score: (if (>= (get trust-score reputation) decay-amount)
                               (- (get trust-score reputation) decay-amount)
                               (var-get min-trust-score))
            }))
            
            (try! (update-reputation-level user))
            (ok "Decay applied")
        )))

;; Get user's current reputation tier
(define-read-only (get-user-tier (user principal))
    (let ((reputation (map-get? user-reputation user)))
        (match reputation
            some-rep (let ((level (get reputation-level some-rep)))
                        (map-get? reputation-tiers level))
            none)))

;; Check if user qualifies for early auction access
(define-read-only (has-early-access (user principal))
    (let ((tier (get-user-tier user)))
        (match tier
            some-tier (get early-access some-tier)
            false)))

;; Calculate fee discount for user
(define-read-only (get-fee-discount (user principal))
    (let ((tier (get-user-tier user)))
        (match tier
            some-tier (get fee-discount some-tier)
            u0)))

;; Get comprehensive user reputation data
(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation user))

;; Get user behavior statistics
(define-read-only (get-user-behavior (user principal))
    (map-get? auction-behavior user))

;; Get user achievements
(define-read-only (get-user-achievements (user principal))
    (map-get? user-achievements user))

;; Admin function to adjust system parameters
(define-public (update-system-parameters (new-decay-rate uint) (new-endorsement-weight uint) (new-achievement-bonus uint))
    (begin
        (asserts! (is-eq tx-sender (var-get reputation-admin)) (err "Not authorized"))
        (asserts! (<= new-decay-rate u50) (err "Decay rate too high"))
        (asserts! (<= new-endorsement-weight u100) (err "Endorsement weight too high"))
        
        (var-set reputation-decay-rate new-decay-rate)
        (var-set endorsement-weight new-endorsement-weight)
        (var-set achievement-bonus new-achievement-bonus)
        
        (ok "System parameters updated")
    ))

;; Emergency pause/resume reputation scoring
(define-public (toggle-scoring-system)
    (begin
        (asserts! (is-eq tx-sender (var-get reputation-admin)) (err "Not authorized"))
        (var-set scoring-active (not (var-get scoring-active)))
        (ok (if (var-get scoring-active) "System activated" "System paused"))
    ))

;; Get system statistics
(define-read-only (get-system-stats)
    {
        total-users: (var-get total-users-tracked),
        tier-count: (var-get tier-count),
        system-active: (var-get scoring-active),
        base-score: (var-get base-trust-score),
        max-score: (var-get max-trust-score)
    })

