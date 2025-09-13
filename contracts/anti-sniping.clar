;; Anti-Sniping Protection System for Decentralized Auctions
;; Prevents last-minute bid sniping through automatic extensions and protective mechanisms

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_AUCTION_NOT_FOUND (err u404))
(define-constant ERR_INVALID_EXTENSION (err u400))
(define-constant ERR_PROTECTION_INACTIVE (err u402))
(define-constant ERR_COOLDOWN_ACTIVE (err u403))

;; Data variables for system configuration
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var protection-enabled bool true)
(define-data-var default-extension-blocks uint u10)
(define-data-var max-extensions uint u5)
(define-data-var snipe-window-blocks uint u20)
(define-data-var cooldown-blocks uint u5)

;; Core protection tracking
(define-map auction-protection uint {
    enabled: bool,
    extension-blocks: uint,
    max-extensions: uint,
    extensions-used: uint,
    last-extension-block: uint,
    snipe-threshold: uint,
    original-end-block: uint,
    protection-level: uint
})

;; Bid timing analysis
(define-map bid-timing uint {
    total-bids: uint,
    snipe-bids: uint,
    last-bid-block: uint,
    rapid-fire-count: uint,
    suspicious-patterns: uint,
    avg-bid-interval: uint
})

;; Bidder behavior tracking
(define-map bidder-patterns principal {
    snipe-attempts: uint,
    successful-snipes: uint,
    rapid-bid-count: uint,
    suspicious-score: uint,
    last-snipe-attempt: uint,
    warning-level: uint
})

;; Extension events log
(define-map extension-log uint {
    auction-id: uint,
    extension-number: uint,
    trigger-bid-amount: uint,
    trigger-bidder: principal,
    blocks-added: uint,
    timestamp: uint
})

(define-data-var extension-count uint u0)

;; Initialize protection for new auction
(define-public (enable-auction-protection (auction-id uint))
    (begin
        (asserts! (var-get protection-enabled) ERR_PROTECTION_INACTIVE)
        
        (map-set auction-protection auction-id {
            enabled: true,
            extension-blocks: (var-get default-extension-blocks),
            max-extensions: (var-get max-extensions),
            extensions-used: u0,
            last-extension-block: u0,
            snipe-threshold: (var-get snipe-window-blocks),
            original-end-block: u0,
            protection-level: u1
        })
        
        (map-set bid-timing auction-id {
            total-bids: u0,
            snipe-bids: u0,
            last-bid-block: u0,
            rapid-fire-count: u0,
            suspicious-patterns: u0,
            avg-bid-interval: u0
        })
        
        (ok "Protection enabled for auction")
    ))

;; Detect and prevent sniping attempts
(define-public (check-snipe-protection (auction-id uint) (auction-end-block uint) (bid-amount uint))
    (let ((protection (unwrap! (map-get? auction-protection auction-id) ERR_AUCTION_NOT_FOUND))
          (timing (unwrap! (map-get? bid-timing auction-id) ERR_AUCTION_NOT_FOUND))
          (blocks-until-end (- auction-end-block stacks-block-height))
          (bidder-history (default-to {
              snipe-attempts: u0,
              successful-snipes: u0,
              rapid-bid-count: u0,
              suspicious-score: u0,
              last-snipe-attempt: u0,
              warning-level: u0
          } (map-get? bidder-patterns tx-sender))))
        
        (begin
            ;; Check if this is a snipe attempt
            (let ((is-snipe (and 
                    (get enabled protection)
                    (<= blocks-until-end (get snipe-threshold protection))
                    (> blocks-until-end u0))))
                
                ;; Update bid timing analysis
                (map-set bid-timing auction-id (merge timing {
                    total-bids: (+ (get total-bids timing) u1),
                    snipe-bids: (if is-snipe 
                        (+ (get snipe-bids timing) u1)
                        (get snipe-bids timing)),
                    last-bid-block: stacks-block-height,
                    rapid-fire-count: (if (< (- stacks-block-height (get last-bid-block timing)) u3)
                        (+ (get rapid-fire-count timing) u1)
                        (get rapid-fire-count timing))
                }))
                
                ;; Update bidder behavior
                (map-set bidder-patterns tx-sender (merge bidder-history {
                    snipe-attempts: (if is-snipe 
                        (+ (get snipe-attempts bidder-history) u1)
                        (get snipe-attempts bidder-history)),
                    last-snipe-attempt: (if is-snipe 
                        stacks-block-height
                        (get last-snipe-attempt bidder-history)),
                    rapid-bid-count: (if (< (- stacks-block-height (get last-snipe-attempt bidder-history)) u5)
                        (+ (get rapid-bid-count bidder-history) u1)
                        (get rapid-bid-count bidder-history))
                }))
                
                ;; Trigger extension if needed
                (if (and is-snipe 
                        (< (get extensions-used protection) (get max-extensions protection))
                        (> (- stacks-block-height (get last-extension-block protection)) (var-get cooldown-blocks)))
                    (begin
                        (try! (extend-auction-automatically auction-id bid-amount))
                        (ok is-snipe))
                    (ok is-snipe))
            )
        )))

;; Automatically extend auction to prevent sniping
(define-public (extend-auction-automatically (auction-id uint) (trigger-bid uint))
    (let ((protection (unwrap! (map-get? auction-protection auction-id) ERR_AUCTION_NOT_FOUND)))
        (begin
            (asserts! (get enabled protection) ERR_PROTECTION_INACTIVE)
            (asserts! (< (get extensions-used protection) (get max-extensions protection)) ERR_INVALID_EXTENSION)
            (asserts! (> (- stacks-block-height (get last-extension-block protection)) (var-get cooldown-blocks)) ERR_COOLDOWN_ACTIVE)
            
            ;; Update protection status
            (map-set auction-protection auction-id (merge protection {
                extensions-used: (+ (get extensions-used protection) u1),
                last-extension-block: stacks-block-height
            }))
            
            ;; Log extension event
            (map-set extension-log (var-get extension-count) {
                auction-id: auction-id,
                extension-number: (+ (get extensions-used protection) u1),
                trigger-bid-amount: trigger-bid,
                trigger-bidder: tx-sender,
                blocks-added: (get extension-blocks protection),
                timestamp: stacks-block-height
            })
            (var-set extension-count (+ (var-get extension-count) u1))
            
            ;; Mark successful snipe prevention
            (let ((bidder-history (default-to {
                snipe-attempts: u0,
                successful-snipes: u0,
                rapid-bid-count: u0,
                suspicious-score: u0,
                last-snipe-attempt: u0,
                warning-level: u0
            } (map-get? bidder-patterns tx-sender))))
                (map-set bidder-patterns tx-sender (merge bidder-history {
                    successful-snipes: (+ (get successful-snipes bidder-history) u1)
                })))
            
            (ok (get extension-blocks protection))
        )))

;; Configure protection settings for specific auction
(define-public (configure-auction-protection (auction-id uint) (extension-blocks uint) (max-extensions-allowed uint) (snipe-threshold uint))
    (let ((protection (unwrap! (map-get? auction-protection auction-id) ERR_AUCTION_NOT_FOUND)))
        (begin
            (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
            (asserts! (<= max-extensions-allowed u10) ERR_INVALID_EXTENSION)
            (asserts! (>= snipe-threshold u5) ERR_INVALID_EXTENSION)
            (asserts! (<= extension-blocks u50) ERR_INVALID_EXTENSION)
            
            (map-set auction-protection auction-id (merge protection {
                extension-blocks: extension-blocks,
                max-extensions: max-extensions-allowed,
                snipe-threshold: snipe-threshold,
                protection-level: (if (and (>= extension-blocks u15) (>= max-extensions-allowed u3)) u2 u1)
            }))
            
            (ok "Auction protection configured")
        )))

;; Analyze bidding patterns for suspicious activity
(define-public (analyze-bidding-patterns (auction-id uint))
    (let ((timing (unwrap! (map-get? bid-timing auction-id) ERR_AUCTION_NOT_FOUND))
          (snipe-ratio (if (> (get total-bids timing) u0)
              (/ (* (get snipe-bids timing) u100) (get total-bids timing))
              u0))
          (rapid-fire-ratio (if (> (get total-bids timing) u0)
              (/ (* (get rapid-fire-count timing) u100) (get total-bids timing))
              u0)))
        (begin
            ;; Update suspicious patterns count based on ratios
            (map-set bid-timing auction-id (merge timing {
                suspicious-patterns: (+ 
                    (if (> snipe-ratio u30) u1 u0)
                    (if (> rapid-fire-ratio u20) u1 u0)
                    (get suspicious-patterns timing))
            }))
            
            (ok {
                snipe-ratio: snipe-ratio,
                rapid-fire-ratio: rapid-fire-ratio,
                total-patterns: (get suspicious-patterns timing)
            })
        )))

;; Update system-wide protection settings
(define-public (update-protection-settings (new-extension-blocks uint) (new-max-extensions uint) (new-snipe-window uint) (new-cooldown uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-extension-blocks u50) ERR_INVALID_EXTENSION)
        (asserts! (<= new-max-extensions u10) ERR_INVALID_EXTENSION)
        (asserts! (>= new-snipe-window u5) ERR_INVALID_EXTENSION)
        (asserts! (>= new-cooldown u1) ERR_INVALID_EXTENSION)
        
        (var-set default-extension-blocks new-extension-blocks)
        (var-set max-extensions new-max-extensions)
        (var-set snipe-window-blocks new-snipe-window)
        (var-set cooldown-blocks new-cooldown)
        
        (ok "Protection settings updated")
    ))

;; Get auction protection status
(define-read-only (get-protection-status (auction-id uint))
    (map-get? auction-protection auction-id))

;; Get bidding pattern analysis
(define-read-only (get-bid-analysis (auction-id uint))
    (map-get? bid-timing auction-id))

;; Get bidder behavior history
(define-read-only (get-bidder-history (bidder principal))
    (map-get? bidder-patterns bidder))

;; Check if auction has extension protection
(define-read-only (has-extension-protection (auction-id uint))
    (let ((protection (map-get? auction-protection auction-id)))
        (match protection
            some-protection (get enabled some-protection)
            false)))

;; Calculate remaining extensions
(define-read-only (get-remaining-extensions (auction-id uint))
    (let ((protection (map-get? auction-protection auction-id)))
        (match protection
            some-protection (- (get max-extensions some-protection) (get extensions-used some-protection))
            u0)))

;; Emergency toggle protection system
(define-public (toggle-protection-system)
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
        (var-set protection-enabled (not (var-get protection-enabled)))
        (ok (if (var-get protection-enabled) 
            "Anti-sniping protection activated"
            "Anti-sniping protection deactivated"))
    ))

;; Get extension history for auction
(define-read-only (get-extension-history (extension-id uint))
    (map-get? extension-log extension-id))

;; Calculate snipe risk level
