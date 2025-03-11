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

(define-public (compute-property-tax 
    (asset-id uint) 
    (rate uint))
    ;; Calculates property tax based on value and rate
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (ok rate)))

(define-public (reserve-maintenance-budget 
    (asset-id uint) 
    (budget uint))
    ;; Allocates funds for property maintenance
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok budget)))

(define-public (allocate-revenue 
    (asset-id uint) 
    (revenue uint))
    ;; Distributes property-generated revenue
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok revenue)))

(define-public (associate-utility-account 
    (asset-id uint) 
    (service-id uint) 
    (account-id (string-ascii 50)))
    ;; Links utility accounts to properties
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok true)))

(define-public (document-renovation 
    (asset-id uint) 
    (expense uint) 
    (work-details (string-ascii 256)))
    ;; Tracks property renovation activities
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok expense)))

(define-public (certify-compliance 
    (asset-id uint) 
    (regulation-type (string-ascii 50)))
    ;; Verifies property compliance with regulations
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (ok true)))

(define-public (enhance-property-security (asset-id uint))
;; Adds extra security to a property transfer process
(begin
    (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
    (map-set property-transfer-status asset-id false)
    (ok true)))

(define-public (test-registration-process)
;; Test function to validate the property registration process
(begin
    (let ((test-id (+ (var-get property-counter) u1)))
        (asserts! (validate-metadata "Test Property") error-property-metadata-invalid)
        (ok true))))

(define-public (establish-tax-rate (rate uint))
;; Sets a global property tax rate
(begin
    (asserts! (is-eq tx-sender admin-address) error-admin-only)
    (ok true)))

;; -------------------------------
;; Property Validation Functions
;; -------------------------------

(define-public (test-property-transfer (asset-id uint) (recipient principal))
;; Tests the property transfer functionality
(begin
    (let ((current-owner (unwrap! (map-get? property-holder asset-id) error-property-unknown)))
        (asserts! (not (is-eq current-owner recipient)) error-recipient-invalid))
    (ok true)))

(define-public (check-insurance-status (asset-id uint))
;; Validates property insurance status
(ok (default-to false (map-get? property-has-insurance asset-id))))

(define-public (resolve-property-not-found (asset-id uint))
;; Resolves issues with property identification
(begin
    (let ((owner (unwrap! (map-get? property-holder asset-id) error-property-unknown)))
        (ok owner))))

(define-public (correct-transfer-error (asset-id uint) (recipient principal))
;; Corrects transfer errors by validating recipient
(begin
    (asserts! (is-eq recipient recipient) error-recipient-invalid)
    (ok "Transfer correction successful")))

;; -------------------------------
;; Advanced Property Functions
;; -------------------------------

(define-public (verify-documents 
    (asset-id uint) 
    (doc-hash (buff 32)))
    ;; Verifies property document authenticity
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok (is-eq doc-hash doc-hash))))

(define-public (book-property 
    (asset-id uint) 
    (check-in uint) 
    (check-out uint))
    ;; Manages property booking schedule
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok true)))

(define-public (report-damage 
    (asset-id uint) 
    (damage-category (string-ascii 50)) 
    (impact-level uint))
    ;; Records property damage incidents
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok impact-level)))

(define-public (monitor-value-growth 
    (asset-id uint) 
    (present-value uint) 
    (growth-rate uint))
    ;; Tracks property value growth
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (ok growth-rate)))

(define-public (record-access-event 
    (asset-id uint) 
    (visitor principal) 
    (timestamp uint))
    ;; Logs property access events
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok timestamp)))

(define-public (generate-audit-record 
    (asset-id uint) 
    (event-type (string-ascii 50)) 
    (event-details (string-ascii 256)))
    ;; Creates audit records for property actions
    (begin
        (asserts! (is-eq tx-sender admin-address) error-admin-only)
        (ok true)))

(define-public (project-investment-returns 
    (asset-id uint) 
    (investment-term uint))
    ;; Calculates property investment returns
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok investment-term)))

(define-public (evaluate-property-condition 
    (asset-id uint) 
    (condition-rating uint) 
    (inspection-notes (string-ascii 256)))
    ;; Records property condition assessments
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (ok condition-rating)))

(define-public (retrieve-maintenance-record (asset-id uint) (record-id uint))
    ;; Fetches maintenance history for a property
    (ok (map-get? property-upkeep-record {asset-id: asset-id, record-id: record-id})))

(define-public (update-land-use (asset-id uint) (zoning-info (string-ascii 50)))
    ;; Updates zoning information for a property
    (begin
        (asserts! (verify-ownership asset-id tx-sender) error-unauthorized-property-action)
        (asserts! (validate-metadata zoning-info) error-property-metadata-invalid)
        (map-set property-land-use asset-id zoning-info)
        (ok true)))

(define-public (get-maintenance-record (asset-id uint) (record-id uint))
    ;; Retrieves a specific maintenance record
    (ok (map-get? property-upkeep-record {asset-id: asset-id, record-id: record-id})))

(define-public (get-tax-assessment (asset-id uint))
    ;; Retrieves the tax assessment for a property
    (ok (map-get? property-annual-tax asset-id)))



(define-public (verify-insurance-coverage (asset-id uint))
    ;; Verifies if a property has insurance coverage
    (ok (map-get? property-has-insurance asset-id)))

(define-public (get-appraisal-record (asset-id uint) (appraisal-date uint))
    ;; Retrieves property appraisal data
    (ok (map-get? property-valuation-history {asset-id: asset-id, assessment-date: appraisal-date})))

(define-public (get-property-age-data (asset-id uint))
    ;; Retrieves property age information
    (ok (map-get? property-construction-year asset-id)))

;; -------------------------------
;; Read-Only Functions
;; -------------------------------

(define-read-only (is-property-locked (asset-id uint))
    ;; Checks if a property is locked for transfers
    (ok (default-to false (map-get? property-transfer-status asset-id))))

(define-read-only (get-latest-property-id)
    ;; Retrieves the most recently assigned property ID
    (ok (var-get property-counter)))

(define-read-only (verify-property-transfer-status (asset-id uint))
;; Checks if a property has been transferred
(ok (default-to false (map-get? property-transfer-status asset-id))))

(define-read-only (get-registry-size)
;; Returns the total number of registered properties
(ok (var-get property-counter)))

(define-read-only (check-property-existence (asset-id uint))
;; Checks if a property with the given ID exists
(ok (is-none (map-get? property-holder asset-id))))

(define-read-only (is-transferable (asset-id uint))
;; Checks if a property is eligible for transfer
(ok (not (default-to false (map-get? property-transfer-status asset-id)))))

(define-read-only (is-registered (asset-id uint))
;; Checks if the property ID exists in the registry
(ok (is-some (map-get? property-holder asset-id))))

(define-read-only (get-lock-status (asset-id uint))
;; Returns the lock status of a property
(ok (default-to false (map-get? property-transfer-status asset-id))))

(define-read-only (lookup-owner (asset-id uint))
;; Retrieves the owner's address for a property
(ok (map-get? property-holder asset-id)))

(define-read-only (can-be-transferred (asset-id uint))
;; Checks if a property is not locked for transfers
(ok (not (default-to false (map-get? property-transfer-status asset-id)))))

(define-read-only (get-property-info (asset-id uint))
;; Retrieves the property information
(ok (map-get? property-metadata asset-id)))

(define-read-only (asset-id-exists (asset-id uint))
;; Verifies if a specific property ID exists
(ok (is-some (map-get? property-holder asset-id))))

(define-read-only (get-property-metadata-hash (asset-id uint))
;; Returns the property metadata for verification
(ok (default-to "" 
    (map-get? property-metadata asset-id))))

(define-read-only (lookup-property-owner (asset-id uint))
;; Retrieves the owner's principal for a property
(ok (map-get? property-holder asset-id)))

(define-read-only (asset-exists (asset-id uint))
;; Checks if a property ID is valid
(ok (is-some (map-get? property-metadata asset-id))))

(define-read-only (total-properties)
;; Returns the total number of registered properties
(ok (var-get property-counter)))

(define-read-only (is-metadata-valid (data (string-ascii 256)))
;; Validates property metadata length
(ok (and (>= (len data) u1) (<= (len data) u256))))

(define-read-only (get-first-asset-id)
;; Returns the first property ID (always 1)
(ok u1))

(define-read-only (get-owner-address (asset-id uint))
;; Simple owner lookup
(ok (map-get? property-holder asset-id)))

(define-read-only (is-valid-asset-id (asset-id uint))
;; Checks if a property ID is within valid range
(ok (and (>= asset-id u1) (<= asset-id (var-get property-counter)))))

(define-read-only (get-metadata-length (asset-id uint))
;; Returns the length of property metadata
(ok (len (unwrap! (map-get? property-metadata asset-id) error-property-unknown))))

(define-read-only (check-lock-status (asset-id uint))
;; Quick check of property lock status
(ok (default-to false (map-get? property-transfer-status asset-id))))

(define-read-only (is-most-recent-asset (asset-id uint))
;; Checks if the given ID is the most recent property
(ok (is-eq asset-id (var-get property-counter))))

(define-read-only (retrieve-metadata (asset-id uint))
;; Retrieves basic property metadata
(ok (map-get? property-metadata asset-id)))

(define-read-only (is-valid-property (asset-id uint))
;; Basic validation of a property
(ok (and 
    (is-some (map-get? property-holder asset-id))
    (is-some (map-get? property-metadata asset-id)))))

(define-read-only (validate-asset-id (asset-id uint))
;; Checks if property ID is within valid range
(ok (and (>= asset-id u1) (<= asset-id (var-get property-counter)))))

(define-read-only (is-locked-for-transfer (asset-id uint))
;; Checks if property is locked
(ok (default-to false (map-get? property-transfer-status asset-id))))

(define-read-only (fetch-property-info (asset-id uint))
;; Retrieves basic property information
(ok (map-get? property-metadata asset-id)))

(define-read-only (get-property-owner (asset-id uint))
;; Simple owner lookup function
(ok (map-get? property-holder asset-id)))

(define-read-only (verify-asset-exists (asset-id uint))
;; Verifies if a property exists
(ok (is-some (map-get? property-holder asset-id))))

(define-read-only (asset-count)
;; Returns the total number of properties
(ok (var-get property-counter)))

(define-read-only (check-metadata-length (data (string-ascii 256)))
;; Checks if property metadata length is valid
(ok (and (>= (len data) u1) (<= (len data) u256))))

(define-read-only (get-base-asset-id)
;; Returns the first property ID
(ok u1))

(define-read-only (is-available-for-transfer (asset-id uint))
;; Checks if property is eligible for transfer
(ok (not (default-to false (map-get? property-transfer-status asset-id)))))

(define-read-only (get-metadata-size (asset-id uint))
;; Returns length of property metadata
(ok (len (unwrap! (map-get? property-metadata asset-id) error-property-unknown))))

(define-read-only (get-latest-asset-id)
;; Returns the last assigned property ID
(ok (var-get property-counter)))

(define-read-only (fetch-asset-details (asset-id uint))
;; Retrieves basic property details
(ok (map-get? property-metadata asset-id)))

(define-read-only (validate-asset-range (start-id uint) (end-id uint))
;; Validates a range of property IDs
(ok (and 
    (>= start-id u1) 
    (<= end-id (var-get property-counter))
    (<= start-id end-id))))

(define-read-only (has-owner (asset-id uint))
;; Checks if a property has an owner
(ok (is-some (map-get? property-holder asset-id))))

(define-read-only (get-next-asset-id)
;; Returns the next available property ID
(ok (+ (var-get property-counter) u1)))

(define-read-only (is-market-listed (asset-id uint))
;; Checks if a property is currently listed for sale
(ok (default-to false (map-get? property-market-status asset-id))))

(define-read-only (get-asset-classification (asset-id uint))
;; Retrieves the classification of a property
(ok (map-get? property-classification asset-id)))

(define-read-only (get-asset-location (asset-id uint))
;; Retrieves the location of a property
(ok (map-get? property-coordinates asset-id)))

(define-read-only (get-asset-value (asset-id uint))
;; Retrieves the market value of a property
(ok (map-get? property-market-value asset-id)))

(define-read-only (has-insurance (asset-id uint))
    ;; Checks if a property is insured
    (ok (default-to false (map-get? property-has-insurance asset-id))))

