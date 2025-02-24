(define-data-var highest-bid uint u0)
(define-data-var highest-bidder principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var auction-end uint u0)
(define-data-var auction-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-public (start-auction (duration uint))
  (begin
    ;; Ensure the auction hasn't already started
    (asserts! (is-eq (var-get auction-owner) 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (err "Auction already started"))
    
    ;; Set the auction end by incrementing from current block height
    (var-set auction-end duration)
    (var-set auction-owner tx-sender)
    (ok "Auction started")
  )
)


(define-public (place-bid (amount uint))
  (begin
    ;; Ensure the auction is still ongoing
    (asserts! (> (var-get auction-end) u0) (err "Auction has ended"))
    
    ;; Ensure the bid is higher than the current highest bid
    (asserts! (> amount (var-get highest-bid)) (err "Bid too low"))
    
    ;; Place the bid and update the highest bidder
    (var-set highest-bid amount)
    (var-set highest-bidder tx-sender)
    (ok "Bid placed")
  )
)


(define-public (end-auction)
  (begin
    ;; Ensure the auction has ended (duration passed)
    (asserts! (<= (var-get auction-end) u0) (err "Auction still ongoing"))
    
    ;; Ensure the sender is the auction owner
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Only auction owner can end the auction"))
    
    ;; Return the highest bidder and the highest bid
    (ok (var-get highest-bidder))
  )
)


;; Add at the top with other data vars
(define-data-var minimum-start-bid uint u100)

;; Modify start-auction to include starting bid
(define-public (start-auction-advanced (duration uint) (starting-bid uint))
  (begin
    (asserts! (is-eq (var-get auction-owner) 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (err "Auction already started"))
    (asserts! (>= starting-bid (var-get minimum-start-bid)) (err "Starting bid too low"))
    (var-set highest-bid starting-bid)
    (var-set auction-end duration)
    (var-set auction-owner tx-sender)
    (ok "Auction started")
  )
)


;; Add new data var
(define-data-var can-withdraw bool true)

(define-public (withdraw-bid)
  (begin
    (asserts! (var-get can-withdraw) (err "Withdrawals not allowed"))
    (asserts! (is-eq tx-sender (var-get highest-bidder)) (err "Not highest bidder"))
    (var-set highest-bid u0)
    (var-set highest-bidder 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
    (ok "Bid withdrawn successfully")
  ))



(define-data-var reserve-price uint u0)

(define-public (set-reserve-price (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not auction owner"))
    (var-set reserve-price price)
    (ok "Reserve price set")
  ))


(define-map bid-history uint {bidder: principal, amount: uint})
(define-data-var bid-count uint u0)

(define-public (record-bid (amount uint))
  (begin
    (map-set bid-history (var-get bid-count) {bidder: tx-sender, amount: amount})
    (var-set bid-count (+ (var-get bid-count) u1))
    (ok "Bid recorded")
  ))


(define-data-var buy-now-price uint u0)

(define-public (set-buy-now (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not auction owner"))
    (var-set buy-now-price price)
    (ok "Buy now price set")
  ))

(define-public (buy-now)
  (begin
    (asserts! (> (var-get buy-now-price) u0) (err "Buy now not available"))
    (var-set highest-bidder tx-sender)
    (var-set highest-bid (var-get buy-now-price))
    (var-set auction-end u0)
    (ok "Item purchased")
  ))


(define-data-var extension-minutes uint u5)

(define-public (extend-auction)
  (begin
    (asserts! (< (- (var-get auction-end) block-height) u10) (err "Not close to end time"))
    (var-set auction-end (+ (var-get auction-end) (var-get extension-minutes)))
    (ok "Auction extended")
  ))



(define-map auction-items uint {
    name: (string-utf8 50),
    quantity: uint,
    sold: uint
})

(define-public (add-auction-item (item-id uint) (name (string-utf8 50)) (quantity uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not auction owner"))
    (map-set auction-items item-id {name: name, quantity: quantity, sold: u0})
    (ok "Item added")
  ))



(define-map whitelisted-bidders principal bool)

(define-public (add-to-whitelist (bidder principal))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not auction owner"))
    (map-set whitelisted-bidders bidder true)
    (ok "Bidder whitelisted")
  ))

(define-public (check-whitelist (bidder principal))
  (ok (default-to false (map-get? whitelisted-bidders bidder))))
