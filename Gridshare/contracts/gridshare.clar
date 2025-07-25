;; GridShare - Peer-to-Peer Renewable Energy Trading Platform
;; Aligns with SDG 7: Affordable and Clean Energy & SDG 11: Sustainable Cities
;; Enables prosumers to trade renewable energy directly

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-energy (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-bid-too-low (err u106))
(define-constant err-not-active (err u107))

;; Data Variables
(define-data-var total-energy-traded uint u0) ;; in kWh
(define-data-var green-certificates-issued uint u0)
(define-data-var base-energy-price uint u1000) ;; microSTX per kWh
(define-data-var peak-hour-multiplier uint u150) ;; 1.5x during peak

;; Data Maps
(define-map prosumers
    principal
    {
        energy-generated: uint, ;; Total kWh generated
        energy-consumed: uint,  ;; Total kWh consumed
        net-position: int,      ;; Positive = surplus, Negative = deficit
        solar-capacity: uint,   ;; Installed capacity in kW
        location-zone: (string-ascii 20),
        green-score: uint
    }
)

(define-map energy-listings
    uint ;; listing-id
    {
        seller: principal,
        amount-kwh: uint,
        price-per-kwh: uint,
        available-from: uint,
        available-until: uint,
        renewable-type: (string-ascii 20), ;; solar, wind, hydro
        active: bool
    }
)

(define-map energy-bids
    uint ;; bid-id
    {
        buyer: principal,
        listing-id: uint,
        amount-kwh: uint,
        bid-price: uint,
        accepted: bool
    }
)

(define-map green-certificates
    uint ;; certificate-id
    {
        owner: principal,
        energy-amount: uint,
        generation-date: uint,
        source-type: (string-ascii 20),
        retired: bool
    }
)

(define-map zone-statistics
    (string-ascii 20) ;; zone
    {
        total-generation: uint,
        total-consumption: uint,
        average-price: uint,
        prosumer-count: uint
    }
)

;; Data Variables for counters
(define-data-var listing-counter uint u0)
(define-data-var bid-counter uint u0)

;; Public Functions
(define-public (register-prosumer (solar-capacity uint) (location-zone (string-ascii 20)))
    (begin
        (asserts! (is-none (map-get? prosumers tx-sender)) err-already-exists)
        (map-set prosumers tx-sender {
            energy-generated: u0,
            energy-consumed: u0,
            net-position: 0,
            solar-capacity: solar-capacity,
            location-zone: location-zone,
            green-score: u50
        })
        
        ;; Update zone statistics
        (let
            (
                (zone-stats (default-to {total-generation: u0, total-consumption: u0, average-price: u1000, prosumer-count: u0}
                           (map-get? zone-statistics location-zone)))
            )
            (map-set zone-statistics location-zone
                (merge zone-stats {prosumer-count: (+ (get prosumer-count zone-stats) u1)}))
        )
        (ok true)
    )
)

(define-public (report-generation (amount-kwh uint))
    (let
        (
            (prosumer (unwrap! (map-get? prosumers tx-sender) err-not-found))
            (new-total (+ (get energy-generated prosumer) amount-kwh))
            (new-net (+ (get net-position prosumer) (to-int amount-kwh)))
        )
        (map-set prosumers tx-sender
            (merge prosumer {
                energy-generated: new-total,
                net-position: new-net
            }))
        
        ;; Issue green certificate
        (let
            (
                (cert-id (var-get green-certificates-issued))
            )
            (map-set green-certificates cert-id {
                owner: tx-sender,
                energy-amount: amount-kwh,
                generation-date: block-height,
                source-type: "solar",
                retired: false
            })
            (var-set green-certificates-issued (+ cert-id u1))
        )
        
        (ok true)
    )
)

(define-public (list-energy (amount-kwh uint) 
                          (price-per-kwh uint)
                          (available-hours uint)
                          (renewable-type (string-ascii 20)))
    (let
        (
            (prosumer (unwrap! (map-get? prosumers tx-sender) err-not-found))
            (listing-id (var-get listing-counter))
        )
        (asserts! (>= (get net-position prosumer) (to-int amount-kwh)) err-insufficient-energy)
        (asserts! (> price-per-kwh u0) err-invalid-amount)
        
        (map-set energy-listings listing-id {
            seller: tx-sender,
            amount-kwh: amount-kwh,
            price-per-kwh: price-per-kwh,
            available-from: block-height,
            available-until: (+ block-height available-hours),
            renewable-type: renewable-type,
            active: true
        })
        
        (var-set listing-counter (+ listing-id u1))
        (ok listing-id)
    )
)

(define-public (place-bid (listing-id uint) (amount-kwh uint) (bid-price uint))
    (let
        (
            (listing (unwrap! (map-get? energy-listings listing-id) err-not-found))
            (bid-id (var-get bid-counter))
        )
        (asserts! (get active listing) err-not-active)
        (asserts! (<= amount-kwh (get amount-kwh listing)) err-invalid-amount)
        (asserts! (>= bid-price (get price-per-kwh listing)) err-bid-too-low)
        
        (map-set energy-bids bid-id {
            buyer: tx-sender,
            listing-id: listing-id,
            amount-kwh: amount-kwh,
            bid-price: bid-price,
            accepted: false
        })
        
        (var-set bid-counter (+ bid-id u1))
        (ok bid-id)
    )
)

(define-public (accept-bid (bid-id uint))
    (let
        (
            (bid (unwrap! (map-get? energy-bids bid-id) err-not-found))
            (listing (unwrap! (map-get? energy-listings (get listing-id bid)) err-not-found))
            (seller-info (unwrap! (map-get? prosumers tx-sender) err-not-found))
            (buyer-info (unwrap! (map-get? prosumers (get buyer bid)) err-not-found))
            (total-price (* (get amount-kwh bid) (get bid-price bid)))
        )
        (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
        (asserts! (get active listing) err-not-active)
        (asserts! (not (get accepted bid)) err-already-exists)
        
        ;; Transfer payment
        (try! (stx-transfer? total-price (get buyer bid) tx-sender))
        
        ;; Update energy positions
        (map-set prosumers tx-sender
            (merge seller-info {
                net-position: (- (get net-position seller-info) (to-int (get amount-kwh bid)))
            }))
        
        (map-set prosumers (get buyer bid)
            (merge buyer-info {
                energy-consumed: (+ (get energy-consumed buyer-info) (get amount-kwh bid)),
                net-position: (+ (get net-position buyer-info) (to-int (get amount-kwh bid)))
            }))
        
        ;; Update bid and listing
        (map-set energy-bids bid-id (merge bid {accepted: true}))
        
        ;; Update listing if fully sold
        (if (is-eq (get amount-kwh bid) (get amount-kwh listing))
            (map-set energy-listings (get listing-id bid) (merge listing {active: false}))
            (map-set energy-listings (get listing-id bid) 
                (merge listing {amount-kwh: (- (get amount-kwh listing) (get amount-kwh bid))}))
        )
        
        ;; Update statistics
        (var-set total-energy-traded (+ (var-get total-energy-traded) (get amount-kwh bid)))
        
        (ok true)
    )
)

(define-public (buy-direct (listing-id uint) (amount-kwh uint))
    (let
        (
            (listing (unwrap! (map-get? energy-listings listing-id) err-not-found))
            (buyer-info (unwrap! (map-get? prosumers tx-sender) err-not-found))
            (seller-info (unwrap! (map-get? prosumers (get seller listing)) err-not-found))
            (total-price (* amount-kwh (get price-per-kwh listing)))
        )
        (asserts! (get active listing) err-not-active)
        (asserts! (<= amount-kwh (get amount-kwh listing)) err-invalid-amount)
        (asserts! (< block-height (get available-until listing)) err-not-active)
        
        ;; Transfer payment
        (try! (stx-transfer? total-price tx-sender (get seller listing)))
        
        ;; Update positions
        (map-set prosumers (get seller listing)
            (merge seller-info {
                net-position: (- (get net-position seller-info) (to-int amount-kwh))
            }))
        
        (map-set prosumers tx-sender
            (merge buyer-info {
                energy-consumed: (+ (get energy-consumed buyer-info) amount-kwh),
                net-position: (+ (get net-position buyer-info) (to-int amount-kwh))
            }))
        
        ;; Update listing
        (if (is-eq amount-kwh (get amount-kwh listing))
            (map-set energy-listings listing-id (merge listing {active: false}))
            (map-set energy-listings listing-id 
                (merge listing {amount-kwh: (- (get amount-kwh listing) amount-kwh)}))
        )
        
        ;; Update zone statistics
        (let
            (
                (zone (get location-zone buyer-info))
                (zone-stats (unwrap! (map-get? zone-statistics zone) err-not-found))
            )
            (map-set zone-statistics zone
                (merge zone-stats {
                    total-consumption: (+ (get total-consumption zone-stats) amount-kwh),
                    average-price: (/ (+ (* (get average-price zone-stats) (get total-consumption zone-stats))
                                        total-price)
                                     (+ (get total-consumption zone-stats) amount-kwh))
                }))
        )
        
        (var-set total-energy-traded (+ (var-get total-energy-traded) amount-kwh))
        (ok true)
    )
)

(define-public (retire-green-certificate (certificate-id uint))
    (let
        (
            (cert (unwrap! (map-get? green-certificates certificate-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner cert)) err-unauthorized)
        (asserts! (not (get retired cert)) err-already-exists)
        
        (map-set green-certificates certificate-id
            (merge cert {retired: true}))
        
        ;; Update green score
        (let
            (
                (prosumer (unwrap! (map-get? prosumers tx-sender) err-not-found))
                (new-score (+ (get green-score prosumer) u10))
            )
            (map-set prosumers tx-sender
                (merge prosumer {green-score: new-score}))
        )
        
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-prosumer-info (user principal))
    (map-get? prosumers user)
)

(define-read-only (get-listing (listing-id uint))
    (map-get? energy-listings listing-id)
)

(define-read-only (get-zone-stats (zone (string-ascii 20)))
    (map-get? zone-statistics zone)
)

(define-read-only (get-current-energy-price (zone (string-ascii 20)))
    (let
        (
            (zone-stats (default-to {total-generation: u0, total-consumption: u0, average-price: (var-get base-energy-price), prosumer-count: u0}
                       (map-get? zone-statistics zone)))
            (hour-of-day u14) ;; Simplified - would need oracle in production
            (is-peak (and (>= hour-of-day u17) (<= hour-of-day u21)))
        )
        (if is-peak
            (/ (* (get average-price zone-stats) (var-get peak-hour-multiplier)) u100)
            (get average-price zone-stats)
        )
    )
)