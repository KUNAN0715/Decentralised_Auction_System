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



;; Add at the top with other data vars
(define-map categories uint (string-utf8 50))
(define-data-var category-count uint u0)

(define-public (create-category (name (string-utf8 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not authorized"))
    (map-set categories (var-get category-count) name)
    (var-set category-count (+ (var-get category-count) u1))
    (ok "Category created")
  ))


(define-map bidder-ratings principal {
    total-ratings: uint,
    rating-sum: uint
})

(define-public (rate-bidder (bidder principal) (rating uint))
  (begin 
    (asserts! (<= rating u5) (err "Rating must be 1-5"))
    (let ((current-rating (default-to {total-ratings: u0, rating-sum: u0} 
                          (map-get? bidder-ratings bidder))))
      (map-set bidder-ratings bidder 
        {total-ratings: (+ (get total-ratings current-rating) u1),
         rating-sum: (+ (get rating-sum current-rating) rating)})
      (ok "Rating submitted"))
  ))



(define-map auction-lots uint {
    item-count: uint,
    min-items: uint,
    max-items: uint
})

(define-public (create-lot (lot-id uint) (count uint) (min uint) (max uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not authorized"))
    (map-set auction-lots lot-id {
        item-count: count,
        min-items: min,
        max-items: max
    })
    (ok "Lot created")
  ))



(define-map time-discounts uint {
    hours-left: uint,
    discount-percent: uint
})

(define-public (set-time-discount (hours uint) (discount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not authorized"))
    (asserts! (<= discount u50) (err "Max discount is 50%"))
    (map-set time-discounts hours {
        hours-left: hours,
        discount-percent: discount
    })
    (ok "Discount set")
  ))



(define-map watchlist (tuple (user principal) (auction-id uint)) bool)

(define-public (add-to-watchlist (auction-id uint))
  (begin
    (map-set watchlist {user: tx-sender, auction-id: auction-id} true)
    (ok "Added to watchlist")
  ))

(define-public (remove-from-watchlist (auction-id uint))
  (begin
    (map-delete watchlist {user: tx-sender, auction-id: auction-id})
    (ok "Removed from watchlist")
  ))



(define-map bid-increments uint uint)

(define-public (set-bid-increment (price-range uint) (increment uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not authorized"))
    (map-set bid-increments price-range increment)
    (ok "Bid increment set")
  ))



(define-map group-bids uint {
    members: (list 50 principal),
    total-contribution: uint
})

(define-public (create-group-bid (group-id uint))
  (begin
    (map-set group-bids group-id {
        members: (list tx-sender),
        total-contribution: u0
    })
    (ok "Group bid created")
  ))



(define-map auction-history uint {
    start-time: uint,
    end-time: uint,
    winner: principal,
    final-price: uint
})

(define-public (record-auction-result (auction-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get auction-owner)) (err "Not authorized"))
    (map-set auction-history auction-id {
        start-time: block-height,
        end-time: (var-get auction-end),
        winner: (var-get highest-bidder),
        final-price: (var-get highest-bid)
    })
    (ok "Auction recorded")
  ))
