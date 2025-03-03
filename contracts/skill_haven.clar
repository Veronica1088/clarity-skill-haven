;; SkillHaven - Decentralized Course Marketplace Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant platform-fee-percentage u5) ;; 5% platform fee
(define-constant err-owner-only (err u100))
(define-constant err-invalid-price (err u101))
(define-constant err-not-found (err u102))
(define-constant err-already-purchased (err u103))
(define-constant err-not-instructor (err u104))
(define-constant err-invalid-rating (err u105))
(define-constant err-invalid-input (err u106))
(define-constant err-course-inactive (err u107))
(define-constant err-no-balance (err u108))

;; Data Variables
(define-map Courses
    { course-id: uint }
    {
        title: (string-ascii 100),
        description: (string-utf8 500),
        instructor: principal,
        price: uint,
        active: bool
    }
)

(define-map Enrollments
    { student: principal, course-id: uint }
    { purchased: bool, rating: (optional uint) }
)

(define-map InstructorRevenue
    { instructor: principal }
    { balance: uint }
)

(define-data-var next-course-id uint u1)

;; Private Functions
(define-private (calculate-platform-fee (amount uint))
    (/ (* amount platform-fee-percentage) u100)
)

(define-private (calculate-instructor-share (amount uint))
    (- amount (calculate-platform-fee amount))
)

(define-private (validate-course-input (title (string-ascii 100)) (description (string-utf8 500)))
    (and
        (> (len title) u0)
        (> (len description) u0)
    )
)

;; Public Functions
(define-public (create-course (title (string-ascii 100)) (description (string-utf8 500)) (price uint))
    (let
        (
            (course-id (var-get next-course-id))
        )
        (asserts! (validate-course-input title description) err-invalid-input)
        (asserts! (> price u0) err-invalid-price)
        (map-set Courses
            { course-id: course-id }
            {
                title: title,
                description: description,
                instructor: tx-sender,
                price: price,
                active: true
            }
        )
        (var-set next-course-id (+ course-id u1))
        (ok course-id)
    )
)

(define-public (toggle-course-status (course-id uint))
    (let
        (
            (course (unwrap! (map-get? Courses {course-id: course-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get instructor course)) err-not-instructor)
        (map-set Courses
            { course-id: course-id }
            (merge course { active: (not (get active course)) })
        )
        (ok true)
    )
)

(define-public (purchase-course (course-id uint))
    (let
        (
            (course (unwrap! (map-get? Courses {course-id: course-id}) err-not-found))
            (enrollment (map-get? Enrollments {student: tx-sender, course-id: course-id}))
        )
        (asserts! (get active course) err-course-inactive)
        (asserts! (not (is-some enrollment)) err-already-purchased)
        (map-set Enrollments
            { student: tx-sender, course-id: course-id }
            { purchased: true, rating: none }
        )
        (let
            (
                (instructor-share (calculate-instructor-share (get price course)))
                (current-balance (default-to {balance: u0} (map-get? InstructorRevenue {instructor: (get instructor course)})))
            )
            (map-set InstructorRevenue
                { instructor: (get instructor course) }
                { balance: (+ (get balance current-balance) instructor-share) }
            )
            (ok true)
        )
    )
)

;; [Previous functions remain unchanged...]

(define-public (withdraw-revenue)
    (let
        (
            (revenue (unwrap! (map-get? InstructorRevenue {instructor: tx-sender}) err-not-found))
        )
        (asserts! (> (get balance revenue) u0) err-no-balance)
        (map-set InstructorRevenue
            { instructor: tx-sender }
            { balance: u0 }
        )
        (ok (get balance revenue))
    )
)

;; [Read-only functions remain unchanged...]
