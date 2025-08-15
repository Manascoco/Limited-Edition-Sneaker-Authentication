(define-non-fungible-token sneaker-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_NOT_OWNER (err u403))
(define-constant ERR_TRANSFER_FAILED (err u500))
(define-constant ERR_NOT_FOR_SALE (err u601))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u602))
(define-constant ERR_CANNOT_BUY_OWN (err u603))

(define-data-var next-token-id uint u1)
(define-data-var contract-paused bool false)

(define-map sneaker-data
  uint
  {
    brand: (string-ascii 50),
    model: (string-ascii 50),
    size: (string-ascii 10),
    color: (string-ascii 30),
    serial-number: (string-ascii 100),
    manufacturer: principal,
    authentication-date: uint,
    is-authentic: bool,
    physical-hash: (buff 32),
    metadata-uri: (string-ascii 256)
  }
)

(define-map authorized-manufacturers principal bool)

(define-map sneaker-history
  uint
  (list 50 {
    action: (string-ascii 20),
    timestamp: uint,
    actor: principal,
    details: (string-ascii 100)
  })
)

(define-map verification-requests
  uint
  {
    requester: principal,
    status: (string-ascii 20),
    timestamp: uint,
    verifier: (optional principal)
  }
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    is-active: bool
  }
)

(define-public (authorize-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-manufacturers manufacturer true)
    (ok true)
  )
)

(define-public (revoke-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-manufacturers manufacturer false)
    (ok true)
  )
)

(define-public (mint-sneaker-nft 
  (recipient principal)
  (brand (string-ascii 50))
  (model (string-ascii 50))
  (size (string-ascii 10))
  (color (string-ascii 30))
  (serial-number (string-ascii 100))
  (physical-hash (buff 32))
  (metadata-uri (string-ascii 256))
)
  (let (
    (token-id (var-get next-token-id))
    (manufacturer tx-sender)
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-manufacturers manufacturer)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len brand) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len model) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len serial-number) u0) ERR_INVALID_PARAMS)
    
    (try! (nft-mint? sneaker-nft token-id recipient))
    
    (map-set sneaker-data token-id {
      brand: brand,
      model: model,
      size: size,
      color: color,
      serial-number: serial-number,
      manufacturer: manufacturer,
      authentication-date: stacks-block-height,
      is-authentic: true,
      physical-hash: physical-hash,
      metadata-uri: metadata-uri
    })
    
    (add-history-entry token-id "MINTED" manufacturer "Initial mint by manufacturer")
    
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (nft-get-owner? sneaker-nft token-id)) ERR_NOT_FOUND)
    
    (try! (nft-transfer? sneaker-nft token-id sender recipient))
    (add-history-entry token-id "TRANSFERRED" sender "Transferred to new owner")
    
    (ok true)
  )
)

(define-public (verify-authenticity (token-id uint) (physical-hash (buff 32)))
  (let (
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get physical-hash sneaker-info) physical-hash) (err u600))
    
    (add-history-entry token-id "VERIFIED" tx-sender "Authenticity verified")
    
    (ok {
      authentic: (get is-authentic sneaker-info),
      brand: (get brand sneaker-info),
      model: (get model sneaker-info),
      serial-number: (get serial-number sneaker-info),
      manufacturer: (get manufacturer sneaker-info)
    })
  )
)

(define-public (request-verification (token-id uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? sneaker-data token-id)) ERR_NOT_FOUND)
    
    (map-set verification-requests token-id {
      requester: tx-sender,
      status: "PENDING",
      timestamp: stacks-block-height,
      verifier: none
    })
    
    (add-history-entry token-id "VERIFY_REQUEST" tx-sender "Verification requested")
    
    (ok true)
  )
)

(define-public (complete-verification (token-id uint) (is-authentic bool))
  (let (
    (verification-req (unwrap! (map-get? verification-requests token-id) ERR_NOT_FOUND))
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-manufacturers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status verification-req) "PENDING") ERR_INVALID_PARAMS)
    
    (map-set verification-requests token-id {
      requester: (get requester verification-req),
      status: (if is-authentic "VERIFIED" "REJECTED"),
      timestamp: stacks-block-height,
      verifier: (some tx-sender)
    })
    
    (map-set sneaker-data token-id 
      (merge sneaker-info { is-authentic: is-authentic })
    )
    
    (add-history-entry token-id "VERIFY_COMPLETE" tx-sender 
      (if is-authentic "Verification completed - authentic" "Verification completed - not authentic"))
    
    (ok is-authentic)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-private (add-history-entry (token-id uint) (action (string-ascii 20)) (actor principal) (details (string-ascii 100)))
  (let (
    (current-history (default-to (list) (map-get? sneaker-history token-id)))
    (new-entry {
      action: action,
      timestamp: stacks-block-height,
      actor: actor,
      details: details
    })
  )
    (map-set sneaker-history token-id (unwrap-panic (as-max-len? (append current-history new-entry) u50)))
    true
  )
)

(define-read-only (get-sneaker-data (token-id uint))
  (map-get? sneaker-data token-id)
)

(define-read-only (get-sneaker-history (token-id uint))
  (map-get? sneaker-history token-id)
)

(define-read-only (get-verification-request (token-id uint))
  (map-get? verification-requests token-id)
)

(define-read-only (is-manufacturer-authorized (manufacturer principal))
  (default-to false (map-get? authorized-manufacturers manufacturer))
)

(define-read-only (get-owner (token-id uint))
  (nft-get-owner? sneaker-nft token-id)
)

(define-read-only (get-last-token-id)
  (- (var-get next-token-id) u1)
)

(define-read-only (get-token-uri (token-id uint))
  (let (
    (sneaker-info (map-get? sneaker-data token-id))
  )
    (match sneaker-info
      info (ok (some (get metadata-uri info)))
      (ok none)
    )
  )
)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

(define-read-only (get-next-token-id)
  (var-get next-token-id)
)

(define-public (list-sneaker-for-sale (token-id uint) (price uint))
  (let (
    (current-owner (unwrap! (nft-get-owner? sneaker-nft token-id) ERR_NOT_FOUND))
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_OWNER)
    (asserts! (get is-authentic sneaker-info) ERR_INVALID_PARAMS)
    (asserts! (> price u0) ERR_INVALID_PARAMS)
    
    (map-set marketplace-listings token-id {
      seller: tx-sender,
      price: price,
      listed-at: stacks-block-height,
      is-active: true
    })
    
    (add-history-entry token-id "LISTED" tx-sender "Listed for sale")
    
    (ok true)
  )
)

(define-public (delist-sneaker (token-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings token-id) ERR_NOT_FOR_SALE))
    (current-owner (unwrap! (nft-get-owner? sneaker-nft token-id) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_OWNER)
    (asserts! (get is-active listing) ERR_NOT_FOR_SALE)
    
    (map-set marketplace-listings token-id
      (merge listing { is-active: false })
    )
    
    (add-history-entry token-id "DELISTED" tx-sender "Removed from sale")
    
    (ok true)
  )
)

(define-public (buy-sneaker (token-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings token-id) ERR_NOT_FOR_SALE))
    (current-owner (unwrap! (nft-get-owner? sneaker-nft token-id) ERR_NOT_FOUND))
    (price (get price listing))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active listing) ERR_NOT_FOR_SALE)
    (asserts! (not (is-eq tx-sender current-owner)) ERR_CANNOT_BUY_OWN)
    
    (try! (stx-transfer? price tx-sender current-owner))
    (try! (nft-transfer? sneaker-nft token-id current-owner tx-sender))
    
    (map-set marketplace-listings token-id
      (merge listing { is-active: false })
    )
    
    (add-history-entry token-id "SOLD" current-owner "Sold via marketplace")
    
    (ok true)
  )
)

(define-read-only (get-marketplace-listing (token-id uint))
  (map-get? marketplace-listings token-id)
)
