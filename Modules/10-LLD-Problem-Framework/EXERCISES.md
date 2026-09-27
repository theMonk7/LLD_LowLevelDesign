# Module 10 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M10`.

### E1 — Noun triage
For the parking-lot paragraph in §2 of the README, classify each noun: entity, value object, actor, attribute, not-modelled, or strategy. This is step E of DESIGN, made mechanical.
*The two that catch people:* `duration` (derived, not stored) and `pricing` (a rule, not data).

### E2 — Implied entities
Each fragment implies an entity **that the prompt never names**. Finding these is the highest-value 90 seconds in an LLD round.

### E3 — Timed design: drink vending machine ⭐
**Do this properly: set a 60-minute timer and work through D→E→S→I→G→N on paper before writing a line of Swift.**

The requirements paragraph is in the file. Note what it already decided for you — and what it deliberately left out (persistence, cards, UI). That's what your step D should have produced.

The graded behaviour:
- insert / refund (largest coin first)
- select with the four failure modes in a fixed order: unknown → sold out → insufficient funds (with the shortfall) → cannot make change
- **atomicity**: any failure leaves stock, bank and inserted coins exactly as they were
- change is greedy from the largest denomination, using the bank *after* it absorbs the inserted coins
- operator restock, coin loading, and cash collection that takes the bank but not the customer's inserted coins

After you're green, write down: which of the four failure orderings would you have got wrong if the spec hadn't said? That ambiguity is a question you should ask in a real round.

## Stretch (not graded)
1. Greedy change fails for denominations like {1, 3, 4} (amount 6 → greedy 4+1+1, optimal 3+3). Add a coin set where your implementation returns a *suboptimal but valid* answer, and one where greedy fails although change is possible. What algorithm fixes it, and is it worth it for real coin systems?
2. Add a `PricingStrategy` so drinks cost more between 12:00 and 14:00. Which existing type changed?
3. Make the machine thread-safe for two customers at two coin slots (Module 09). Which method is the check-then-act?
4. The operator wants a sales report by drink. Which GRASP principle tells you where that method belongs?
5. Redesign the machine with an explicit State pattern (Module 07 E2). Compare: which version is easier to extend with a "maintenance mode"?
