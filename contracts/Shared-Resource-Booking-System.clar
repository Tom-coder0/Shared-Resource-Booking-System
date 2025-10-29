(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_RESOURCE_NOT_FOUND (err u101))
(define-constant ERR_RESOURCE_EXISTS (err u102))
(define-constant ERR_BOOKING_NOT_FOUND (err u103))
(define-constant ERR_BOOKING_EXISTS (err u104))
(define-constant ERR_INVALID_TIME (err u105))
(define-constant ERR_RESOURCE_UNAVAILABLE (err u106))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u107))
(define-constant ERR_BOOKING_EXPIRED (err u108))
(define-constant ERR_INVALID_DURATION (err u109))
(define-constant ERR_RESOURCE_INACTIVE (err u110))

(define-data-var next-resource-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u50)

(define-map resources
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    owner: principal,
    price-per-hour: uint,
    active: bool,
    category: (string-ascii 30),
    max-booking-duration: uint,
    created-at: uint
  }
)

(define-map bookings
  uint
  {
    resource-id: uint,
    user: principal,
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    status: (string-ascii 20),
    created-at: uint,
    payment-made: bool
  }
)

(define-map resource-bookings-count
  uint
  uint
)

(define-map user-bookings-count
  principal
  uint
)

(define-map active-bookings
  { resource-id: uint, start-block: uint }
  uint
)

(define-map user-stats
  principal
  {
    total-bookings: uint,
    total-spent: uint,
    reputation-score: uint
  }
)

(define-map resource-stats
  uint
  {
    total-bookings: uint,
    total-revenue: uint,
    rating: uint,
    review-count: uint
  }
)

(define-public (create-resource (name (string-ascii 50)) (description (string-ascii 200)) (price-per-hour uint) (category (string-ascii 30)) (max-booking-duration uint))
  (let
    (
      (resource-id (var-get next-resource-id))
      (current-time (var-get next-resource-id))
    )
    (asserts! (> (len name) u0) ERR_INVALID_DURATION)
    (asserts! (> price-per-hour u0) ERR_INVALID_DURATION)
    (asserts! (and (> max-booking-duration u0) (<= max-booking-duration u168)) ERR_INVALID_DURATION)
    
    (map-set resources resource-id
      {
        name: name,
        description: description,
        owner: tx-sender,
        price-per-hour: price-per-hour,
        active: true,
        category: category,
        max-booking-duration: max-booking-duration,
        created-at: current-time
      }
    )
    
    (map-set resource-stats resource-id
      {
        total-bookings: u0,
        total-revenue: u0,
        rating: u0,
        review-count: u0
      }
    )
    
    (map-set resource-bookings-count resource-id u0)
    (var-set next-resource-id (+ resource-id u1))
    (ok resource-id)
  )
)

(define-public (book-resource (resource-id uint) (start-time uint) (duration uint))
  (let
    (
      (resource (unwrap! (map-get? resources resource-id) ERR_RESOURCE_NOT_FOUND))
      (booking-id (var-get next-booking-id))
      (end-time (+ start-time duration))
      (current-time (var-get next-booking-id))
      (total-cost (* (get price-per-hour resource) duration))
    )
    (asserts! (get active resource) ERR_RESOURCE_INACTIVE)
    (asserts! (> start-time current-time) ERR_INVALID_TIME)
    (asserts! (and (> duration u0) (<= duration (get max-booking-duration resource))) ERR_INVALID_DURATION)
    (asserts! (is-none (map-get? active-bookings { resource-id: resource-id, start-block: start-time })) ERR_RESOURCE_UNAVAILABLE)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    (map-set bookings booking-id
      {
        resource-id: resource-id,
        user: tx-sender,
        start-time: start-time,
        end-time: end-time,
        total-cost: total-cost,
        status: "confirmed",
        created-at: current-time,
        payment-made: true
      }
    )
    
    (map-set active-bookings { resource-id: resource-id, start-block: start-time } booking-id)
    (increment-booking-counts resource-id tx-sender)
    (update-user-stats tx-sender total-cost)
    (update-resource-stats resource-id total-cost)
    
    (var-set next-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (cancel-booking (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (current-time (var-get next-booking-id))
    )
    (asserts! (or (is-eq tx-sender (get user booking)) (is-eq tx-sender (var-get contract-owner))) ERR_NOT_AUTHORIZED)
    (asserts! (> (get start-time booking) current-time) ERR_BOOKING_EXPIRED)
    (asserts! (is-eq (get status booking) "confirmed") ERR_BOOKING_NOT_FOUND)
    
    (map-set bookings booking-id (merge booking { status: "cancelled" }))
    (map-delete active-bookings { resource-id: (get resource-id booking), start-block: (get start-time booking) })
    
    (if (get payment-made booking)
      (begin
        (try! (as-contract (stx-transfer? (get total-cost booking) tx-sender (get user booking))))
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (update-resource (resource-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (price-per-hour uint) (active bool))
  (let
    (
      (resource (unwrap! (map-get? resources resource-id) ERR_RESOURCE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner resource)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_DURATION)
    (asserts! (> price-per-hour u0) ERR_INVALID_DURATION)
    
    (map-set resources resource-id (merge resource
      {
        name: name,
        description: description,
        price-per-hour: price-per-hour,
        active: active
      }
    ))
    (ok true)
  )
)

(define-public (complete-booking (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (resource (unwrap! (map-get? resources (get resource-id booking)) ERR_RESOURCE_NOT_FOUND))
      (current-time (var-get next-booking-id))
      (platform-fee-amount (/ (* (get total-cost booking) (var-get platform-fee)) u10000))
      (owner-payment (- (get total-cost booking) platform-fee-amount))
    )
    (asserts! (>= current-time (get end-time booking)) ERR_INVALID_TIME)
    (asserts! (is-eq (get status booking) "confirmed") ERR_BOOKING_NOT_FOUND)
    
    (map-set bookings booking-id (merge booking { status: "completed" }))
    (map-delete active-bookings { resource-id: (get resource-id booking), start-block: (get start-time booking) })
    
    (try! (as-contract (stx-transfer? owner-payment tx-sender (get owner resource))))
    (try! (as-contract (stx-transfer? platform-fee-amount tx-sender (var-get contract-owner))))
    
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR_INVALID_DURATION)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-resource (resource-id uint))
  (map-get? resources resource-id)
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id)
)

(define-public (withdraw-fees)
  (let
    (
      (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> contract-balance u0) ERR_INSUFFICIENT_PAYMENT)
    (try! (as-contract (stx-transfer? contract-balance tx-sender (var-get contract-owner))))
    (ok contract-balance)
  )
)

(define-public (add-review (resource-id uint) (rating uint))
  (let
    (
      (resource (unwrap! (map-get? resources resource-id) ERR_RESOURCE_NOT_FOUND))
      (current-stats (get-resource-stats resource-id))
      (new-review-count (+ (get review-count current-stats) u1))
      (total-rating (+ (* (get rating current-stats) (get review-count current-stats)) rating))
      (new-average-rating (/ total-rating new-review-count))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_DURATION)
    
    (map-set resource-stats resource-id (merge current-stats
      {
        rating: new-average-rating,
        review-count: new-review-count
      }
    ))
    (ok true)
  )
)

(define-read-only (get-user-stats (user principal))
  (default-to { total-bookings: u0, total-spent: u0, reputation-score: u0 } (map-get? user-stats user))
)

(define-read-only (get-resource-stats (resource-id uint))
  (default-to { total-bookings: u0, total-revenue: u0, rating: u0, review-count: u0 } (map-get? resource-stats resource-id))
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-next-resource-id)
  (var-get next-resource-id)
)

(define-read-only (get-next-booking-id)
  (var-get next-booking-id)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-resource-booked-at (resource-id uint) (start-block uint))
  (is-some (map-get? active-bookings { resource-id: resource-id, start-block: start-block }))
)

(define-read-only (get-booking-at-time (resource-id uint) (start-block uint))
  (map-get? active-bookings { resource-id: resource-id, start-block: start-block })
)

(define-read-only (get-user-booking-count (user principal))
  (default-to u0 (map-get? user-bookings-count user))
)

(define-read-only (get-resource-booking-count (resource-id uint))
  (default-to u0 (map-get? resource-bookings-count resource-id))
)

(define-private (increment-booking-counts (resource-id uint) (user principal))
  (let
    (
      (current-user-count (get-user-booking-count user))
      (current-resource-count (get-resource-booking-count resource-id))
    )
    (map-set user-bookings-count user (+ current-user-count u1))
    (map-set resource-bookings-count resource-id (+ current-resource-count u1))
    true
  )
)

(define-private (update-user-stats (user principal) (amount uint))
  (let
    (
      (current-stats (get-user-stats user))
    )
    (map-set user-stats user
      {
        total-bookings: (+ (get total-bookings current-stats) u1),
        total-spent: (+ (get total-spent current-stats) amount),
        reputation-score: (get reputation-score current-stats)
      }
    )
    true
  )
)

(define-private (update-resource-stats (resource-id uint) (amount uint))
  (let
    (
      (current-stats (get-resource-stats resource-id))
    )
    (map-set resource-stats resource-id
      {
        total-bookings: (+ (get total-bookings current-stats) u1),
        total-revenue: (+ (get total-revenue current-stats) amount),
        rating: (get rating current-stats),
        review-count: (get review-count current-stats)
      }
    )
    true
  )
)
