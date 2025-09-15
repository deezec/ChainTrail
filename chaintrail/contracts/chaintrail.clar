;; Define SIP-009 NFT Trait
(define-trait digital-asset-trait
    (
        ;; Transfer token to a specified principal
        (transfer (uint principal principal) (response bool uint))

        ;; Get the owner of the specified token ID
        (get-owner (uint) (response (optional principal) uint))

        ;; Get the last token ID
        (get-last-token-id () (response uint uint))

        ;; Get the token URI
        (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    )
)

;; Constants
(define-constant admin-address tx-sender)
(define-constant error-admin-only (err u100))
(define-constant error-not-asset-owner (err u101))
(define-constant error-asset-not-found (err u102))
(define-constant error-listing-not-found (err u103))
(define-constant error-insufficient-balance (err u104))
(define-constant error-invalid-amount (err u105))
(define-constant error-market-paused (err u106))

;; Data Variables
(define-data-var current-token-id uint u0)
(define-data-var market-paused bool false)
(define-data-var market-commission uint u250) ;; 2.5% fee (basis points)

;; Define the NFT
(define-non-fungible-token premium-nft uint)

;; Data Maps
(define-map asset-metadata 
    uint 
    {
        holder: principal,
        uri: (string-utf8 256),
        minter: principal
    }
)

(define-map asset-listings 
    uint 
    {
        cost: uint,
        vendor: principal,
        deadline: uint
    }
)

;; Private Functions
(define-private (is-holder (asset-id uint))
    (match (map-get? asset-metadata asset-id)
        asset-info (is-eq tx-sender (get holder asset-info))
        false
    )    
)

(define-private (move-token (asset-id uint) (from principal) (to principal))
    (let (
        (asset-data (map-get? asset-metadata asset-id))
    )
        (asserts! (is-some asset-data) error-asset-not-found)
        (try! (nft-transfer? premium-nft asset-id from to))
        (map-set asset-metadata asset-id 
            (merge (unwrap-panic asset-data)
                   {holder: to}))
        (ok true)
    )
)

(define-private (compute-commission (cost uint))
    (/ (* cost (var-get market-commission)) u10000)
)

;; Public Functions

;; SIP009: Transfer token
(define-public (transfer (asset-id uint) (from principal) (to principal))
    (begin
        (asserts! (not (var-get market-paused)) error-market-paused)
        (asserts! (is-eq tx-sender from) error-not-asset-owner)
        (asserts! (is-holder asset-id) error-not-asset-owner)
        ;; Ensure the recipient is not the contract owner (optional safety check)
        (asserts! (not (is-eq to admin-address)) (err u999)) ;; Custom error for invalid recipient
        (move-token asset-id from to)
    )
)

;; NFT Core Functions
(define-public (mint (uri (string-utf8 256)))
    (let
        ((asset-id (+ (var-get current-token-id) u1)))
        (asserts! (not (var-get market-paused)) error-market-paused)
        ;; Ensure metadata-url is not empty
        (asserts! (> (len uri) u0) (err u998)) ;; Add custom error for empty metadata-url
        (try! (nft-mint? premium-nft asset-id tx-sender))
        (map-set asset-metadata asset-id 
            {
                holder: tx-sender,
                uri: uri,
                minter: tx-sender
            })
        (var-set current-token-id asset-id)
        (ok asset-id))
)

;; Marketplace Functions
(define-public (list-asset (asset-id uint) (cost uint) (deadline uint))
    (begin
        (asserts! (not (var-get market-paused)) error-market-paused)
        (asserts! (> cost u0) error-invalid-amount)
        (asserts! (is-holder asset-id) error-not-asset-owner)
        ;; Ensure expiry is a future block height
        (asserts! (> deadline u0) (err u997)) ;; Add custom error for invalid expiry
        (map-set asset-listings asset-id 
            {
                cost: cost,
                vendor: tx-sender,
                deadline: (+ block-height deadline)
            })
        (ok true))
)

(define-public (unlist-asset (asset-id uint))
    (begin
        (asserts! (not (var-get market-paused)) error-market-paused)
        (asserts! (is-holder asset-id) error-not-asset-owner)
        (map-delete asset-listings asset-id)
        (ok true))
)

(define-public (purchase-asset (asset-id uint))
    (let
        (
            (listing (unwrap! (map-get? asset-listings asset-id) error-listing-not-found))
            (cost (get cost listing))
            (vendor (get vendor listing))
            (deadline (get deadline listing))
        )
        (asserts! (not (var-get market-paused)) error-market-paused)
        (asserts! (<= block-height deadline) error-listing-not-found)
        (asserts! (>= (stx-get-balance tx-sender) cost) error-insufficient-balance)
        (let
            (
                (commission (compute-commission cost))
                (vendor-payment (- cost commission))
            )
            (try! (stx-transfer? vendor-payment tx-sender vendor))
            (try! (stx-transfer? commission tx-sender admin-address))
            (try! (move-token asset-id vendor tx-sender))
            (map-delete asset-listings asset-id)
            (ok true)))
)

;; Read-only Functions
(define-read-only (get-asset-metadata (asset-id uint))
    (map-get? asset-metadata asset-id)
)

(define-read-only (get-asset-listing (asset-id uint))
    (map-get? asset-listings asset-id)
)

;; SIP009: Get the owner of the specified token ID
(define-read-only (get-owner (asset-id uint))
    (match (map-get? asset-metadata asset-id)
        asset-data (ok (some (get holder asset-data)))
        (ok none)
    )
)

;; SIP009: Get the last token ID
(define-read-only (get-last-token-id)
    (ok (var-get current-token-id))
)

;; SIP009: Get the token URI
(define-read-only (get-token-uri (asset-id uint))
    (match (map-get? asset-metadata asset-id)
        asset-data (ok (some (get uri asset-data)))
        (ok none)
    )
)

;; Admin Functions
(define-public (set-market-commission (new-commission uint))
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (asserts! (<= new-commission u1000) error-invalid-amount) ;; Max 10% fee
        (var-set market-commission new-commission)
        (ok true))
)

(define-public (toggle-market-pause)
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (var-set market-paused (not (var-get market-paused)))
        (ok true))
)

(define-public (update-deadline (asset-id uint) (new-deadline uint))
    (let
        ((listing (unwrap! (map-get? asset-listings asset-id) error-listing-not-found)))
        (asserts! (is-eq tx-sender (get vendor listing)) error-not-asset-owner)
        (map-set asset-listings asset-id 
            (merge listing {deadline: (+ block-height new-deadline)}))
        (ok true))
)