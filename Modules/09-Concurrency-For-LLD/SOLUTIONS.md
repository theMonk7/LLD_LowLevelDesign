# Module 09 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 / E2 — the same guarantee, two mechanisms
```swift
public actor SafeCounter { private var count = 0; public func increment() { count += 1 } }

public final class LockedCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()
    public func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
}
```
`count += 1` is read-modify-write — three operations. The actor serialises access to its own state; the lock serialises access to the object. Both turn three steps into one indivisible one.

`defer { lock.unlock() }` isn't style. Any early `return` or `throw` between `lock()` and a manual `unlock()` leaves the lock held forever, and the next caller hangs. `defer` makes that impossible.

`@unchecked Sendable` is a promise to the compiler that you've handled safety yourself. It's honest here because there's a real lock. Using it to silence a Swift 6 warning without one is how races get shipped.

## E3 — check-then-act, fixed
```swift
public func book(_ seat: String) -> Bool { booked.insert(seat).inserted }
```
Two wins in one line. `Set.insert` **is** the atomic test-and-set — it returns whether the insert happened — so there's no window between checking and acting. And because the method contains no `await`, the actor runs it to completion before admitting another caller.

The naive version fails the 500-task test:
```swift
guard !booked.contains(seat) else { return false }   // 500 tasks can pass here…
booked.insert(seat)                                   // …before any of them reach here
```
Except, inside an actor with no suspension point, even that version is safe. **That's worth understanding precisely:** the danger isn't the two statements, it's the two statements *with a suspension between them* or *outside an actor*. Explain that distinction in an interview and you're clearly above the recital level.

## E4 — reserve / pay / confirm ⭐
```swift
public func reserve(_ seat: String) -> Bool {      // synchronous ⇒ atomic
    guard states[seat] == .free else { return false }
    states[seat] = .reserved
    return true
}

public func book(_ seat: String, amount: Decimal) async throws {
    guard await reservation.reserve(seat) else { throw BookingError.seatTaken }
    let paid = await charge(amount)                 // slow work OUTSIDE the critical section
    if paid { _ = await reservation.confirm(seat) }
    else { await reservation.release(seat); throw BookingError.paymentFailed }
}
```
Three properties make this correct:
1. **`reserve` contains no `await`.** A suspension inside it would release the actor and let a second caller pass the same guard — the reentrancy bug this exercise exists to teach.
2. **The payment is outside the actor.** Holding a lock across a network call serialises every booking in the system behind one slow gateway. This is the single most common concurrency design error in booking systems.
3. **Failure compensates.** `release` on a failed payment is what the sequence diagram in Module 04 §3 was pointing at. Forget it and seats leak permanently.

`release` refuses to free a `.sold` seat — a late-arriving failure callback must not un-sell a ticket. That's the kind of guard that only appears when you've thought about ordering.

What's still missing, and worth saying: a **TTL**. If the client crashes between reserve and confirm, the seat is stuck in `.reserved` forever. Real systems attach an expiry and sweep.

## E5 — rate limiter
```swift
public func allow() -> Bool {
    rollIfNeeded()
    guard used < limit else { return false }
    used += 1
    return true
}
```
Roll, check, consume — one actor method, no suspension, so 2,000 concurrent callers can't overshoot 100. Split `allow()` into `canAllow()` + `consume()` and the test fails immediately.

The **injected clock** is the same DIP move as Module 02 E5: `now: @Sendable () -> Double`. The tests advance a fake clock instead of sleeping, so the window-rollover test runs in microseconds and never flakes. A test that calls `Task.sleep` to test a rate limiter is a test that fails on CI at 3 a.m.

Fixed window has a known flaw worth naming: a client can send `limit` requests at the end of one window and `limit` more at the start of the next — 2× the limit in a short span. Sliding window or token bucket fixes it, at the cost of more state per client.

## E6 — idempotency + actor reentrancy ⭐ the trap
```swift
if let done = processed[idempotencyKey] { return done }
if let running = inFlight[idempotencyKey] { return await running.value }

let charge = self.charge
let task = Task { await charge(amount) }
inFlight[idempotencyKey] = task
let txn = await task.value
processed[idempotencyKey] = txn
inFlight[idempotencyKey] = nil
```
The naive version — check `processed`, `await charge`, store — is correct sequentially and **wrong under concurrency**. At the `await`, the actor suspends; the other 199 callers enter, all find `processed` empty, and all charge. Idempotency implemented with a reentrancy bug is worse than no idempotency, because it looks correct in every test that doesn't run concurrently.

The fix stores the **in-flight `Task`** under the key *before* suspending. Later callers find it and await the same result — one charge, 200 identical answers. This "task coalescing" idiom is also how you deduplicate concurrent image downloads or token refreshes in an iOS app, which makes it directly useful in Module 14.

`let charge = self.charge` before the `Task` avoids capturing the actor in the closure.

## E7 — optimistic locking
```swift
guard let current = items[sku], current.version == expectedVersion else {
    conflictCount += 1
    return false
}
items[sku] = VersionedItem(quantity: newQuantity, version: current.version + 1)
```
Compare-and-swap in one atomic step. A writer holding a stale snapshot loses and retries — no lost update, no lock held across the read-compute-write cycle.

`decrement` is a retry loop, capped, that distinguishes `.outOfStock` (a real business condition, don't retry) from `.conflict` (contention, do retry). Conflating them is how you return "out of stock" to a user when you were merely unlucky.

When to prefer it: conflicts rare (most catalogue items). When not: a hot row, like the last seat of a sold-out show, where every attempt collides and retries make it worse. Then pessimistic locking — or a queue — wins.

## E8 — reader-writer
```swift
public func get(_ key: String) -> Int? { queue.sync { storage[key] } }
public func set(_ key: String, _ value: Int) { queue.sync(flags: .barrier) { storage[key] = value } }
```
Concurrent reads run in parallel; a barrier write waits for in-flight reads and excludes everything until it finishes. Right for read-heavy caches.

The classic bug is `queue.async(flags: .barrier)` for the write plus a `sync` read — a read issued immediately after a write may run *before* it. Here `set` is `sync` so a write is visible to the next read, which is what the tests require. Async barriers are fine when you don't need read-after-write consistency; know which you're choosing.

Never call `queue.sync` from inside a block already running on that queue — instant deadlock.

## E9 — hazards
| Scenario | Hazard |
|---|---|
| two threads both run `count += 1` | race (lost update on read-modify-write) |
| `guard !booked.contains` then `insert` | check-then-act |
| A holds seats wants payments, B the reverse | deadlock (fix: lock ordering) |
| `await` mid-actor-method | actor reentrancy |
| stale snapshot overwrites a newer value | lost update |
| client retries a charge after a timeout | non-idempotent retry |

## Self-check
| If you… | Re-read |
|---|---|
| put an `await` inside `reserve` | §2 actor reentrancy |
| held the actor across the payment | §2, §4 |
| split allow() into check + consume | §1 check-then-act |
| wrote the naive `processed[key]` idempotency check | §2 reentrancy + E6 |
| retried on `.outOfStock` | §5 optimistic locking |
| forgot `defer { unlock() }` | §2 |
