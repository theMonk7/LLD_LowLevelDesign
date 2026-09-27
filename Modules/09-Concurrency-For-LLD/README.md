# Module 09 — Concurrency for LLD

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** recognise the concurrency question hiding inside every LLD problem, and answer it in Swift without hand-waving.

**Why this module exists:** in almost every LLD problem the interviewer eventually asks *"what happens if two users do this at the same time?"* — two cars taking the last parking spot, two users booking seat A1, two threads hitting a rate limiter, two requests pulling the same connection. Most candidates freeze. This is a cheap way to stand out.

---

## 1. The three failure modes you must be able to name

### Race condition
Two operations interleave and the result depends on timing.

```swift
final class Counter {
    private var count = 0
    func increment() { count += 1 }     // read, add, write — three steps, not one
}
```
Two threads read `5`, both write `6`. One increment is lost. `+=` is **not** atomic.

### Check-then-act (the one that matters in LLD)
The classic booking bug, and the answer to most interview follow-ups:

```swift
func book(_ seat: String) -> Bool {
    guard !bookedSeats.contains(seat) else { return false }   // CHECK
    bookedSeats.insert(seat)                                  // ACT
    return true
}
```
Two threads both pass the check, both insert, both return `true`. One seat, two tickets, one angry customer. **The check and the act must be one atomic operation.**

### Deadlock
Two threads each hold a lock the other wants.
```
Thread A: lock(seats) → wants lock(payments)
Thread B: lock(payments) → wants lock(seats)
```
Fixes: a single lock, a global **lock ordering** (always take `seats` before `payments`), or lock-free design. "I'd impose a consistent lock acquisition order" is the answer they're listening for.

Also worth naming: **livelock** (threads keep retrying and never progress), **starvation** (one thread never gets the lock), and **ABA** in lock-free code.

---

## 2. The Swift toolbox, in the order you should reach for it

### 0. Don't share mutable state
The best concurrency fix is an immutable value type. `struct` copies can't race. Reach for this first.

### 1. `actor` — the default answer in modern Swift
```swift
actor SeatBooking {
    private var booked: Set<String> = []

    func book(_ seat: String) -> Bool {          // the whole method is one atomic unit
        guard !booked.contains(seat) else { return false }
        booked.insert(seat)
        return true
    }
    var bookedCount: Int { booked.count }
}

let ok = await booking.book("A1")                // callers must await
```
The actor serialises access to its own state — check-then-act inside one method is safe by construction. This is what you should say first in a Swift interview.

**The actor trap you must know — reentrancy:**
```swift
actor Booking {
    private var booked: Set<String> = []
    func book(_ seat: String, gateway: Gateway) async -> Bool {
        guard !booked.contains(seat) else { return false }
        _ = await gateway.charge()          // ⚠️ SUSPENSION — other calls run here
        booked.insert(seat)                 // the guard above may now be stale
        return true
    }
}
```
An `await` inside an actor method **releases** the actor. Other calls interleave. Rule: **re-validate after every suspension**, or (better) reserve synchronously first and do the slow work outside:
```swift
func reserve(_ seat: String) -> Bool {      // no await: fully atomic
    guard !booked.contains(seat) else { return false }
    booked.insert(seat)
    return true
}
// then charge outside the actor, and call `release(seat)` on failure
```
That reserve-then-charge-then-confirm-or-release shape is the correct answer for BookMyShow/ticketing problems.

### 2. `NSLock` — when the API must stay synchronous
```swift
final class ThreadSafeCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
```
`defer { unlock() }` is mandatory — an early `return` or `throw` without it deadlocks the process. `@unchecked Sendable` is you telling the compiler "I've handled this manually"; use it honestly.

### 3. Serial `DispatchQueue`
```swift
private let queue = DispatchQueue(label: "com.app.store")
func write(_ v: Int) { queue.async { self.storage = v } }         // fire and forget
func read() -> Int { queue.sync { self.storage } }                 // blocks
```
Never call `queue.sync` from the same queue — instant deadlock. Prefer `actor` in new code.

### 4. Reader-writer (concurrent queue + barrier)
Many concurrent readers, exclusive writers — right when reads vastly outnumber writes (a cache).
```swift
private let q = DispatchQueue(label: "cache", attributes: .concurrent)
func get(_ k: String) -> V? { q.sync { store[k] } }
func set(_ k: String, _ v: V) { q.async(flags: .barrier) { self.store[k] = v } }
```

### 5. Atomics / lock-free
`OSAllocatedUnfairLock`, `Atomic` from Swift Atomics. Mention for counters; don't hand-roll lock-free data structures in an interview.

### Choosing
| Need | Use |
|---|---|
| no shared mutable state | value types — nothing else needed |
| new Swift code, async callers | `actor` |
| must stay synchronous | `NSLock` / `OSAllocatedUnfairLock` |
| legacy / Objective-C interop | serial `DispatchQueue` |
| read-heavy cache | concurrent queue + barrier |
| a single counter | atomics |

---

## 3. `Sendable` and Swift 6 strict concurrency

`Sendable` marks a type safe to cross concurrency domains.
- `struct`/`enum` of `Sendable` members → automatically `Sendable`.
- `final class` with only immutable `let` properties → can be `Sendable`.
- `actor` → always `Sendable`.
- Mutable class → **not** `Sendable`; either make it an actor, or mark `@unchecked Sendable` and protect it yourself.

```swift
struct Ticket: Sendable { let id: String; let seat: String }     // free
final class Cache: @unchecked Sendable { private let lock = NSLock(); ... }
```
Under Swift 6 these are compile errors, not warnings. Saying *"I'd model the ticket as a `Sendable` struct and keep mutable state inside an actor"* lands well.

`@MainActor` is the UI corollary — one actor for all UI state:
```swift
@MainActor final class BookingViewModel { @Published private(set) var seats: [Seat] = [] }
```

---

## 4. Concurrency questions per classic LLD problem

Have the answer ready *before* the interviewer asks.

| Problem | The race | The fix |
|---|---|---|
| **Parking lot** | two cars assigned the last spot | atomic find-and-occupy inside an actor, not `findSpot()` then `occupy()` |
| **Ticket booking** | two users book seat A1 | reserve synchronously with a TTL, charge outside, confirm or release |
| **Elevator** | two requests mutate the stop queue | actor owning the queue; scheduler reads a snapshot |
| **Rate limiter** | concurrent requests overshoot the limit | atomic "test and consume" in one operation |
| **Inventory** | oversell the last unit | atomic decrement with a guard; optimistic locking by version in a DB |
| **Connection pool** | two clients get the same connection | atomic pop from `available` |
| **LRU cache** | eviction during a read | lock around the map + list, or an actor |
| **Splitwise** | concurrent expenses corrupt balances | balances derived from an append-only log, not mutated in place |
| **Logging framework** | interleaved log lines | serial queue; batch writes |
| **ATM** | double withdrawal | atomic check-and-debit; idempotency key on the transaction |

---

## 5. Optimistic vs pessimistic locking

**Pessimistic** — take the lock, then act. Safe, serialises everything, risks deadlock.
```swift
await store.withLock { inventory[sku]! -= 1 }
```

**Optimistic** — read a version, compute, write only if the version is unchanged; retry on conflict.
```swift
struct Item { var qty: Int; var version: Int }

func decrement(sku: String) throws {
    for _ in 0..<3 {
        let snapshot = read(sku)
        guard snapshot.qty > 0 else { throw .outOfStock }
        if compareAndSwap(sku, expectedVersion: snapshot.version,
                          newValue: Item(qty: snapshot.qty - 1, version: snapshot.version + 1)) { return }
    }
    throw .contention
}
```
Optimistic wins when conflicts are rare (most e-commerce). Pessimistic wins for hot contended rows (the last seat in a sold-out show). Naming the tradeoff — *"optimistic with a version column, because collisions on a given SKU are rare"* — is a strong senior signal.

---

## 6. Idempotency — the other half of correctness

The user taps "Pay" twice; the network retries a request; the client reconnects and replays. Without idempotency you double-charge.

```swift
actor PaymentService {
    private var processed: [String: String] = [:]      // idempotencyKey -> transactionID

    func pay(amount: Decimal, idempotencyKey: String) async throws -> String {
        if let existing = processed[idempotencyKey] { return existing }   // replay: same answer
        let txn = try await gateway.charge(amount)
        processed[idempotencyKey] = txn
        return txn
    }
}
```
Say it plainly: *"I'd make the write path idempotent with a client-supplied key, so retries are safe."* It's the answer to half of all "what about failures?" follow-ups.

---

## 7. Where concurrency lives in your design

Keep it **at the boundary of a small number of types**, not sprinkled everywhere:
- Entities and value objects: immutable, `Sendable`, no locking.
- One coordinator per shared resource (an `actor`) owning all mutation.
- Everything else: pure functions over values.

A design where five types each hold their own lock is a deadlock waiting to happen. A design where one actor owns the mutable state is explainable in one sentence.

---

## 8. Pitfalls

| Pitfall | Why | Fix |
|---|---|---|
| Assuming `+=` is atomic | read-modify-write | lock or actor |
| check-then-act split across two calls | interleaving | one atomic operation |
| `await` mid-critical-section in an actor | reentrancy invalidates the guard | re-validate, or don't suspend |
| `queue.sync` on the current serial queue | deadlock | restructure; prefer actor |
| Lock without `defer { unlock() }` | early return leaves it locked | always `defer` |
| Inconsistent lock ordering | deadlock | one global ordering |
| Locking around a network call | serialises everything | lock only the state mutation |
| `@unchecked Sendable` as a warning silencer | hides real races | only with a real lock |
| Reserving with no TTL | crashed clients hold seats forever | expiry + cleanup |
| Retrying non-idempotent writes | duplicates | idempotency key |

---

## 9. Interview script

When asked *"is this thread-safe?"*:
> *"No — `book(_:)` is a check-then-act: two callers can both pass the guard. I'd make `SeatBooking` an actor so the check and the insert are one atomic unit. The subtlety is that if I `await` a payment inside that method, the actor suspends and another booking interleaves, so I'd reserve synchronously with a short TTL, charge outside the actor, then confirm or release. I'd also make the charge idempotent with a client key so a retry can't double-charge."*

That's four points — atomicity, actor reentrancy, reserve/confirm, idempotency — in thirty seconds.

---

## ✅ Checkpoint
1. Explain check-then-act with a seat-booking example and give two fixes.
2. Why does an `await` inside an actor method break an invariant guarded earlier in the same method?
3. When is optimistic locking better than pessimistic, and why?
4. What does `Sendable` mean, and which Swift types get it free?
5. Write the idempotency snippet from memory and say which failure it prevents.

Then: `EXERCISES.md` → `swift test --filter M09` → `SOLUTIONS.md` → `PROJECT.md`.
