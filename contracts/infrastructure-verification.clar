;; Infrastructure Verification Contract
;; Validates hyperloop systems and infrastructure components

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Infrastructure status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_MAINTENANCE u3)

;; Data structures
(define-map infrastructure-registry
  { infrastructure-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    infrastructure-type: (string-ascii 50),
    status: uint,
    verification-date: uint,
    inspector: principal
  }
)

(define-map authorized-inspectors principal bool)

(define-data-var next-infrastructure-id uint u1)

;; Initialize contract owner as authorized inspector
(map-set authorized-inspectors CONTRACT_OWNER true)

;; Public functions
(define-public (register-infrastructure (location (string-ascii 100)) (infrastructure-type (string-ascii 50)))
  (let ((infrastructure-id (var-get next-infrastructure-id)))
    (map-set infrastructure-registry
      { infrastructure-id: infrastructure-id }
      {
        owner: tx-sender,
        location: location,
        infrastructure-type: infrastructure-type,
        status: STATUS_PENDING,
        verification-date: u0,
        inspector: CONTRACT_OWNER
      }
    )
    (var-set next-infrastructure-id (+ infrastructure-id u1))
    (ok infrastructure-id)
  )
)

(define-public (verify-infrastructure (infrastructure-id uint) (approved bool))
  (let ((infrastructure (unwrap! (map-get? infrastructure-registry { infrastructure-id: infrastructure-id }) ERR_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-inspectors tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status infrastructure) STATUS_PENDING) ERR_INVALID_STATUS)

    (map-set infrastructure-registry
      { infrastructure-id: infrastructure-id }
      (merge infrastructure {
        status: (if approved STATUS_VERIFIED STATUS_REJECTED),
        verification-date: block-height,
        inspector: tx-sender
      })
    )
    (ok true)
  )
)

(define-public (authorize-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-inspectors inspector true)
    (ok true)
  )
)

(define-public (set-maintenance-status (infrastructure-id uint))
  (let ((infrastructure (unwrap! (map-get? infrastructure-registry { infrastructure-id: infrastructure-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner infrastructure)) ERR_UNAUTHORIZED)

    (map-set infrastructure-registry
      { infrastructure-id: infrastructure-id }
      (merge infrastructure { status: STATUS_MAINTENANCE })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-infrastructure (infrastructure-id uint))
  (map-get? infrastructure-registry { infrastructure-id: infrastructure-id })
)

(define-read-only (is-verified (infrastructure-id uint))
  (match (map-get? infrastructure-registry { infrastructure-id: infrastructure-id })
    infrastructure (is-eq (get status infrastructure) STATUS_VERIFIED)
    false
  )
)

(define-read-only (is-authorized-inspector (inspector principal))
  (default-to false (map-get? authorized-inspectors inspector))
)
