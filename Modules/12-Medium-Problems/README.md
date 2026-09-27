# Module 12 — Medium Problems (8 solved + 5 solo)

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** the problems that actually get asked. Parking Lot, ATM and Splitwise are the three most common LLD questions in Indian product interviews; the rest cover the shapes the others are built from.

**Same rule as Module 11:** read the requirements, design for 25 minutes yourself, *then* read the walkthrough. Code: [`Solutions/Solved.swift`](Solutions/Solved.swift).

---

# SOLVED 1 — Parking Lot ⭐ the most-asked LLD question

### Requirements
Multi-level lot, spots of different sizes (motorcycle/car/truck), vehicles enter and get a ticket, park in a compatible spot, pay on exit by duration and vehicle type. Admin can change pricing.

### Clarifying questions
- Can a car use a truck spot? *(Yes — a vehicle fits its own size or larger. State it; it changes allocation.)*
- One pricing scheme or several? *(Several → the variation axis.)*
- Do we handle lost tickets, monthly passes, reservations? *(Out of scope, say so.)*
- Concurrent entry gates? *(Yes in reality — name the race even if you don't implement it.)*

### Entities
`Vehicle12` (value) · `ParkingSpot` (entity — identity and mutable occupancy) · `ParkingTicket` (value, issued on entry) · `ParkingLot` (root) · `ParkingPricing` (strategy).

`Ticket` is the implied entity, and it must capture **entry time** — the fee depends on it, and storing a `duration` instead would be a second source of truth.

### The two decisions that matter

**1. Best-fit allocation.**
```swift
guard let spot = spots.filter({ $0.fits(vehicle) }).min(by: { $0.size < $1.size }) else { throw .full }
```
First-fit would put a motorcycle in a truck bay and leave trucks stranded. Say this out loud: *"I allocate the smallest compatible spot so large spots stay available."* Then note the cost: it's O(n) per park, and at 10,000 spots you'd keep a free-list per size — O(1).

**2. Pricing behind a protocol.**
```swift
public protocol ParkingPricing { func fee(size: VehicleSize, hours: Int) -> Decimal }
```
This is the one abstraction the requirements justify. Note the `max(1, hours)` minimum-charge rule living inside the strategy, not in the lot.

### Edge cases handled
Lot full · unknown ticket · ticket used twice · zero-duration stay (charged one hour) · rounding partial hours **up** (`ceil`) — a product decision you should surface.

### Extension questions
1. Multiple floors with per-floor availability displays. (Add `Floor`; `ParkingLot` aggregates.)
2. Monthly pass holders who don't pay hourly. (Another `ParkingPricing`? Or a `Customer` concept? Argue both.)
3. Two gates admit two cars to the last spot. (Module 09: `park` is check-then-act.)
4. 10,000 spots, availability shown in real time. (Free-list per size + a counter, not a filter.)

---

# SOLVED 2 — ATM

### Requirements
Insert card, enter PIN (3 attempts, then retain), check balance, withdraw cash in available notes, eject card. The ATM has a finite number of each note.

### The design insight: two state machines
The **session** (idle → awaitingPIN → authenticated → cardRetained) and the **cash inventory** are different concerns. Candidates who merge them produce a class where `withdraw` has to re-check authentication three ways.

```swift
public enum State: Equatable { case idle, awaitingPIN, authenticated, cardRetained }
```
Small enough to be an enum, not the State pattern (Module 07 §2, "few states with simple logic → enum"). Say that choice out loud.

### The ordering that matters
```swift
guard let balance = bank.balance(account: card), balance >= amount else { throw .insufficientFunds }
guard let plan = dispensePlan(for: amount) else { throw .cannotDispenseAmount }
guard bank.debit(account: card, amount: amount) else { throw .insufficientFunds }
for (note, count) in plan { cash[note]! -= count }      // commit last
```
Debit **after** confirming the notes can be dispensed, and decrement the cassettes **after** the debit succeeds. Any other order can take a customer's money without giving them cash — the single worst bug in this problem, and the one interviewers probe.

`dispensePlan` is greedy and bounded by what's actually in each cassette, returning `nil` rather than a partial plan — the same shape as the vending machine in Module 10.

### `BankService` is injected
The ATM doesn't own accounts; a bank does. That protocol is what makes the whole thing testable, and it's the DIP answer to "how would you test this?"

### Extension questions
1. Deposits, transfers, mini-statements. Which type grows, and is that still SRP?
2. Two ATMs on one account, withdrawing simultaneously. (Module 09 — the bank needs the atomic check-and-debit, not the ATM.)
3. Receipt printing that must not block the dispense. (Decorator or an event; and note the failure isolation.)
4. Notes run out mid-transaction after a hardware jam. What compensates?

---

# SOLVED 3 — Splitwise ⭐

### Requirements
Users in groups. An expense is paid by one user and split among several — equally, by exact amounts, or by percentage. Show who owes whom and settle up.

### The design insight: never store balances
```swift
public func balances() -> [String: Decimal] {
    var result: [String: Decimal] = [:]
    for e in expenses {
        result[e.paidBy, default: 0] += e.amount
        for s in e.splits { result[s.userID, default: 0] -= s.amount }
    }
    return result.filter { $0.value != 0 }
}
```
Balances are **derived** from an append-only expense log. Store a `balance` field on `User` and you have two sources of truth, which drift the first time an expense is edited or deleted (DRY, Module 03 §1). This is also the answer to "how do you support editing an expense?" — recompute, don't patch.

### Split types
```swift
public enum SplitType: Equatable {
    case equal
    case exact([String: Decimal])
    case percentage([String: Decimal])
}
```
An enum with associated values, not three classes: the set is closed, and each case needs *different data*, which an enum expresses better than a protocol. If users could define their own split rules, this would become a protocol — that's the closed/open test from Module 08 §1.

Validation lives with the split logic and throws before an expense exists: exact amounts must sum to the total, percentages to 100.

### Settlement
Greedy: largest debtor pays largest creditor, repeat. It minimises the *number* of transactions well in practice (the true minimum is NP-hard). Say that — it's a rare chance to name a complexity result without showing off.

### Extension questions
1. Simplify debts across a group (A owes B, B owes C → A owes C). Is that always desirable? (Some users want to see the real edges.)
2. Multiple currencies. Where does conversion happen, and at which rate — transaction time or settlement time?
3. Editing and deleting expenses. (Trivial because balances are derived — say so.)
4. 10,000 expenses in a group; balances on every screen load. (Cache with invalidation, or a materialised running balance — and now you *do* have two sources of truth, deliberately.)

---

# SOLVED 4 — Rate Limiter

### Requirements
Allow N requests per client per window. Reject the rest.

### Why token bucket, not fixed window
Fixed window (Module 09 E5) allows 2× the limit at a boundary: N requests at 0:59 and N more at 1:00. The token bucket refills continuously:

```swift
bucket.tokens = min(capacity, bucket.tokens + (t - bucket.lastRefill) * refillPerSecond)
```
It permits a burst up to `capacity` and then enforces the steady rate — which is usually exactly what you want from an API limiter. Being able to compare fixed window / sliding window / sliding log / token bucket / leaky bucket in one sentence each is the differentiator on this problem.

| Algorithm | Memory | Burst behaviour |
|---|---|---|
| Fixed window | O(1) per client | 2× at boundaries |
| Sliding log | O(requests) | exact, expensive |
| Sliding window counter | O(1) | approximate, good |
| Token bucket | O(1) | allows a controlled burst |
| Leaky bucket | O(1) | smooths output, queues |

### Design details
Per-client buckets in a dictionary, lazily created at full capacity so a first-time client isn't throttled. Time injected, so tests never sleep. `cost` as a parameter supports weighted endpoints.

### Extension questions
1. Millions of clients — the dictionary grows forever. (Eviction/TTL, or a fixed-size sharded store.)
2. Distributed across 10 servers. (This becomes HLD: Redis with Lua for atomic test-and-consume.)
3. Make it thread-safe. (Module 09 — `allow` is test-and-consume.)
4. Different limits per plan tier. (Which pattern? And is it justified?)

---

# SOLVED 5 — Underground System

### Requirements
Customers check in at a station and out at another. Report the average travel time between any two stations.

### The design insight: running aggregate, not a list
```swift
private var totals: [String: (total: Double, count: Int)] = [:]
public func averageTime(from: String, to: String) -> Double? {
    guard let stats = totals["\(from)->\(to)"], stats.count > 0 else { return nil }
    return stats.total / Double(stats.count)
}
```
Storing every trip would be O(n) memory and O(n) per query for no benefit — the average needs only a sum and a count. Recognising when an aggregate suffices is a genuine design skill, not an optimisation.

`inTransit` is the implied entity (an in-progress `Trip`), and `removeValue(forKey:)` is a single atomic "read and remove" — the check-then-act shape done right.

### Extension questions
1. Percentiles, not just the average. (Now you *do* need the samples — or a t-digest/histogram.)
2. Someone never checks out. (A sweeper with a TTL; what do you charge them?)
3. Route-aware averages (via interchange). (The key is no longer a pair of stations.)
4. Concurrent check-ins for one customer. (`alreadyCheckedIn` exists exactly for this.)

---

# SOLVED 6 — Logging Framework

### Requirements
Levels, a minimum level filter, multiple destinations, and formatting.

### Two details that separate a good answer
**1. `@autoclosure` on the message.**
```swift
public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
    guard level >= minimumLevel else { return }
    ...
}
logger.debug("state = \(expensiveDescription())")
```
Without `@autoclosure`, that string interpolation runs even when debug logging is off. With it, the closure is never called. This is the single most valuable thing to know about logging APIs, and Swift's `assert` uses the same trick.

**2. Sinks as the variation axis.**
```swift
public protocol LogSink { func write(_ record: LogRecord) }
```
Console, file, network, memory — the thing that genuinely varies. Levels are a closed enum; formatting is a closure. Three different mechanisms, each matched to whether the set is open or closed (Module 08 §1).

### Extension questions
1. Asynchronous, batched writes so logging never blocks the caller. (Module 09; and what happens to ordering?)
2. Per-sink minimum levels. (Move the filter into a decorator around the sink.)
3. Structured logging with key/value metadata. (What does `LogRecord` become?)
4. Log rotation by size. (Which pattern owns the policy?)

---

# SOLVED 7 — Library Management

### Requirements
Books have multiple physical copies. Members borrow up to 3, for 14 days. Copies can be lost. Search by author or title.

### The design insight: `Book` vs `BookCopy`
Two types, and conflating them is the classic error. `Book` is a *title* (value: ISBN, author); `BookCopy` is a *physical object* with identity and a state. "Is Clean Code available?" is a question about copies, not about the book.

### Illegal states unrepresentable
```swift
public enum CopyState: Equatable { case available, onLoan(memberID: String, due: Double), lost }
```
With `isAvailable: Bool` + `isLost: Bool` you can represent "lost AND on loan". With this enum you cannot — and the borrower and due date are *attached to the state that needs them*, so they can't be stale in the `available` case. This is the strongest form of encapsulation Swift gives you, and it's worth naming.

### Time injected
`borrow(copyID:memberID:now:)` takes the current time as a parameter. Same reason as everywhere else in this course: a domain that calls `Date()` internally cannot be tested.

### Extension questions
1. Reservations: when a copy is returned, the first reserver gets it. Which type changes? (If the answer is "several", the boundaries were wrong.)
2. Different limits per membership tier. (Strategy — and is it justified for two tiers?)
3. Fines for overdue copies. (A new entity, or a computation? Argue.)
4. 1M copies, "is it available" on every search. (Index by ISBN → available count.)

---

# SOLVED 8 — Hotel Management

### Requirements
Rooms of several types, bookings for a date range, availability search, cancellation, occupancy report.

### The design insight: half-open intervals
```swift
public func overlaps(_ other: DateRange) -> Bool { start < other.end && other.start < end }
```
`[1,3)` and `[3,5)` do **not** overlap — one guest checks out the morning the next checks in. Use closed intervals and you lose a night's revenue on every room, every day. This two-line predicate is the whole problem; get it wrong and everything else is wrong.

Availability is then a filter over bookings rather than a stored per-day map:
```swift
!bookings.values.contains { $0.roomID == roomID && $0.range.overlaps(range) }
```
O(bookings) per search. Correct first; the interval tree or per-day bitmap is the scale answer, and you should name it as the follow-up.

### Extension questions
1. Overbooking by 5% deliberately. Where does that policy live?
2. Dynamic pricing by occupancy and season. (Strategy — and now `total` can't be computed at booking time from a flat rate.)
3. 500 rooms, 2-year horizon, sub-100ms search. (Per-room sorted interval list + binary search, or a day bitmap.)
4. Two guests book the last room simultaneously. (Module 09 — reserve/confirm.)

---

# Cross-problem lessons

| Lesson | Where |
|---|---|
| Derive, don't store, what can be recomputed | Splitwise balances, parking duration |
| Commit last: validate everything, then mutate | ATM, vending machine |
| Half-open intervals for date ranges | Hotel |
| Best-fit vs first-fit is a real decision | Parking |
| Running aggregates beat storing samples | Underground |
| `@autoclosure` for work you might not need | Logger |
| Make illegal states unrepresentable | Library `CopyState` |
| Physical object vs catalogue entry are different types | `BookCopy` vs `Book` |
| Inject time, randomness and external services | all eight |

---

## ✅ Checkpoint
1. Why best-fit in the parking lot, and what's the cost at scale?
2. State the correct order of debit, dispense-plan and cassette decrement in the ATM, and the bug from getting it wrong.
3. Why are Splitwise balances never stored?
4. Give the token bucket's advantage over a fixed window in one sentence.
5. Write the half-open overlap predicate from memory and explain the hotel bug it prevents.

Then: `EXERCISES.md` (5 solo problems) → `swift test --filter M12` → `SOLUTIONS.md` → `PROJECT.md`.
