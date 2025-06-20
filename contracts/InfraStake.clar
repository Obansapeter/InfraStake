;; ================================================
;; InfraLink Staking Hub - Decentralized Physical Infra Staking
;; ================================================

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INSUFFICIENT_STAKE (err u103))
(define-constant ERR_TOO_SOON (err u104))
(define-constant ERR_NOT_ACTIVE (err u105))
(define-constant ERR_NOT_ELIGIBLE (err u106))
(define-constant ERR_LOCKED (err u107))
(define-constant ERR_NOT_DELEGATED (err u108))

(define-data-var MIN_STAKE_AMOUNT uint u10000000) ;; 0.1 STX
(define-data-var REWARD_INTERVAL uint u144) ;; Approx. 24 hrs
(define-constant REWARD_AMOUNT u1000000) ;; 0.01 STX
(define-constant COOLDOWN_BLOCKS u288) ;; 2 days
(define-constant REWARD_PERCENTAGE u500) ;; 5% reward for simplicity
(define-constant oracle-admin 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Replace with actual oracle admin address
(define-constant contract-admin 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Replace with actual admin address

(define-map nodes principal {
    staked: uint,
    last-claim: uint,
    active: bool,
    last-online: uint,
    cooldown-start: (optional uint),
    lock-expiry: (optional uint),
    delegated-stake: (optional uint),  ;; New field for delegated stake
    delegated-to: (optional principal) ;; New field for tracking which node the stake is delegated to
})

(define-map reward-history principal (list 50 uint))
(define-map stake-history principal (list 50 uint))

(define-data-var total-staked uint u0)

(define-private (log-reward-history (amount uint))
    (match (map-get? reward-history tx-sender)
        prev-rewards (map-set reward-history tx-sender (unwrap-panic (as-max-len? (concat (list amount) prev-rewards) u50)))
        (map-set reward-history tx-sender (list amount))
    )
)

(define-private (log-stake-history (amount uint))
    (match (map-get? stake-history tx-sender)
        prev-stakes (map-set stake-history tx-sender (unwrap-panic (as-max-len? (concat (list amount) prev-stakes) u50)))
        (map-set stake-history tx-sender (list amount))
    )
)
(define-data-var contract-paused bool false)

;; ---------------------------
;; Register Node
;; ---------------------------
(define-public (register-node)
    (begin
        (if (is-some (map-get? nodes tx-sender))
            (err ERR_ALREADY_REGISTERED)
            (begin
                (map-set nodes tx-sender {
                    staked: u0,
                    last-claim: burn-block-height,
                    active: false,
                    last-online: u0,
                    cooldown-start: none,
                    lock-expiry: none,
                    delegated-stake: none,
                    delegated-to: none
                })
                (ok true)
            )
        )
    )
)

;; ---------------------------
;; Stake STX
;; ---------------------------
(define-public (stake-tokens)
    (if (var-get contract-paused)
        (err ERR_UNAUTHORIZED)
        (let ((node (map-get? nodes tx-sender)))
            (match node
                node-data
                (begin
                    (match (stx-transfer? (var-get MIN_STAKE_AMOUNT) tx-sender (as-contract tx-sender))
                        success-tx
                        (begin
                            (map-set nodes tx-sender {
                                staked: (+ (get staked node-data) (var-get MIN_STAKE_AMOUNT)),
                                last-claim: burn-block-height,
                                active: true,
                                last-online: burn-block-height,
                                cooldown-start: none,
                                lock-expiry: none,
                                delegated-stake: none,
                                delegated-to: none
                            })
                            (var-set total-staked (+ (var-get total-staked) (var-get MIN_STAKE_AMOUNT)))
                            (log-stake-history (var-get MIN_STAKE_AMOUNT))
                            (ok true)
                        )
                        error (err ERR_INSUFFICIENT_STAKE)
                    )
                )
                (err ERR_NOT_REGISTERED)
            )
        )
    )
)

;; ---------------------------
;; Delegate Stake
;; ---------------------------
(define-public (delegate-stake (target principal))
    (if (var-get contract-paused)
        (err ERR_UNAUTHORIZED)
        (let ((node (map-get? nodes tx-sender)))
            (match node
                node-data
                (begin
                    (if (is-eq (get staked node-data) u0)
                        (err ERR_NOT_ACTIVE)
                        (begin
                            (map-set nodes tx-sender {
                                staked: (get staked node-data),
                                last-claim: (get last-claim node-data),
                                active: true,
                                last-online: (get last-online node-data),
                                cooldown-start: (get cooldown-start node-data),
                                lock-expiry: (get lock-expiry node-data),
                                delegated-stake: (some (get staked node-data)),
                                delegated-to: (some target)
                            })
                            (ok true)
                        )
                    )
                )
                (err ERR_NOT_REGISTERED)
            )
        )
    )
)

;; ---------------------------
;; Undelegate Stake after cooldown
;; ---------------------------
(define-public (undelegate-stake)
    (if (var-get contract-paused)
        (err ERR_UNAUTHORIZED)
        (let ((node (map-get? nodes tx-sender)))
            (match node
                node-data
                (begin
                    (if (is-none (get delegated-to node-data))
                        (err ERR_NOT_DELEGATED)
                        (begin
                            (match (get cooldown-start node-data)
                                cooldown-val 
                                (if (>= (- burn-block-height cooldown-val) COOLDOWN_BLOCKS)
                                    (begin
                                        (map-set nodes tx-sender {
                                            staked: (+ (get staked node-data) (default-to u0 (get delegated-stake node-data))),
                                            last-claim: (get last-claim node-data),
                                            active: true,
                                            last-online: (get last-online node-data),
                                            cooldown-start: (get cooldown-start node-data),
                                            lock-expiry: (get lock-expiry node-data),
                                            delegated-stake: none,
                                            delegated-to: none
                                        })
                                        (ok true)
                                    )
                                    (err ERR_TOO_SOON))
                                (err ERR_NOT_ACTIVE)
                            )
                        )
                    )
                )
                (err ERR_NOT_REGISTERED)
            )
        )
    )
)

;; ---------------------------
;; Claim Daily Rewards Based on Stake
;; ---------------------------
(define-public (claim-reward-percentage)
    (if (var-get contract-paused)
        (err ERR_UNAUTHORIZED)
        (match (map-get? nodes tx-sender)
            node
            (if (and (get active node)
                     (>= (- burn-block-height (get last-claim node)) (var-get REWARD_INTERVAL))
                     (>= (- burn-block-height (get last-online node)) u0)) ;; online within last day
                (begin
                    (let ((stake (get staked node))
                          (reward (/ (* stake REWARD_PERCENTAGE) u10000))) ;; Apply percentage reward
                        (map-set nodes tx-sender {
                            staked: stake,
                            last-claim: burn-block-height,
                            active: true,
                            last-online: (get last-online node),
                            cooldown-start: (get cooldown-start node),
                            lock-expiry: (get lock-expiry node),
                            delegated-stake: (get delegated-stake node),
                            delegated-to: (get delegated-to node)
                        })
                        (log-reward-history reward)
                        (match (stx-transfer? reward (as-contract tx-sender) tx-sender)
                            success (ok true)
                            error (err ERR_NOT_ELIGIBLE)
                        )
                    )
                )
                (err ERR_NOT_ELIGIBLE)
            )
            (err ERR_NOT_REGISTERED)
        )
    )
)

;; ---------------------------
;; Pause Node (No Unstaking)
;; ---------------------------
(define-public (pause-node)
    (if (var-get contract-paused)
        (err ERR_UNAUTHORIZED)
        (match (map-get? nodes tx-sender)
            node
            (begin
                (map-set nodes tx-sender {
                    staked: (get staked node),
                    last-claim: (get last-claim node),
                    active: false,
                    last-online: (get last-online node),
                    cooldown-start: (some burn-block-height),
                    lock-expiry: (get lock-expiry node),
                    delegated-stake: (get delegated-stake node),
                    delegated-to: (get delegated-to node)
                })
                (ok true)
            )
            (err ERR_NOT_REGISTERED)
        )
    )
)

;; ---------------------------
;; Admin Functions to Control Contract Parameters
;; ---------------------------
(define-public (update-min-stake (new-min-stake uint))
    (if (is-eq tx-sender contract-admin)
        (begin
            (var-set MIN_STAKE_AMOUNT new-min-stake)
            (ok true)
        )
        (err ERR_UNAUTHORIZED)
    )
)

(define-public (update-reward-interval (new-interval uint))
    (if (is-eq tx-sender contract-admin)
        (begin
            (var-set REWARD_INTERVAL new-interval)
            (ok true)
        )
        (err ERR_UNAUTHORIZED)
    )
)

(define-public (toggle-pause)
    (if (is-eq tx-sender contract-admin)
        (begin
            (let ((paused (var-get contract-paused)))
                (var-set contract-paused (not paused))
                (ok (not paused))
            )
        )
        (err ERR_UNAUTHORIZED)
    )
)

;; ---------------------------
;; Read-Only Views
;; ---------------------------
(define-read-only (get-node (who principal))
    (match (map-get? nodes who)
        n (ok n)
        (err ERR_NOT_REGISTERED)
    )
)

(define-read-only (get-total-staked)
    (ok {total: (var-get total-staked)})
)
