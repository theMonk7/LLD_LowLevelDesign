# Module 15 — Model Answers & Grading Notes

For each mock: what a strong answer contains, what the interventions are really probing, and the traps.

---

## Mock 1 — Vending Machine
**Strong answer contains:** three scope lists inside six minutes · `Drink`/`Coin` as value types, machine as entity · guard ordering stated as a product decision · change computed on a *copy* and committed only after every rule passes.

**Minute 12 ("can't make exact change") probes failure atomicity.** The answer: refuse the sale, leave the money inserted, touch nothing. The trap is absorbing the coins into the bank first and discovering the problem afterwards — the customer's money is gone.

**Minute 25 (happy-hour pricing)** probes OCP. Strong: a `PricingStrategy` protocol, one new file, injected clock. Weak: an `if hour >= 16` inside `select`.

**Minute 35 (two slots)** probes whether you volunteer concurrency vocabulary. Say: *"`select` is check-then-act — stock is read, then decremented. I'd put the machine's state behind an actor so the whole selection is atomic."*

**Common failure:** starting to code at minute 3 and never writing the scope lists. Everything downstream is then guesswork.

---

## Mock 2 — Parking Lot
**Strong answer contains:** `Ticket` named as an implied entity holding entry time · composition/aggregation distinguished on the diagram · pricing behind a protocol · rounding rule surfaced as a question.

**Minute 10 (motorcycle in a truck spot)** is a scoping question disguised as a rule question. Strong: *"A vehicle fits its own size or larger, and I allocate best-fit so large spots stay free for vehicles that need them."*

**Minute 20 (EV spots)** probes whether your model separates *spot capability* from *pricing*. Strong: a new `SpotFeature`/`SpotType` plus a pricing strategy that charges for charging — and noticing they're two different axes. Weak: an `isEV: Bool` on `ParkingSpot` and an `if` in the fee method.

**Minute 30 (10,000 spots, real-time board)** probes complexity awareness. Strong: *"My allocation is O(n); I'd keep a free-list per spot type and a count per type, so both allocation and the display are O(1)."*

**Minute 38 (testing the fee)** — the expected answer is "inject the clock and the pricing strategy; the fee calculation is then a pure function of two timestamps and a type."

---

## Mock 3 — Elevator
**Strong answer contains:** three types (car, policy, bank) with one responsibility each · direction as a derived property of the stop set · discrete `step()` rather than timers.

**Minute 8 (inside vs outside request)** probes modelling care. An inside request is a destination with no direction; an outside request carries a direction that a good policy uses. Modelling both as "a floor" loses information the scheduler needs.

**Minute 20 (which car)** — if you haven't already introduced a policy protocol, this is where you do it. Strong answers score idle cars first, then cars already moving toward the request, then distance.

**Minute 32 (different algorithm)** is the payoff question. One new conformer, zero edits. If you're editing `ElevatorBank`, the abstraction was in the wrong place.

**Minute 45 (capacity)** probes whether new state breaks old behaviour: a full car must stop accepting *pickups* but must still serve its *drop-offs*. That distinction is the answer.

**Minute 55 (shared state)** — the stop set. Two requests mutating it concurrently is the race; an actor per car is the fix.

---

## Mock 4 — Splitwise
**Minute 18 is the whole interview.** "Someone edits last month's expense" has a clean answer only if balances are **derived from an append-only expense log**. If you stored a balance per user, you now need reconciliation logic, and you'll spend the rest of the interview digging out. Say early: *"I won't store balances; they're a fold over the expenses."*

**Minute 8 (split types)** — enum with associated values, because each case needs different data and the set is closed. Validation (exact amounts sum to the total, percentages to 100) throws before the expense exists.

**Minute 28 (minimise payments)** — greedy largest-creditor/largest-debtor, plus the honest note that the exact minimum is NP-hard and greedy is what everyone ships.

**Minute 38 (two currencies)** probes whether you ask *when* conversion happens. Converting at settlement time versus expense time gives different answers and different arguments at dinner. Ask; don't assume.

---

## Mock 5 — Image Loading (iOS)
**Minute 10 (sixty cells)** is the differentiator. Strong: *"I keep a dictionary of in-flight `Task`s keyed by URL; the task is stored before the first `await`, so the other 59 callers find it and await the same result — one network call."* If you say "I'd cache it", you've answered a different question: the cache is empty on the first request, which is exactly when the stampede happens.

**Minute 22 (user scrolls past)** — cancellation. The good answer is reference-counted: cancel the underlying fetch only when *no* caller is still waiting. Cancelling on the first departure breaks the other 59.

**Minute 33 (memory warning)** — cost-based limit and eviction; `NSCache` gives you automatic eviction under pressure but unpredictable policy; an LRU gives you predictability. Name the trade.

**Minute 42 (testing)** — three protocols (memory, disk, remote) and a fake fetcher; coalescing tested with a task group; nothing touches the network.

**Minute 52 (two sizes)** — the cache key must include the transformation, while the *download* is coalesced on the URL alone. Getting both right in one sentence is a strong finish.

---

## Mock 6 — Refactor
**What's really scored:** whether you name smells with principles (SRP, OCP, DIP) rather than preferences, and whether you protect behaviour before changing it.

**Minute 15 (what first)** — prioritise by risk: `try!`/`as!` crash paths and untestability before naming and structure. A candidate who starts by renaming variables has misjudged the room.

**Minute 25 (do it)** — say *"let me write a characterisation test against the current behaviour first"*. Almost nobody does; it's the clearest signal of professional refactoring.

**Minute 38 (new format)** — zero edits, one new file. If the switch merely moved into a factory, say so honestly and explain what you'd do with more time.

---

## Mock 7 — BookMyShow
**Minute 8 (hold duration)** — three states with a TTL. *"Free, held-until-with-owner, booked."* Two states can't express "someone is paying".

**Minute 20 (app crashes)** — lazy expiry. *"I check the hold against the clock when the seat is read, so an abandoned hold is free the moment it expires; no sweeper is needed for correctness."*

**Minute 30 (same instant)** — reserve synchronously inside an actor, charge outside, confirm or release. This is Module 09 E4 verbatim, and it should be automatic by now.

**Minute 42 (payment succeeded, confirm failed)** — the hardest question in the set. Answer: the confirm must be **idempotent and retriable**, the payment carries an idempotency key, and there must be a reconciliation path (an outbox or a job that finds paid-but-unconfirmed bookings). Saying "I'd need a reconciliation job because the two systems can't commit atomically" is a senior answer.

**Minute 52 (best adjacent seats)** — a new `SeatRecommender` type, not a method on `Show`. `Show` owns seat state; recommendation is a separate responsibility (Pure Fabrication).

---

## Mock 8 — Architecture (iOS)
**Minute 10 ("why not VIPER")** — do not attack it. *"VIPER buys hard boundaries at five files per screen. With three teams I want boundaries at the **module** level rather than per screen, so I'd use MVVM plus a thin domain layer and separate Swift packages per feature."*

**Minute 20 (networking)** — one `APIClient` behind protocols, repositories owned by the domain, use cases for anything with rules, view models consuming use cases. The dependency rule stated explicitly: **the domain imports nothing**.

**Minute 30 (three teams)** — feature modules as separate packages with a shared `Core`/`DesignSystem`; contracts are protocols in a shared module so teams integrate against types that exist on day one. This is the question most candidates answer weakly.

**Minute 40 (two services, partial state)** — one state enum that can express partial success (`.partial(profile:ordersError:)`), not three booleans. This connects straight back to Module 12's "make illegal states unrepresentable".

**Minute 50 (what do you regret)** — an answer showing real self-criticism scores highest: *"I'd probably regret splitting into packages too early — module boundaries chosen in month one are usually wrong, and merging them later is harder than splitting."* Candidates who say "nothing" score zero here.

---

## Scoring calibration

| Total | Meaning |
|---|---|
| 45–50 | Senior hire signal |
| 38–44 | Solid hire; some depth gaps |
| 30–37 | Borderline; usually communication or scoping, not knowledge |
| < 30 | Re-run the framework drills (Module 10) before more mocks |

If two consecutive mocks score below 35 for the **same** criterion, stop mocking and drill that one thing. More mocks do not fix a specific missing habit.
