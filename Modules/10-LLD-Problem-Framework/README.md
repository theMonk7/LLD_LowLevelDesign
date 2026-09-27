# Module 10 — The LLD Problem-Solving Framework

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** a repeatable procedure that turns a vague prompt into a defensible design in 45 minutes — every time, under pressure, without staring at a blank board.

Module 00 introduced **DESIGN**. This module is the deep version: what exactly you write down at each step, the full question bank, the noun/verb technique, time-boxing, and how to recover when you're stuck.

---

## 1. The framework, expanded

```
D — Discover requirements          5–8 min   → 3 lists on the board
E — Entities, actors, use cases    5 min     → noun/verb table
S — Structure: class diagram       10 min    → boxes + relationships
I — Interfaces & interactions      5 min     → APIs + one sequence
G — Gaps: patterns, edge cases     5 min     → variation axes + failure list
N — Nail it down: code             rest      → core path first
```

---

## 2. D — Discover requirements

### What you write on the board

```
IN SCOPE                    OUT OF SCOPE              NON-FUNCTIONAL
1. park a vehicle           - payments/refunds        - concurrent access
2. unpark + compute fee     - number plate OCR        - 10k spots, 1k events/min
3. multiple spot sizes      - reservations            - pricing must be swappable
4. multiple floors          - persistence             - extensible vehicle types
5. find available spot      - UI
```

Three lists. Out-of-scope is not a cop-out — it's the single clearest signal that you scope deliberately. Say: *"I'll assume these are out of scope; tell me if you'd rather I include one."*

### Requirement smells to catch immediately
| Prompt says | You must ask |
|---|---|
| "users" | one type of user, or roles with different permissions? |
| "payment" | do I model money movement, or assume a gateway returns success? |
| "real time" | how real — sub-second, or "eventually"? |
| "scalable" | LLD-scalable (extensible) or HLD-scalable (traffic)? |
| "like Uber" | which *slice* of Uber — matching, pricing, tracking, ratings? |
| no numbers | 10 items or 10 million? It changes the data structure. |

### Turning vague into concrete
> "Design a parking lot."

becomes

> "A multi-floor lot with motorcycle/car/truck spots. Vehicles enter, get a ticket, park in a compatible free spot, and pay on exit based on duration and vehicle type. Admins add floors and change pricing. In-memory, single process, concurrent entry gates. No payments integration, no plate recognition."

That paragraph *is* the first deliverable. Write it, read it back, get agreement. Everything after it is cheap; everything before it is wasted if you skip it.

---

## 3. The 40-question bank

Pick 6–10. Never ask all of them.

**Scope and boundaries (1–8)**
1. Is this one instance or multi-tenant?
2. Is persistence in scope, or is in-memory state fine?
3. Do I need authentication or authorisation?
4. Is there a UI, or is a clean API enough?
5. Should I design for a library/SDK, or an app?
6. Is this a single process or distributed? (If distributed, it's partly HLD.)
7. What's explicitly *not* required?
8. How much time do we have — should I optimise for breadth or depth?

**Actors and use cases (9–15)**
9. Who are the actors, and what can each do?
10. Are there admin/operator flows?
11. What's the primary happy path, end to end?
12. Which operations are read-only vs state-changing?
13. Are there scheduled/background operations?
14. Are there external systems I call, or that call me?
15. Which actions must be audited?

**Domain rules (16–24)**
16. What's the lifecycle of the main entity — created → … → terminal?
17. Which transitions are illegal?
18. Which rules are fixed vs admin-configurable?
19. Are there limits/quotas (max N per user, per day)?
20. How is money represented, and what rounding applies?
21. Are there time-based rules (peak hours, expiry, cutoffs)?
22. What does "cancel" mean — and is it reversible?
23. Are there priorities or tie-breaking rules?
24. What must be immutable once created? (A price snapshot, an order line.)

**Variation and extensibility (25–30)** — the highest-value block
25. **What's likely to change in the next 6 months?**
26. Are there multiple algorithms for the core computation?
27. Will third parties add types/plugins?
28. Which sets are closed (fixed enum) and which are open (protocol)?
29. Should behaviour be configurable at runtime or compile time?
30. Are there multiple "families" that must stay consistent?

**Scale and performance (31–35)**
31. Rough numbers for the main collections?
32. Read-heavy or write-heavy?
33. Any latency requirement on the hot path?
34. Is memory constrained?
35. Does anything need indexing beyond a linear scan?

**Concurrency and failure (36–40)**
36. Single-threaded or concurrent?
37. What happens if two actors do the same thing simultaneously?
38. What's idempotent and what isn't?
39. What happens on partial failure — is there a compensating action?
40. What should happen when a resource is exhausted?

**If you only ask three:** #9 (actors), #25 (what changes), #37 (concurrency).

---

## 4. E — Entities via noun/verb extraction

Take the agreed paragraph. Mechanically:

| Noun | Keep? | Why |
|---|---|---|
| lot | ✅ | root aggregate |
| floor | ✅ | owns spots |
| spot | ✅ | has state |
| vehicle | ✅ | polymorphic |
| ticket | ✅ | issued on entry |
| duration | ❌ | derived from timestamps |
| admin | ✅ actor | not an entity in the model |
| system | ❌ | that's the program |
| pricing | ✅ | a *strategy*, not data |

| Verb | Owner (Information Expert) |
|---|---|
| park | `ParkingLot` |
| find free spot | `Floor` |
| occupy / vacate | `ParkingSpot` |
| compute fee | `PricingStrategy` |
| issue ticket | `ParkingLot` (Creator) |

### Finding the implied entities
The high-value entities are never in the prompt. They appear when you ask *"what records this relationship over time?"*

| Prompt has | Implied entity |
|---|---|
| "user borrows a book" | `Loan` (who, what, when, due) |
| "driver delivers order" | `Assignment`/`Trip` |
| "user pays" | `Payment` (status, method, retries) |
| "user books seats" | `Reservation` (with TTL), `Ticket` |
| "cart becomes an order" | `OrderLine` with a **price snapshot** |
| "user rates restaurant" | `Rating` (one per order, not per user) |

Naming two or three implied entities unprompted is one of the strongest signals available in an LLD round.

---

## 5. S — Structure

For each entity, write ≤4 fields and ≤4 methods. Then, for each, ask:

1. **Identity or value?** → class or struct (Module 01 §2).
2. **What's its single reason to change?** → SRP.
3. **What invariant does it guarantee?** → encapsulation.
4. **Who owns it?** → composition vs aggregation (Module 04 §2).
5. **What's its multiplicity?** → `0..1` vs `1..*`.

Layer the board:
```
┌ Entities ──────────────┐   ParkingLot  Floor  Spot  Ticket  Vehicle
├ Protocols (variation) ─┤   PricingStrategy  SpotAllocator  VehicleType
└ Services / fabrications┘   TicketIssuer  OccupancyReporter
```

---

## 6. I — Interfaces and interactions

Write the public API of the root type. It should read like the use-case list:

```swift
final class ParkingLot {
    func park(_ vehicle: any Vehicle) throws -> Ticket
    func unpark(_ ticket: Ticket, at: Date) throws -> Decimal
    func availability(for type: VehicleType) -> Int
}
```

Then walk **one** use case as a sequence (Module 04 §3). You are looking for:
- a call with no method to land on → missing method
- a return value nobody uses → wrong ownership
- a step that needs data the caller doesn't have → wrong boundary

Two minutes here saves ten minutes of rewriting code.

---

## 7. G — Gaps

### Variation axes
For each, complete: *"The ___ varies by ___ → therefore ___."* If a variation axis has exactly one implementation and no stated plan for a second, **leave it concrete** and say so (Module 08 §5).

### Edge-case checklist — run it out loud
| Category | Ask |
|---|---|
| Empty | no spots, no items, no users |
| Full | lot full, quota exhausted, pool exhausted |
| Boundary | exactly at the limit, exactly at expiry, zero duration |
| Duplicate | same ticket twice, double submit, replayed request |
| Invalid | unknown ticket, wrong type, negative amount |
| Concurrent | two actors, same resource (Module 09) |
| Failure | payment fails after reservation — what compensates? |
| Time | clock skew, DST, expiry during processing |
| Money | rounding, currency, refunds |

Naming 5–6 of these unprompted is worth more than another class on the board.

---

## 8. N — Code

Order matters when the clock is running:
1. **Value types and enums** — `Money`, `VehicleType`, `SpotType`. Fast, and they make everything else readable.
2. **Entities with invariants** — `Spot.occupy()`, `Ticket`.
3. **The root service happy path** — `park` / `unpark`.
4. **One variation point** — the pricing protocol plus one implementation.
5. **A `demo()`** that runs the happy path and prints.
6. **Edge cases**, in the order you listed them.
7. **Tests**, if time remains — or state which you'd write.

Rules under time pressure:
- Stub what you can't finish, out loud: *"`PersistenceStore` is a protocol; I'd implement it against SQLite, but I'll keep the in-memory one for now."*
- Don't gold-plate step 1. A 40-line `Money` type when the fee logic doesn't exist yet is a failed round.
- Keep it compiling. A running 70% beats a beautiful 100% that doesn't build.

---

## 9. Time-boxing

**45 minutes (design discussion)**
```
0–6    requirements + scope
6–10   actors, use cases, nouns/verbs
10–22  class diagram
22–27  public API + one sequence
27–32  patterns + edge cases
32–42  code the core (or detailed pseudocode)
42–45  extensions you'd add
```

**90–120 minutes (machine coding)**
```
0–10   requirements, written down
10–20  entities + diagram sketch
20–70  code: values → entities → service → demo
70–95  edge cases + one variation point
95–110 tests
110+   README with assumptions and what you'd do next
```

**Checkpoint discipline:** at the halfway mark, if there's no running code, stop designing and start typing.

---

## 10. Recovering when you're stuck

| Stuck on | Do this |
|---|---|
| Can't find the entities | re-read the requirement and underline nouns; say them out loud |
| Too many classes | ask "what's the smallest thing that runs the happy path?" |
| Don't know which pattern | say what varies; the pattern follows (Module 08 §1) |
| Interviewer looks unconvinced | ask "would you like me to go deeper here, or move on?" |
| Blanked completely | narrate the use case end-to-end in plain English; the design falls out |
| Running out of time | say so, name the remaining pieces and how you'd build them |

Silence is the only unrecoverable state. Narrating a wrong idea is recoverable; narrating nothing is not.

---

## 11. Self-review checklist (run it before you say "done")

- [ ] Can I state each class's single responsibility in one sentence?
- [ ] Can I add a new *kind* of the main varying thing by adding one file?
- [ ] Is every invariant enforced inside a type, not by the caller?
- [ ] Does any class name contain `Manager`, `Helper`, or `Util`?
- [ ] Is there a `switch` over a type tag that will keep growing?
- [ ] Is money a `Decimal`? Are prices snapshotted where they must be?
- [ ] Can I unit-test the core without network, disk or clock?
- [ ] What happens with two concurrent actors on the same resource?
- [ ] Which abstraction would I delete if forced to remove one?
- [ ] Did I name at least one thing I deliberately left out?

---

## ✅ Checkpoint
1. Reproduce the six DESIGN steps with their outputs and time budgets.
2. Give the three questions you'd ask if allowed only three.
3. Extract nouns/verbs from a prompt you haven't seen before and name two implied entities.
4. Recite the edge-case categories from memory.
5. Describe what you do at the halfway checkpoint if nothing compiles.

Then: `EXERCISES.md` → `swift test --filter M10` → `SOLUTIONS.md` → `PROJECT.md`.
