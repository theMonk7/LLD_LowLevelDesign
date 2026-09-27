# Module 13 — Hard Problems (5 solved + 2 design-only + 4 solo)

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** problems big enough that scoping *is* the skill. At this size you will not finish everything — so the graded behaviour becomes: pick the core, build it well, and name what you deferred.

Code: [`Solutions/Solved.swift`](Solutions/Solved.swift). Same rule: design for 30 minutes before reading.

---

# SOLVED 1 — Elevator System ⭐

### Requirements
Multiple cars in a building. External requests (floor + direction) and internal requests (floor). A dispatcher picks a car; cars move floor by floor, opening doors at their stops.

### Clarifying questions
- How many cars, how many floors?
- External requests carry a direction; internal ones don't — do I model both?
- Which scheduling algorithm — nearest car, SCAN/LOOK, or destination dispatch? *(This is the variation axis.)*
- Are express/service elevators in scope? Capacity limits? *(Defer.)*

### The decomposition that makes this tractable
Three responsibilities, three types — merging any two is what makes people fail this problem:

| Type | Owns |
|---|---|
| `Elevator` | one car's position, direction, doors, and its own stop set |
| `ElevatorDispatchPolicy` | *which* car serves a request |
| `ElevatorBank` | the fleet, and routing requests through the policy |

```swift
public protocol ElevatorDispatchPolicy {
    func select(_ elevators: [Elevator], for request: ElevatorRequest) -> Elevator?
}
```
The interviewer's follow-up is always *"what if we changed the scheduling algorithm?"* — and the answer is a new conformer. `NearestCarPolicy` scores by a tier (idle → moving toward → moving away) and then distance, which is the minimum sensible policy.

### The state machine
Direction is recomputed after every stop change:
```swift
case .up:   direction = above ? .up : (below ? .down : .idle)
```
A car heading up keeps heading up while anything is above it — that's the LOOK behaviour in miniature, and it's why an elevator doesn't oscillate.

`step()` is one simulation tick. Making time discrete and injected (rather than using timers) is what makes the whole thing testable — the same move as injecting `Clock`.

### What to defer out loud
Capacity, door obstruction, fire-service mode, maintenance, per-floor call buttons with lamps, energy optimisation.

### Extension questions
1. Implement LOOK properly (solo problem 4).
2. Add capacity: a full car must skip further pickups but still make its drop-offs. Which type changes?
3. Destination dispatch (you enter your floor in the lobby). What information moves earlier, and why is it better?
4. Two people press the same call button. (Deduplication — the `Set` of stops already handles it. Note that.)

---

# SOLVED 2 — Chess

### Requirements
8×8 board, standard setup, legal moves for all six piece types, turn enforcement, check detection. *(Castling, en passant and promotion deliberately out of scope — say so, they're 30% of the code for 5% of the signal.)*

### The design insight: pseudo-legal, then filter
```swift
guard isPseudoLegal(piece, from: from, to: to) else { throw .illegalMove }
// simulate
board[to] = piece; board[from] = nil
if isInCheck(piece.color) { /* undo */ throw .wouldLeaveKingInCheck }
```
Two layers: *can this piece move that way?* and *does the move leave my own king attacked?* Trying to answer both in one function is how chess implementations become unreadable. The simulate-and-undo trick is the standard solution and it reuses `isInCheck` rather than duplicating attack logic.

`isInCheck` is itself defined in terms of `isPseudoLegal` — one rule set, used three ways. That's the DRY win that makes the whole thing small.

### Representation choices
- `[Square: Piece]` rather than `[[Piece?]]`: sparse, and iteration visits only occupied squares (useful for `isInCheck`). An 8×8 array is faster and equally valid — be ready to compare.
- `Square` is a `Hashable` value type with an algebraic initialiser (`Square("e4")`), which makes tests and demos readable.
- Movement is expressed as deltas plus `isPathClear`, so rook/bishop/queen share the sliding logic instead of repeating it.

### Why not a `Piece` protocol with one class per piece type?
It's the obvious OOP answer, and it's defensible — `Pawn: Piece` overriding `canMove`. But pawn rules need the board (captures, double-step, blocked squares), so each piece class ends up taking the board anyway, and you've gained six files. With an `enum PieceKind` and one `switch`, the rules sit side by side where they can be compared. **The set of piece kinds is closed** (Module 08 §5) — chess has had six for 500 years. Say that; it's the whole judgment call.

### Extension questions
1. Checkmate vs stalemate: how do you detect "no legal moves"? (Generate all moves, filter by the check rule — you already have both halves.)
2. Castling needs king/rook "has moved" history. Where does that live, and what does it do to `Piece` as a value type?
3. Move history and undo. (Command/Memento — Module 07.)
4. A chess *clock*. Which type owns it, and is it part of the game or a decorator around it?

---

# SOLVED 3 — BookMyShow ⭐

### Requirements
Shows with seat maps and seat classes. Users select seats, pay, get tickets. Seats must not be double-booked; a held seat is released if payment doesn't complete.

### The design insight: hold → pay → confirm, with a TTL
```swift
public enum SeatStatus: Equatable { case free, held(until: Double, by: String), booked(by: String) }
```
Three states, and the held state carries **who** and **until when**. Two-state (free/booked) designs fail the moment payment takes 20 seconds.

```swift
public func status(of seatID: String, now: Double) -> SeatStatus? {
    if case .held(let until, _) = status, until <= now { return .free }   // lazily expired
    return status
}
```
**Lazy expiry** — the hold is checked against the clock at read time, so no background sweeper is required for correctness. Say this: it's a cheap, robust technique, and a sweeper then becomes an optimisation for freeing memory rather than a correctness requirement.

Holding is **all-or-nothing** across the requested seats: validate every seat first, then mutate. Booking 3 of 4 seats and failing is worse than failing cleanly.

```swift
try show.hold(seatIDs, by: user, now: now)
guard charge(amount) else { show.release(...); throw .paymentFailed }
try show.confirm(seatIDs, by: user, now: now)
```
The payment happens **between** hold and confirm, never inside the critical section — the same structure as Module 09 E4, which is where the concurrency version lives.

### Edge cases handled
Hold expired before confirm · someone else's hold · unknown seat · payment failure releasing exactly the seats that were held (and no others).

### Extension questions
1. Two users hold the same seat concurrently. (Module 09 — `hold` is check-then-act.)
2. Seat *recommendations* (best N adjacent seats). New responsibility — which type, and why not `Show`?
3. Dynamic pricing by demand. Where does the multiplier get snapshotted?
4. Cancellation with a refund window. What does `SeatStatus` become?

---

# SOLVED 4 — Food Delivery (order lifecycle)

### Requirements
Orders move through a fixed lifecycle, restaurants accept or reject, partners are assigned, customers can cancel within a window.

### The design insight: a transition table
```swift
private static let allowed: [String: Set<String>] = [
    "placed": ["accepted", "rejected", "cancelled"],
    "accepted": ["preparing", "cancelled"],
    "preparing": ["readyForPickup"],
    ...
]
```
A declarative table beats scattered `if state == .placed` checks: the whole lifecycle is readable in one place, and an illegal transition is impossible by construction. For a richer machine you'd move to the State pattern (Module 07 §2); for a linear lifecycle with a few branches, the table is the KISS answer.

`history` gives a free audit trail, which is the first thing operations will ask for.

### Price snapshotting
```swift
public struct OrderItem: Equatable {
    public let unitPrice: Decimal        // snapshotted at order time
}
```
The menu price can change tomorrow; the order must not. This is the implied-entity lesson from Module 10 §4 made concrete, and it's the detail that separates a designed model from a transcribed one.

### Extension questions
1. Partial refunds for missing items. What does that do to `OrderItem`?
2. Live tracking — does `FoodOrder` hold the partner's location? (No. Why not?)
3. Multi-restaurant carts. Which boundary breaks first?
4. Restaurant rejects after the customer's free-cancellation window. Who pays? (A product question — but the model must be able to express the answer.)

---

# SOLVED 5 — Inventory with Reservations

### Requirements
Stock must not be oversold. An order reserves stock, then commits on payment or releases on failure.

### The design insight: available = onHand − reserved
```swift
public func available(_ sku: String) -> Int { l.onHand - l.reserved }
```
Two counters, not one. Decrementing `onHand` at reservation time makes a cancelled order look like a sale; decrementing only at payment time oversells during checkout. Splitting them is the whole design.

```swift
public func reserve(_ request: [String: Int], reservationID: String) throws {
    if reservations[reservationID] != nil { return }        // idempotent
    for (sku, qty) in request { guard available(sku) >= qty else { throw .insufficientStock } }
    for (sku, qty) in request { lines[sku]?.reserved += qty }
}
```
**Idempotent by reservation id** (a retry is a no-op) and **all-or-nothing across SKUs** (validate every line before mutating any). Both are Module 09 lessons applied to a synchronous design.

### Extension questions
1. Reservations need a TTL. Lazy expiry or a sweeper? (Compare with BookMyShow.)
2. Multiple warehouses. Does `available` still make sense, and what's the new key?
3. Backorders. New state, or a new entity?
4. 5,000 concurrent checkouts on one hot SKU. Optimistic or pessimistic? (Module 09 §5 — and here pessimistic wins.)

---

# DESIGN-ONLY 6 — Cab Booking (Uber)

Fully specified as the **Module 12 project**. The design skeleton:

- **Entities:** `Rider`, `Driver`, `Ride`, `Location`, `Fare`, `Rating`. Implied: `Assignment`, `SurgeSnapshot`.
- **State machines:** driver (offline → available → offered → onTrip) and ride (requested → assigned → started → completed/cancelled). Two machines, not one.
- **Variation axes:** matching strategy (nearest, highest-rated, ETA-based), pricing (base/surge/pool), cancellation policy.
- **The three graded details:** surge snapshotted at *request* time; a driver can hold only one active ride (check-then-act); cancellation compensations differ by who cancels and when.
- **Scale note:** nearest-driver search is a geospatial index question (geohash/quadtree) — that's HLD; in LLD you put it behind `DriverIndex` and say so.

# DESIGN-ONLY 7 — Distributed Job Scheduler

- **Entities:** `Job`, `JobRun`, `Schedule` (cron/interval), `Worker`, `Lease`.
- **Core problem:** exactly-once-ish execution across N workers. The LLD answer is **leases**: a worker claims a job by writing a lease with an expiry, renews it while running, and another worker may claim it only after the lease expires. Combined with **idempotent job bodies**, that gives at-least-once execution with safe retries.
- **Patterns:** Strategy (retry/backoff policy), Command (a job run is a reified request), Observer (run lifecycle events), Chain of Responsibility (middleware: auth → dedupe → metrics).
- **The questions you must answer:** what if a worker dies mid-run (lease expiry), what if the same job is scheduled twice (dedupe key), what if a run takes longer than its interval (skip, queue, or overlap — a policy), and how do you stop a poison job (dead-letter after N attempts — solo problem 1).

---

# Cross-problem lessons

| Lesson | Where |
|---|---|
| Split *policy* from *mechanism* | elevator dispatch vs car movement |
| Two layers beat one clever function | chess pseudo-legal, then check filter |
| Three-state resources, never two | seat free/held/booked, stock onHand/reserved |
| Lazy expiry beats a required sweeper | seat holds |
| Declarative transition tables | food order lifecycle |
| Snapshot anything that history depends on | order item price, surge multiplier |
| All-or-nothing across a multi-item operation | seat holds, inventory reservations |
| Idempotency keys make retries safe | inventory reservations |
| Say what you're deferring | every problem in this module |

---

## ✅ Checkpoint
1. Name the three types in the elevator design and the one responsibility each owns.
2. Explain pseudo-legal-then-filter and why it avoids duplicating attack logic.
3. Why does a seat need three states, and what does lazy expiry buy you?
4. Why are `onHand` and `reserved` separate counters?
5. For any two problems here, name something you would explicitly defer and how you'd phrase it.

Then: `EXERCISES.md` (4 solo problems) → `swift test --filter M13` → `SOLUTIONS.md` → `PROJECT.md`.
