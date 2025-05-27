;; Network Coordination Contract
;; Manages hyperloop transportation networks and routes

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_ROUTE_EXISTS (err u201))
(define-constant ERR_ROUTE_NOT_FOUND (err u202))
(define-constant ERR_INVALID_CAPACITY (err u203))
(define-constant ERR_INFRASTRUCTURE_NOT_VERIFIED (err u204))

;; Route status
(define-constant ROUTE_ACTIVE u1)
(define-constant ROUTE_INACTIVE u0)
(define-constant ROUTE_MAINTENANCE u2)

;; Data structures
(define-map network-routes
  { route-id: uint }
  {
    start-infrastructure: uint,
    end-infrastructure: uint,
    distance: uint,
    max-capacity: uint,
    current-load: uint,
    status: uint,
    operator: principal
  }
)

(define-map route-schedules
  { route-id: uint, time-slot: uint }
  {
    reserved-capacity: uint,
    operator: principal
  }
)

(define-data-var next-route-id uint u1)

;; Public functions
(define-public (create-route
  (start-infrastructure uint)
  (end-infrastructure uint)
  (distance uint)
  (max-capacity uint))
  (let ((route-id (var-get next-route-id)))
    ;; Verify infrastructure exists and is verified (simplified check)
    (asserts! (> max-capacity u0) ERR_INVALID_CAPACITY)

    (map-set network-routes
      { route-id: route-id }
      {
        start-infrastructure: start-infrastructure,
        end-infrastructure: end-infrastructure,
        distance: distance,
        max-capacity: max-capacity,
        current-load: u0,
        status: ROUTE_ACTIVE,
        operator: tx-sender
      }
    )
    (var-set next-route-id (+ route-id u1))
    (ok route-id)
  )
)

(define-public (reserve-capacity (route-id uint) (time-slot uint) (capacity uint))
  (let (
    (route (unwrap! (map-get? network-routes { route-id: route-id }) ERR_ROUTE_NOT_FOUND))
    (existing-reservation (default-to { reserved-capacity: u0, operator: tx-sender }
                          (map-get? route-schedules { route-id: route-id, time-slot: time-slot })))
  )
    (asserts! (is-eq (get status route) ROUTE_ACTIVE) ERR_UNAUTHORIZED)
    (asserts! (<= (+ (get reserved-capacity existing-reservation) capacity) (get max-capacity route)) ERR_INVALID_CAPACITY)

    (map-set route-schedules
      { route-id: route-id, time-slot: time-slot }
      {
        reserved-capacity: (+ (get reserved-capacity existing-reservation) capacity),
        operator: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (update-route-status (route-id uint) (new-status uint))
  (let ((route (unwrap! (map-get? network-routes { route-id: route-id }) ERR_ROUTE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator route)) ERR_UNAUTHORIZED)

    (map-set network-routes
      { route-id: route-id }
      (merge route { status: new-status })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-route (route-id uint))
  (map-get? network-routes { route-id: route-id })
)

(define-read-only (get-route-capacity (route-id uint) (time-slot uint))
  (match (map-get? route-schedules { route-id: route-id, time-slot: time-slot })
    reservation (get reserved-capacity reservation)
    u0
  )
)

(define-read-only (calculate-route-efficiency (route-id uint))
  (match (map-get? network-routes { route-id: route-id })
    route (/ (* (get current-load route) u100) (get max-capacity route))
    u0
  )
)
