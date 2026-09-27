# Module 12 — Concepts: When the Problem Has Money, Time and People In It

> Read before the README. Medium problems introduce three things small ones didn't: *resources that run out*, *facts that must stay true after the world changes*, and *operations that can half-fail*.

---

## 1. The mental model: real systems are about *resources*, not data

A small problem manipulates data. A medium one manages a **resource**: parking spots, cash in a machine, seats, stock, connections, request budget.

Resources have properties that data doesn't:

- They are **finite** — which means "none left" is a real state with real behaviour.
- They are **contended** — two people may want the same one.
- They **change hands** — claimed, held, released, sometimes lost.
- They have **units and rounding** — half a seat and a third of a rupee don't exist.

> **Once something is a resource, the interesting design questions are about its lifecycle, not its shape.**

So before modelling fields, ask: what are the states of one unit of this resource, who can move it between them, and what happens when there are none?

---

## 2. The three-state realisation

Beginners model a resource with two states: available or not.

Two is almost always wrong, because it can't express *"someone is in the middle of taking it"*. Real acquisition takes time — a payment, a confirmation, a human walking to a car — and during that time the resource is neither freely available nor definitively taken.

> **free → held (by someone, until some time) → taken**

The held state must carry **who** and **until when**. Without the holder you can't tell whether the person confirming is the person who reserved. Without the deadline, a crashed client removes that resource from circulation permanently.

This single realisation is what separates a design that works in a demo from one that works with users. It appears in seat booking, inventory, parking, ride matching, and resource pools — and once you see the shape, all of those become the same problem.

The companion insight: the expiry can be **evaluated when the resource is read** rather than swept by a background job. Then correctness doesn't depend on a timer running; the sweeper becomes an optimisation for reclaiming memory, not a requirement.

---

## 3. Derived versus stored: the decision that defines Splitwise-shaped problems

"Who owes whom" can be answered two ways:

- **Store a balance** per person and adjust it on every event.
- **Store the events** and compute the balance on demand.

The first is faster to read and *structurally fragile*. Every operation must remember to adjust; an edit or a deletion needs a compensating adjustment; a bug leaves a balance that no sequence of events justifies, and no amount of staring at the number tells you where it went wrong.

The second has one source of truth. Editing history is trivially correct because the balance is recomputed. Auditing is free — you can always show *why* a number is what it is.

> **Prefer derived state. Store the events; compute the conclusions.**

Caching the result later is a performance decision you can make with measurements — and when you do, you'll do it knowing you've *deliberately* introduced a second source of truth, with invalidation as its price. That's very different from stumbling into it.

This pattern generalises far beyond expense splitting: account balances, inventory positions, reputation scores, unread counts. Every one of them is a fold over a log, and every one of them becomes painful when someone stores the fold instead.

---

## 4. Snapshotting: some facts must be frozen

Menu prices change. Tax rates change. Discount rules change. Addresses change.

An order placed yesterday must **not** change when the menu does. If the order references the live price, history rewrites itself every time someone edits a catalogue — and the user who paid ₹320 now sees ₹340 on their receipt.

> **When a record must stay true after the world moves on, copy the value in rather than pointing at its source.**

This is the reason order lines exist as entities rather than as references to products. The line *is* the snapshot. Same for the surge multiplier captured at request time, the tax rate captured at invoice time, the terms accepted at signup.

The design question to ask of every relationship: *"if the referenced thing changes tomorrow, should this record change with it?"* Usually yes for names and descriptions; almost always **no** for anything that affects money or obligations.

---

## 5. Multi-step operations and the all-or-nothing rule

A small problem changes one thing. A medium one changes several — decrement stock *and* record a reservation, take the coins *and* dispense change *and* reduce inventory, debit an account *and* release the notes.

If a later step fails after earlier ones succeeded, you have a **half-applied operation**: money taken with nothing dispensed, stock reserved for an order that never existed. These are the bugs that produce angry customers rather than stack traces.

Two disciplines prevent it:

**Validate everything first.** Every rejection happens before any mutation. Then most failures leave the system untouched by construction.

**Compute on a copy; commit at the end.** When the operation touches several pieces of state, work out the complete result first, then apply it in one move. If anything fails during computation, you throw away a copy and nothing real changed.

> **Do all the deciding, then all the changing.**

This is a poor engineer's transaction, and in a single-process design it's usually enough. Knowing that you're *emulating* a transaction — and being able to say what a real one would give you — is the senior version of the answer.

---

## 6. Money, time and rounding

Three domains where casual modelling creates real damage.

**Money is not a floating-point number.** Binary floating point cannot represent a tenth exactly, so sums drift, comparisons fail, and totals disagree with the sum of their parts. Use a decimal type or integer minor units. Interviewers notice immediately, because it's a one-word tell for whether you've shipped financial code.

**Rounding is a product decision, not a coding one.** Round per line or on the total? Round up, or to nearest? Who absorbs the half-paisa? Different answers are correct in different businesses, and the failure mode is not *choosing wrongly* — it's failing to notice there was a choice, and then rounding differently in two places.

**Time is a range, not a point.** Booking systems deal in intervals, and the only sane representation is half-open: a stay includes its start and excludes its end. That's what makes "checkout Tuesday, check-in Tuesday" work without a clash. Use closed intervals and you silently lose one night's revenue per room per day.

More generally: whenever you compare intervals, write the overlap rule down explicitly and test the touching case. It's two lines, and getting it wrong invalidates everything built on top.

---

## 7. Allocation policy is a design decision

When several resources could satisfy a request, *which one you pick* is a policy with consequences.

Take the first that fits and a motorcycle occupies a truck bay; later a truck arrives and is turned away while space exists. Take the *smallest* that fits and large spaces stay available for things that need them.

The generalisable point:

> **Any time you choose from a set of candidates, there is a policy — and if you didn't name it, you chose one by accident.**

Nearest driver, cheapest route, least-loaded worker, best-fit spot, highest-priority job. Naming the policy makes it swappable; leaving it implicit makes it a bug someone finds later.

And the cost of the policy matters: scanning every candidate is fine for hundreds and wrong for hundreds of thousands. The scaling answer is usually to maintain the candidates in the order you need rather than searching each time — but say the simple version first, then name the upgrade.

---

## 8. Layered rules and the closed/open question again

Medium problems tend to accumulate rules: discounts, fees, surcharges, eligibility. Two shapes appear repeatedly.

**A pipeline** — each rule adjusts a running value. Order matters, and the order is a business decision, not an implementation detail. (Does the percentage discount apply before or after the flat one? Different totals.)

**A selection** — many rules are eligible, exactly one applies, chosen by some criterion ("biggest discount wins"). Then the criterion is itself a rule, and ties need a deterministic tie-break or your output is unstable.

Both benefit from rules being separate, uniform things: each one decides whether it applies and what it does, and the engine knows nothing about any of them. The test of whether you got it right: can someone add a rule without touching the engine?

---

## 9. Bounding everything

Every medium problem has something that can grow without limit: log lines, cached entries, reservations, per-client rate-limit buckets, in-flight requests.

> **Anything that grows needs an eviction story, or it is a leak with a delay.**

The question for each: what's the limit — count, size, age, or cost — and what happens at the limit? Reject, evict the least useful, or block? Each is defensible; silence is not.

The related discipline is the **running aggregate**. If you only ever need an average, keep a sum and a count rather than every sample. Keeping samples "just in case" is how a metrics feature becomes a memory incident. When you *do* need percentiles, that's a different structure and a deliberate choice — not an accident of having kept everything.

---

## 10. The thinking procedure for a medium problem

1. **Name the resource(s).** What is finite here?
2. **Draw the lifecycle of one unit.** Expect three states, not two. Find the expiry.
3. **Separate events from conclusions.** Store events; derive balances, counts, availability.
4. **Find what must be frozen.** Anything affecting money or obligations gets copied, not referenced.
5. **List multi-step operations.** For each, order it as decide-then-apply, and name the compensation for failure.
6. **Check money, rounding and intervals.** Decimal, stated rounding rule, half-open ranges.
7. **Name every selection policy.** Then say what it costs at scale.
8. **Find everything unbounded.** Give each a limit and an eviction rule.
9. **Then** ask what varies, and only then reach for a pattern.

Steps 1–8 are where medium problems are won or lost. Step 9 is the part people rehearse.

---

## ✅ Concept checkpoint
1. Why is two states not enough for a contended resource, and what must the middle state carry?
2. Give the argument for derived state over stored state, and the condition under which you'd cache anyway.
3. Explain snapshotting with a money example, and give the question to ask of every relationship.
4. State the decide-then-apply rule and what it emulates.
5. Why is floating-point money a bug, and why is rounding a product decision?
6. Give the half-open interval rule and the revenue bug it prevents.
7. What must accompany anything that can grow without limit?

Then read the module `README.md`.
