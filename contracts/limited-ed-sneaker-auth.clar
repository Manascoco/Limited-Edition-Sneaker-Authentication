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
(define-constant ERR_WARRANTY_EXPIRED (err u701))
(define-constant ERR_NO_WARRANTY (err u702))
(define-constant ERR_CLAIM_EXISTS (err u703))
(define-constant ERR_INVALID_CLAIM (err u704))
(define-constant ERR_INSURANCE_EXPIRED (err u705))
(define-constant ERR_INVALID_ROYALTY (err u706))
(define-constant DEFAULT_ROYALTY_PERCENT u5)
(define-constant MAX_ROYALTY_PERCENT u25)

(define-data-var next-token-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var next-warranty-id uint u1)
(define-data-var next-claim-id uint u1)

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

(define-map sneaker-warranties
  uint
  {
    warranty-id: uint,
    token-id: uint,
    manufacturer: principal,
    coverage-type: (string-ascii 30),
    duration-blocks: uint,
    start-block: uint,
    is-active: bool,
    premium-paid: uint
  }
)

(define-map insurance-policies
  uint
  {
    policy-id: uint,
    token-id: uint,
    owner: principal,
    coverage-amount: uint,
    premium: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool
  }
)

(define-map warranty-claims
  uint
  {
    claim-id: uint,
    warranty-id: uint,
    claimant: principal,
    claim-type: (string-ascii 50),
    description: (string-ascii 200),
    filed-at: uint,
    status: (string-ascii 20),
    resolution: (optional (string-ascii 200))
  }
)

(define-map insurance-claims
  uint
  {
    claim-id: uint,
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    evidence-hash: (buff 32),
    filed-at: uint,
    status: (string-ascii 20),
    approved-amount: uint
  }
)

(define-map manufacturer-royalties
  principal
  {
    royalty-percent: uint,
    total-earned: uint,
    sales-count: uint
  }
)

(define-public (authorize-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-manufacturers manufacturer true)
    (map-set manufacturer-royalties manufacturer {
      royalty-percent: DEFAULT_ROYALTY_PERCENT,
      total-earned: u0,
      sales-count: u0
    })
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

(define-public (create-warranty (token-id uint) (coverage-type (string-ascii 30)) (duration-blocks uint) (premium uint))
  (let (
    (warranty-id (var-get next-warranty-id))
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
    (manufacturer (get manufacturer sneaker-info))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender manufacturer) ERR_NOT_AUTHORIZED)
    (asserts! (get is-authentic sneaker-info) ERR_INVALID_PARAMS)
    (asserts! (> duration-blocks u0) ERR_INVALID_PARAMS)
    
    (map-set sneaker-warranties warranty-id {
      warranty-id: warranty-id,
      token-id: token-id,
      manufacturer: manufacturer,
      coverage-type: coverage-type,
      duration-blocks: duration-blocks,
      start-block: stacks-block-height,
      is-active: true,
      premium-paid: premium
    })
    
    (add-history-entry token-id "WARRANTY_CREATED" manufacturer "Warranty coverage activated")
    (var-set next-warranty-id (+ warranty-id u1))
    (ok warranty-id)
  )
)

(define-public (purchase-insurance (token-id uint) (coverage-amount uint) (duration-blocks uint))
  (let (
    (policy-id (var-get next-claim-id))
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
    (current-owner (unwrap! (nft-get-owner? sneaker-nft token-id) ERR_NOT_FOUND))
    (premium (calculate-insurance-premium coverage-amount duration-blocks))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_OWNER)
    (asserts! (get is-authentic sneaker-info) ERR_INVALID_PARAMS)
    (asserts! (> coverage-amount u0) ERR_INVALID_PARAMS)
    (asserts! (> duration-blocks u0) ERR_INVALID_PARAMS)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set insurance-policies policy-id {
      policy-id: policy-id,
      token-id: token-id,
      owner: current-owner,
      coverage-amount: coverage-amount,
      premium: premium,
      start-block: stacks-block-height,
      end-block: (+ stacks-block-height duration-blocks),
      is-active: true
    })
    
    (add-history-entry token-id "INSURANCE_PURCHASED" current-owner "Insurance policy activated")
    (var-set next-claim-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (file-warranty-claim (warranty-id uint) (claim-type (string-ascii 50)) (description (string-ascii 200)))
  (let (
    (warranty-info (unwrap! (map-get? sneaker-warranties warranty-id) ERR_NO_WARRANTY))
    (claim-id (var-get next-claim-id))
    (current-block stacks-block-height)
    (warranty-end (+ (get start-block warranty-info) (get duration-blocks warranty-info)))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active warranty-info) ERR_NO_WARRANTY)
    (asserts! (< current-block warranty-end) ERR_WARRANTY_EXPIRED)
    (asserts! (> (len description) u0) ERR_INVALID_PARAMS)
    
    (map-set warranty-claims claim-id {
      claim-id: claim-id,
      warranty-id: warranty-id,
      claimant: tx-sender,
      claim-type: claim-type,
      description: description,
      filed-at: current-block,
      status: "PENDING",
      resolution: none
    })
    
    (add-history-entry (get token-id warranty-info) "WARRANTY_CLAIM" tx-sender "Warranty claim filed")
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (file-insurance-claim (policy-id uint) (claim-amount uint) (evidence-hash (buff 32)))
  (let (
    (policy-info (unwrap! (map-get? insurance-policies policy-id) ERR_NOT_FOUND))
    (claim-id (var-get next-claim-id))
    (current-block stacks-block-height)
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender (get owner policy-info)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active policy-info) ERR_INSURANCE_EXPIRED)
    (asserts! (< current-block (get end-block policy-info)) ERR_INSURANCE_EXPIRED)
    (asserts! (<= claim-amount (get coverage-amount policy-info)) ERR_INVALID_PARAMS)
    
    (map-set insurance-claims claim-id {
      claim-id: claim-id,
      policy-id: policy-id,
      claimant: tx-sender,
      claim-amount: claim-amount,
      evidence-hash: evidence-hash,
      filed-at: current-block,
      status: "PENDING",
      approved-amount: u0
    })
    
    (add-history-entry (get token-id policy-info) "INSURANCE_CLAIM" tx-sender "Insurance claim filed")
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (process-warranty-claim (claim-id uint) (approve bool) (resolution (string-ascii 200)))
  (let (
    (claim-info (unwrap! (map-get? warranty-claims claim-id) ERR_INVALID_CLAIM))
    (warranty-info (unwrap! (map-get? sneaker-warranties (get warranty-id claim-info)) ERR_NO_WARRANTY))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender (get manufacturer warranty-info)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status claim-info) "PENDING") ERR_INVALID_CLAIM)
    
    (map-set warranty-claims claim-id
      (merge claim-info {
        status: (if approve "APPROVED" "DENIED"),
        resolution: (some resolution)
      })
    )
    
    (add-history-entry (get token-id warranty-info) "WARRANTY_PROCESSED" tx-sender 
      (if approve "Warranty claim approved" "Warranty claim denied"))
    (ok approve)
  )
)

(define-public (process-insurance-claim (claim-id uint) (approved-amount uint))
  (let (
    (claim-info (unwrap! (map-get? insurance-claims claim-id) ERR_INVALID_CLAIM))
    (policy-info (unwrap! (map-get? insurance-policies (get policy-id claim-info)) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status claim-info) "PENDING") ERR_INVALID_CLAIM)
    (asserts! (<= approved-amount (get claim-amount claim-info)) ERR_INVALID_PARAMS)
    
    (if (> approved-amount u0)
      (try! (as-contract (stx-transfer? approved-amount tx-sender (get claimant claim-info))))
      true
    )
    
    (map-set insurance-claims claim-id
      (merge claim-info {
        status: (if (> approved-amount u0) "APPROVED" "DENIED"),
        approved-amount: approved-amount
      })
    )
    
    (add-history-entry (get token-id policy-info) "INSURANCE_PROCESSED" tx-sender
      (if (> approved-amount u0) "Insurance claim approved" "Insurance claim denied"))
    (ok approved-amount)
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

(define-private (calculate-insurance-premium (coverage-amount uint) (duration-blocks uint))
  (let (
    (base-rate u50)
    (time-factor (/ duration-blocks u1000))
    (amount-factor (/ coverage-amount u10000))
  )
    (+ base-rate (* time-factor amount-factor))
  )
)

(define-private (check-warranty-for-token (warranty-id uint) (data { token-id: uint, found: bool, current-block: uint }))
  (if (get found data)
    data
    (match (map-get? sneaker-warranties warranty-id)
      warranty-info
      (if (and 
            (is-eq (get token-id warranty-info) (get token-id data))
            (get is-active warranty-info)
            (< (get current-block data) (+ (get start-block warranty-info) (get duration-blocks warranty-info)))
          )
        (merge data { found: true })
        data
      )
      data
    )
  )
)

(define-private (check-insurance-for-token (policy-id uint) (data { token-id: uint, found: bool, current-block: uint }))
  (if (get found data)
    data
    (match (map-get? insurance-policies policy-id)
      policy-info
      (if (and 
            (is-eq (get token-id policy-info) (get token-id data))
            (get is-active policy-info)
            (>= (get current-block data) (get start-block policy-info))
            (< (get current-block data) (get end-block policy-info))
          )
        (merge data { found: true })
        data
      )
      data
    )
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
    (sneaker-info (unwrap! (map-get? sneaker-data token-id) ERR_NOT_FOUND))
    (price (get price listing))
    (manufacturer (get manufacturer sneaker-info))
    (royalty-info (map-get? manufacturer-royalties manufacturer))
    (royalty-percent (default-to DEFAULT_ROYALTY_PERCENT (get royalty-percent royalty-info)))
    (royalty-amount (/ (* price royalty-percent) u100))
    (seller-amount (- price royalty-amount))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active listing) ERR_NOT_FOR_SALE)
    (asserts! (not (is-eq tx-sender current-owner)) ERR_CANNOT_BUY_OWN)
    
    (try! (stx-transfer? seller-amount tx-sender current-owner))
    (try! (stx-transfer? royalty-amount tx-sender manufacturer))
    (try! (nft-transfer? sneaker-nft token-id current-owner tx-sender))
    
    (match royalty-info
      info (map-set manufacturer-royalties manufacturer {
        royalty-percent: (get royalty-percent info),
        total-earned: (+ (get total-earned info) royalty-amount),
        sales-count: (+ (get sales-count info) u1)
      })
      true
    )
    
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

(define-read-only (get-warranty (warranty-id uint))
  (map-get? sneaker-warranties warranty-id)
)

(define-read-only (get-insurance-policy (policy-id uint))
  (map-get? insurance-policies policy-id)
)

(define-read-only (get-warranty-claim (claim-id uint))
  (map-get? warranty-claims claim-id)
)

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (is-warranty-active (warranty-id uint))
  (match (map-get? sneaker-warranties warranty-id)
    warranty-info
    (let (
      (current-block stacks-block-height)
      (warranty-end (+ (get start-block warranty-info) (get duration-blocks warranty-info)))
    )
      (and (get is-active warranty-info) (< current-block warranty-end))
    )
    false
  )
)

(define-read-only (is-insurance-active (policy-id uint))
  (match (map-get? insurance-policies policy-id)
    policy-info
    (let ((current-block stacks-block-height))
      (and 
        (get is-active policy-info)
        (>= current-block (get start-block policy-info))
        (< current-block (get end-block policy-info))
      )
    )
    false
  )
)

(define-read-only (get-warranty-status (warranty-id uint))
  (match (map-get? sneaker-warranties warranty-id)
    warranty-info
    (let (
      (current-block stacks-block-height)
      (warranty-end (+ (get start-block warranty-info) (get duration-blocks warranty-info)))
      (blocks-remaining (if (< current-block warranty-end) (- warranty-end current-block) u0))
    )
      (some {
        warranty: warranty-info,
        is-active: (and (get is-active warranty-info) (< current-block warranty-end)),
        blocks-remaining: blocks-remaining,
        expired: (>= current-block warranty-end)
      })
    )
    none
  )
)

(define-read-only (get-insurance-quote (coverage-amount uint) (duration-blocks uint))
  {
    coverage-amount: coverage-amount,
    duration-blocks: duration-blocks,
    premium: (calculate-insurance-premium coverage-amount duration-blocks),
    rate-per-block: (/ (calculate-insurance-premium coverage-amount duration-blocks) duration-blocks)
  }
)

(define-read-only (get-protection-summary (token-id uint))
  (let (
    (sneaker-info (map-get? sneaker-data token-id))
  )
    (match sneaker-info
      info
      (some {
        token-id: token-id,
        has-warranty: (check-active-warranty token-id),
        has-insurance: (check-active-insurance token-id),
        is-authentic: (get is-authentic info),
        manufacturer: (get manufacturer info)
      })
      none
    )
  )
)

(define-read-only (check-active-warranty (token-id uint))
  (let 
    (
      (current-block stacks-block-height)
      (result (fold check-warranty-for-token (list u1 u2 u3 u4 u5) { token-id: token-id, found: false, current-block: current-block }))
    )
    (get found result)
  )
)

(define-read-only (check-active-insurance (token-id uint))
  (let 
    (
      (current-block stacks-block-height)
      (result (fold check-insurance-for-token (list u1 u2 u3 u4 u5) { token-id: token-id, found: false, current-block: current-block }))
    )
    (get found result)
  )
)

(define-public (set-royalty-percent (new-percent uint))
  (let (
    (current-royalty (map-get? manufacturer-royalties tx-sender))
  )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-manufacturers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-percent MAX_ROYALTY_PERCENT) ERR_INVALID_ROYALTY)
    
    (match current-royalty
      info (map-set manufacturer-royalties tx-sender
        (merge info { royalty-percent: new-percent })
      )
      (map-set manufacturer-royalties tx-sender {
        royalty-percent: new-percent,
        total-earned: u0,
        sales-count: u0
      })
    )
    (ok new-percent)
  )
)

(define-read-only (get-manufacturer-royalty-info (manufacturer principal))
  (map-get? manufacturer-royalties manufacturer)
)

(define-read-only (calculate-sale-breakdown (token-id uint) (sale-price uint))
  (let (
    (sneaker-info (map-get? sneaker-data token-id))
  )
    (match sneaker-info
      info
      (let (
        (manufacturer (get manufacturer info))
        (royalty-info (map-get? manufacturer-royalties manufacturer))
        (royalty-percent (default-to DEFAULT_ROYALTY_PERCENT (get royalty-percent royalty-info)))
        (royalty-amount (/ (* sale-price royalty-percent) u100))
        (seller-amount (- sale-price royalty-amount))
      )
        (some {
          total-price: sale-price,
          royalty-amount: royalty-amount,
          seller-amount: seller-amount,
          royalty-percent: royalty-percent,
          manufacturer: manufacturer
        })
      )
      none
    )
  )
)
