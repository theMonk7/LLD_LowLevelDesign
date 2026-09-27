# Module 09 Project — Thread-Safe Seat Booking Core

**Time:** 3–4 hours. Deliverable must survive a hostile concurrency test suite you write yourself.

## Brief

> Build the booking core for a cinema. A show has a seat map. Users reserve seats, pay, and receive tickets. Payment is slow (simulate 10–50 ms) and fails ~20% of the time. Reservations expire after a timeout if not paid. Users may retry a failed payment; retries must not double-charge. The system reports seat availability and per-show revenue at any time, consistently.

## Functional requirements
1. Reserve one or more seats atomically — either all requested seats, or none.
2. Pay for a reservation; on success the seats become sold and a ticket is issued.
3. On payment failure, seats return to free immediately.
4. Reservations expire after a configurable TTL; expired seats become free.
5. Cancel a sold ticket → seats free, refund recorded (idempotent).
6. Query availability and revenue consistently while bookings are in flight.

## Non-functional (the graded part)
7. **No overselling under any interleaving.** Prove it with a test running 5,000 concurrent bookings against 100 seats.
8. **No lock held across the payment call.** A slow gateway must not serialise unrelated shows.
9. **Idempotent payment** keyed by a client-supplied key; a duplicate submit charges once.
10. **No deadlock** even with multi-seat reservations acquired in any order (hint: sort the seat ids — that's lock ordering).
11. All shared state `Sendable` or actor-isolated; compiles clean under Swift 6 strict concurrency.
12. Deterministic tests — inject the clock, never `Task.sleep` to test expiry.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | 5,000 tasks book the same seat | exactly 1 succeeds |
| 2 | 5,000 tasks book 100 distinct seats, 50× oversubscribed | exactly 100 sold, 0 oversold |
| 3 | All-or-nothing: request [A1, A2] where A2 is taken | neither reserved |
| 4 | Payment fails | seats free again, no ticket |
| 5 | Two users submit the same idempotency key concurrently | one charge, identical ticket returned |
| 6 | Reservation not paid before TTL | seat free; a late payment is rejected |
| 7 | Cancel a sold ticket twice | one refund, second is a no-op |
| 8 | Revenue query during 1,000 in-flight bookings | never reflects an unpaid reservation |
| 9 | Two users reserve [A1,B1] and [B1,A1] simultaneously | no deadlock, one wins |
| 10 | Slow gateway (200 ms) on show 1 | show 2 bookings unaffected |

## Deliverables
1. `BookingCore.swift` — actors, value types, errors.
2. `StressTests.swift` — all 10 scenarios, with the concurrent ones using `withTaskGroup`.
3. `demo()` printing a run with mixed successes, failures and expiries.
4. A short `CONCURRENCY.md`: for each piece of mutable state, say **who owns it**, **what protects it**, and **which invariant it guards**. Include the lock-ordering rule and the TTL sweep strategy.

## Rubric (/50)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| No oversell under 5,000-task load | fails | passes sometimes | deterministic pass |
| All-or-nothing multi-seat reserve | partial reservations leak | mostly | atomic with rollback |
| No lock across payment | holds it | partial | payment outside all critical sections |
| Idempotency incl. concurrent duplicates | none | sequential only | task-coalesced, one charge |
| TTL expiry + late-payment rejection | missing | partial | both, deterministic via injected clock |
| Deadlock-free multi-seat ordering | deadlocks | luck | explicit ordering rule, documented |
| Consistent revenue/availability reads | torn reads | mostly | snapshot-consistent |
| Swift 6 strict concurrency clean | errors | warnings | clean, `Sendable` where it matters |
| Tests are deterministic | sleeps everywhere | some | injected clock, no flake |
| `CONCURRENCY.md` ownership table | absent | thin | every piece of state accounted for |

**40+/50** → Module 10.

## Extension questions
1. Two cinemas, one shared payment gateway with a global rate limit. Where does that limiter live, and what does it do to your actor boundaries?
2. The process crashes between charge and confirm. What's the recovery story? (This is where "idempotency key" becomes "outbox pattern".)
3. Your TTL sweep runs every 30 s. What's the worst-case seat-hold time, and how would you reduce it without a tighter loop?
4. Make revenue reads lock-free. What consistency do you give up?
5. Someone proposes one global actor for the whole cinema chain. Explain the throughput problem in one sentence.

Ask me to review your implementation and `CONCURRENCY.md` against this rubric.
