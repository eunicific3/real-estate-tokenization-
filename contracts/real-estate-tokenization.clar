;; File: tokenized-real-estate.clar
;; Description: Smart Contract for Real Estate Tokenization via NFTs
;; This contract enables property registration, ownership management, and transfer
;; of real estate assets represented as non-fungible tokens on the blockchain.

;; -------------------------------
;; Core Constants and Error Codes
;; -------------------------------

(define-constant admin-address tx-sender) 
;; Administrator address - the entity that deployed this contract

(define-constant error-admin-only (err u100)) 
;; Error: Operation restricted to administrator only

(define-constant error-unauthorized-property-action (err u101)) 
;; Error: Caller lacks ownership rights to this property

(define-constant error-duplicate-property (err u102)) 
;; Error: Property with this identifier already exists

(define-constant error-property-unknown (err u103)) 
;; Error: Referenced property does not exist in registry

(define-constant error-recipient-invalid (err u104)) 
;; Error: Property transfer failed due to invalid recipient address

(define-constant error-property-locked (err u105)) 
;; Error: Property is locked and cannot be transferred

(define-constant error-property-metadata-invalid (err u106)) 
;; Error: Property metadata is invalid (empty or exceeds size limits)

;; -------------------------------
;; NFT Definition and State Variables
;; -------------------------------

(define-non-fungible-token real-estate-asset uint) 
;; NFT definition representing unique real estate properties

(define-data-var property-counter uint u0) 
;; Counter to generate unique property identifiers

;; -------------------------------
;; Primary Data Maps
;; -------------------------------

(define-map property-metadata uint (string-ascii 256)) 
;; Stores property details and description

(define-map property-holder uint principal) 
;; Maps property IDs to current owner addresses

(define-map property-transfer-status uint bool) 
;; Tracks whether a property has been transferred

(define-map property-market-status uint bool)
;; Property listing status (available for sale)

;; -------------------------------
;; Property Attribute Maps
;; -------------------------------

(define-map property-classification uint (string-ascii 50))
;; Property type classification (residential, commercial, etc.)

(define-map property-coordinates uint (string-ascii 100))
;; Geographic location information

(define-map property-market-value uint uint)
;; Current market valuation

(define-map property-has-insurance uint bool)
(define-map property-insurer uint (string-ascii 50))
;; Insurance information

(define-map property-upkeep-record 
    {asset-id: uint, record-id: uint} 
    {notes: (string-ascii 256), timestamp: uint})
;; Maintenance and repair history

(define-map property-annual-tax uint uint)
;; Annual property tax amount

(define-map property-is-occupied uint bool)
;; Current occupancy status

(define-map property-land-use uint (string-ascii 50))
;; Zoning and land use designation

(define-map property-transfer-whitelist 
    {asset-id: uint, authorized-buyer: principal} 
    bool)
;; Pre-approved buyer addresses for property transfers

(define-map property-construction-year uint uint)
;; Year property was constructed

(define-map property-valuation-history 
    {asset-id: uint, assessment-date: uint} 
    uint)
;; Historical property valuations

;; -------------------------------
;; Private Helper Functions
;; -------------------------------

(define-private (verify-ownership (asset-id uint) (address principal))
    ;; Verifies that the address is the current owner of the property
    (is-eq address (unwrap! (map-get? property-holder asset-id) false)))

(define-private (validate-metadata (metadata (string-ascii 256)))
    ;; Ensures that property metadata is valid (non-empty and within size limits)
    (let ((content-length (len metadata)))
        (and (>= content-length u1)
             (<= content-length u256))))

(define-private (create-property-record (metadata (string-ascii 256)))
    ;; Creates a new property record with a unique ID and stores its metadata
    (let ((asset-id (+ (var-get property-counter) u1)))
        (asserts! (validate-metadata metadata) error-property-metadata-invalid)
        (try! (nft-mint? real-estate-asset asset-id tx-sender))
        (map-set property-metadata asset-id metadata)
        (map-set property-holder asset-id tx-sender)
        (var-set property-counter asset-id)
        (ok asset-id)))

;; -------------------------------
;; Property Registration Functions
;; -------------------------------

(define-public (register-new-property (metadata (string-ascii 256)))
    ;; Registers a new property (admin only)
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (asserts! (validate-metadata metadata) error-property-metadata-invalid)
        (create-property-record metadata)))

(define-public (register-multiple-properties 
(property-descriptions (list 10 (string-ascii 256))))
;; Enables bulk registration of properties (admin only)
(begin
    (asserts! (is-eq tx-sender admin-address) error-admin-only)
    (let ((registration-results 
        (map create-property-record property-descriptions)))
        (ok registration-results))))
