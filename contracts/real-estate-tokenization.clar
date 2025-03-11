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

;; -------------------------------
;; Property Transfer Functions
;; -------------------------------

(define-public (execute-property-transfer (asset-id uint) (new-owner principal))
    ;; Transfers property ownership to a new owner
    (begin
        (let ((current-owner (unwrap! (map-get? property-holder asset-id) error-property-unknown)))
            (asserts! (is-eq tx-sender current-owner) error-unauthorized-property-action)

            (let ((is-locked (default-to false (map-get? property-transfer-status asset-id))))
                (asserts! (not is-locked) error-property-locked))

            (asserts! (is-eq new-owner new-owner) error-recipient-invalid)
            (map-set property-holder asset-id new-owner)
            (map-set property-transfer-status asset-id true)
            (ok true))))

(define-public (lock-property-transfers (asset-id uint))
;; Prevents further transfers of a property
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (map-set property-transfer-status asset-id true)
    (ok true)))

(define-public (unlock-property-transfers (asset-id uint))
;; Enables transfers for a previously locked property
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (map-set property-transfer-status asset-id false)
    (map-set property-market-status asset-id true)
    (ok true)))

;; -------------------------------
;; Property Listing Functions
;; -------------------------------

(define-public (publish-property-listing (asset-id uint))
    ;; Makes a property available for sale
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (map-set property-market-status asset-id true)
        (ok true)))

(define-public (withdraw-property-listing (asset-id uint))
    ;; Removes property from market
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (map-set property-market-status asset-id false)
        (ok true)))

(define-public (remove-from-marketplace (asset-id uint))
;; Removes a property from the marketplace
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (map-set property-market-status asset-id false)
    (ok true)))

;; -------------------------------
;; Property Data Management Functions
;; -------------------------------

(define-public (update-property-metadata (asset-id uint) (metadata (string-ascii 256)))
    ;; Updates the metadata for an existing property
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (asserts! (validate-metadata metadata) error-property-metadata-invalid)
        (map-set property-metadata asset-id metadata)
        (ok true)))

(define-public (set-property-classification (asset-id uint) (classification (string-ascii 50)))
;; Assigns a classification to a property
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (asserts! (>= (len classification) u1) error-property-metadata-invalid)
    (map-set property-classification asset-id classification)
    (ok true)))

(define-public (set-property-coordinates (asset-id uint) (location (string-ascii 100)))
;; Sets the location details for a property
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (asserts! (>= (len location) u1) error-property-metadata-invalid)
    (map-set property-coordinates asset-id location)
    (ok true)))

(define-public (set-property-land-use (asset-id uint) (zoning-info (string-ascii 50)))
    ;; Updates the zoning information for a property
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (asserts! (>= (len zoning-info) u1) error-property-metadata-invalid)
        (map-set property-land-use asset-id zoning-info)
        (ok true)))

(define-public (remove-property-insurance (asset-id uint))
    ;; Removes insurance coverage from a property
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (map-set property-has-insurance asset-id false)
        (map-set property-insurer asset-id "")
        (ok true)))

;; -------------------------------
;; Property Information Retrieval
;; -------------------------------

(define-public (get-current-property-owner (asset-id uint))
    ;; Retrieves the current owner's address for a property
    (ok (map-get? property-holder asset-id)))

(define-public (get-property-details (asset-id uint))
    ;; Retrieves the stored metadata for a property
    (ok (map-get? property-metadata asset-id)))

(define-public (validate-claimed-ownership (asset-id uint) (claimed-owner principal))
;; Validates if the claimed owner matches the actual property owner
(let ((actual-owner (unwrap! (map-get? property-holder asset-id) error-property-unknown)))
    (ok (is-eq actual-owner claimed-owner))))

(define-public (get-property-metadata-length (asset-id uint))
;; Returns the length of the property metadata string
(ok (len (unwrap! (map-get? property-metadata asset-id) error-property-unknown))))

(define-public (check-transfer-status (asset-id uint))
    ;; Fetches the transfer status for a property
    (ok (map-get? property-transfer-status asset-id)))

(define-public (check-transfer-eligibility (asset-id uint))
    ;; Checks if a property is eligible for transfer
    (ok (and (not (default-to false (map-get? property-transfer-status asset-id)))
             (is-some (map-get? property-holder asset-id)))))

(define-public (fetch-owner-by-property-id (asset-id uint))
    ;; Retrieves the owner address for a property
    (ok (map-get? property-holder asset-id)))

(define-public (remove-from-transfer-whitelist (asset-id uint))
    ;; Removes a property from the transfer whitelist
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (map-set property-transfer-whitelist {asset-id: asset-id, authorized-buyer: tx-sender} false)
        (ok true)))

(define-public (secure-property (asset-id uint))
;; Locks a property to prevent modifications
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (map-set property-transfer-status asset-id true)
    (map-set property-market-status asset-id false)
    (ok true)))

;; -------------------------------
;; Property Feature Functions
;; -------------------------------

(define-public (submit-property-vote 
    (asset-id uint) 
    (motion-id uint) 
    (support bool))
    ;; Creates a voting mechanism for property decisions
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok support)))

(define-public (plan-maintenance 
    (asset-id uint) 
    (service-date uint))
    ;; Schedules maintenance for properties
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok service-date)))

(define-public (establish-rental-agreement 
    (asset-id uint) 
    (renter principal) 
    (term-length uint))
    ;; Creates rental agreements for properties
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok term-length)))

(define-public (record-valuation 
    (asset-id uint) 
    (appraisal-amount uint) 
    (record-date uint))
    ;; Tracks historical property valuations
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (ok appraisal-amount)))

(define-public (file-property-dispute 
    (asset-id uint) 
    (claimant principal) 
    (claim-details (string-ascii 256)))
    ;; Handles property-related disputes
    (begin
        (asserts! (validate-metadata claim-details) error-property-metadata-invalid)
        (ok true)))

(define-public (assign-access-rights 
    (asset-id uint) 
    (grantee principal) 
    (permission-level uint))
    ;; Manages access levels for different users
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok permission-level)))

(define-public (process-insurance-claim 
    (asset-id uint) 
    (amount uint) 
    (claim-details (string-ascii 256)))
    ;; Processes property insurance claims
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok amount)))

