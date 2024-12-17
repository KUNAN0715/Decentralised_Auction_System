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