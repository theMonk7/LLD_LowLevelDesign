# Module 09 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M09`.

**These tests run real concurrent load** — 10,000 overlapping increments, 500 racing bookings, 2,000 simultaneous rate-limit checks. A missing lock doesn't look wrong, it *fails*.

### E1 — `SafeCounter` (actor)
10,000 concurrent increments must total 10,000. Trivial to write, and the test is the point: run it, then mentally remove the `actor` keyword and predict the result.

### E2 — `LockedCounter` (NSLock)
The same thing with a synchronous API. Use `defer { lock.unlock() }` — the test won't catch a missing `defer`, but a `throw` in production will.

### E3 — `SeatBooking`
Make `book(_:)` atomic. 500 tasks race for one seat; exactly one must win.
*Hint:* `Set.insert` returns `(inserted: Bool, memberAfterInsert:)` — check-and-act in one call.

### E4 — Reserve → pay → confirm/release ⭐
The exercise that matters most. `reserve` must be **synchronous** (no `await` inside), because a suspension mid-method lets another booking interleave. The payment happens outside the actor; success confirms, failure releases.
The graded case: while a slow payment is in flight, a second booker must get `.seatTaken`.

### E5 — Fixed-window rate limiter
Test-and-consume in one atomic step, with an injected clock so tests never sleep. 2,000 concurrent calls against a limit of 100 must allow exactly 100.

### E6 — Idempotent payments ⭐ the trap
A naive `if let done = processed[key]` check fails under concurrency: `charge` is async, the actor suspends, and 200 callers with the same key all miss. You must record the **in-flight `Task`** under the key so later callers await the same one.
This is actor reentrancy, and it's the subtlest thing in the module.

### E7 — Optimistic locking
`compareAndSet` writes only if the version still matches; `decrement` retries. Concurrent decrements must never oversell.

### E8 — Reader-writer cache
Concurrent reads, barrier writes, using a concurrent `DispatchQueue`.

### E9 — Hazard identification
Map each scenario to its hazard.

## Stretch (not graded)
1. Add a TTL to E4's reservations: a seat reserved more than 5 minutes ago becomes free again. Where does the expiry check go, and what does that do to `reserve`'s atomicity?
2. Turn E5 into a **sliding window** limiter. What extra state do you need, and what's the memory cost per client?
3. Give E7's `decrement` a jittered backoff between attempts. Why jitter and not a fixed delay?
4. Rewrite E8 with an `actor`. Which call sites had to change, and what did you gain?
5. Construct a deadlock with two `NSLock`s and two queues, then fix it with lock ordering. Keep the broken version — being able to *cause* one is how you learn to see one.
