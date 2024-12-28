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

;; Public Functions
(define-public (create-course (title (string-ascii 100)) (description (string-utf8 500)) (price uint))
    (let
        (
            (course-id (var-get next-course-id))
        )
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

(define-public (update-course (course-id uint) (new-price uint))
    (let
        (
            (course (unwrap! (map-get? Courses {course-id: course-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get instructor course)) err-not-instructor)
        (asserts! (> new-price u0) err-invalid-price)
        (map-set Courses
            { course-id: course-id }
            (merge course { price: new-price })
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

(define-public (rate-course (course-id uint) (rating uint))
    (let
        (
            (enrollment (unwrap! (map-get? Enrollments {student: tx-sender, course-id: course-id}) err-not-found))
        )
        (asserts! (<= rating u5) err-invalid-rating)
        (asserts! (get purchased enrollment) err-not-found)
        (map-set Enrollments
            { student: tx-sender, course-id: course-id }
            { purchased: true, rating: (some rating) }
        )
        (ok true)
    )
)

(define-public (withdraw-revenue)
    (let
        (
            (revenue (unwrap! (map-get? InstructorRevenue {instructor: tx-sender}) err-not-found))
        )
        (map-set InstructorRevenue
            { instructor: tx-sender }
            { balance: u0 }
        )
        (ok (get balance revenue))
    )
)

;; Read-only Functions
(define-read-only (get-course (course-id uint))
    (map-get? Courses {course-id: course-id})
)

(define-read-only (get-enrollment (student principal) (course-id uint))
    (map-get? Enrollments {student: student, course-id: course-id})
)

(define-read-only (get-instructor-revenue (instructor principal))
    (default-to {balance: u0} (map-get? InstructorRevenue {instructor: instructor}))
)