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
