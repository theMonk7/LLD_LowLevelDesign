# Module 13 — Concepts: Designing Something You Can't Finish

> Read before the README. At this size the skill changes. You are no longer being asked to produce a complete design — you're being asked to produce a *coherent* one, and to know which parts you left out.

---

## 1. The mental model: the deliverable is a boundary, not a system

For a small problem, the answer is the solution. For a large one, the answer is:

> **"Here is the part I built, here is the part I didn't, and here is why that line is in the right place."**

A coherent 40% beats an incoherent 80%, because coherence is what proves you understand the system. Breadth without depth proves only that you can list features.

The practical consequence is that **scoping becomes the design work**, not a preliminary to it. Choosing to build matching-and-lifecycle while deferring notifications, persistence and analytics is a *design decision* with consequences, and it should be argued for, not apologised for.

---

## 2. Decomposition: the first real skill

Small problems have one obvious centre. Large ones have several, and the first question is where to cut.

The cut that works is by **responsibility**, and the test is:

> **Could this part change entirely without the others noticing?**

In an elevator system: how a car moves is one thing; which car is chosen is another. Change the scheduling algorithm and the car's movement doesn't care. Change the door timing and the scheduler doesn't care. That independence is what tells you the cut is real.

Contrast a bad cut — splitting by data structure, or by "things that sound similar". Those produce parts that must change together, which is a split in name only: you've added files without adding independence.

### The tell for a missing cut
One type that everything else references, that grows a method per feature, and that no two people can edit simultaneously. When you find it, ask *what are the different reasons this thing changes* — and each reason is a candidate part.

---

## 3. Policy and mechanism: the most reusable separation there is

A distinction that appears in nearly every hard problem:

- **Mechanism**: how a thing physically works. Moving a floor. Holding a seat. Storing a message. Validating a move.
- **Policy**: what we *choose* to do. Which car to send. Who gets the last seat. Which job runs next. Which move is legal in this variant.

Mechanism is stable and testable. Policy is where the requirements churn and the arguments happen.

> **Mixing them is why systems become unchangeable.** Separate them and the interviewer's "what if we changed the algorithm?" is a one-type answer instead of a rewrite.

The recognisable phrasing: any requirement containing the words *choose*, *prefer*, *best*, *first available*, *priority*, or *fairness* is policy. Pull it out.

---

## 4. Layering a decision: validate in stages, not all at once

Large domains have rules that are expensive to check and rules that are cheap, and rules that depend on other rules having passed.

Chess is the clean example. "Can a bishop move like that?" is local and cheap. "Does this move leave my own king attacked?" requires simulating the move and re-examining the whole board. Trying to answer both in one function produces code nobody can follow.

The structure that works:

1. Check the cheap, local rules.
2. Tentatively apply the change.
3. Check the expensive, global rules.
4. Undo if they fail.

> **Two layers, each simple, beat one layer that is clever.**

And notice the reuse: the global check is written once and used for "is this move legal", "is the king in check", and later "is this checkmate". One rule set, three questions — which is only possible because the layers are separate.

---

## 5. Lifecycles get their own model

Once an entity has more than about three states, informal handling stops working. The failure is gradual: a boolean here, a status string there, and after four features nobody can say which transitions are legal.

Two viable models:

**A transition table** — one place that declares, for each state, which states it may move to. The whole lifecycle is readable at a glance, and an illegal transition is impossible by construction. Best when the lifecycle is mostly linear with a few branches.

**A type per state** — each state answers every event for itself and names its successors. Best when states have genuinely different behaviour, their own data, or their own dependencies.

Either way, the design content is the same and it's not about syntax:

> **Enumerate the states. Enumerate the events. Decide, for every pair, what happens.**

Most of the bugs in large systems live in the pairs nobody enumerated — "what happens if the restaurant rejects after the customer already cancelled?" The grid is how you find them before a user does.

---

## 6. Every long operation is really three

Anything that takes time — a payment, a dispatch, a download, a human decision — cannot be modelled as one atomic step. It is always:

**intend → do → settle**

Reserve, charge, confirm. Assign, deliver, complete. Claim, run, acknowledge.

Three consequences fall out, and they're the same three every time:

- The middle state must be **visible**, because the system is in it for a while and someone will ask what's happening.
- The middle state must **expire**, because the thing doing the work may never come back.
- The settle step must have **both outcomes designed** — success and compensation — because the failure path is where resources leak.

Once you see this shape, hard problems get dramatically easier: booking, delivery assignment, job execution, distributed leases, checkout flows are all the same three beats with different nouns.

---

## 7. When one worker becomes many: leases

Scale introduces a question that doesn't exist with one worker: **how do you stop two of them doing the same work?**

The general answer is a **lease**: a worker takes a time-limited claim on a piece of work, renews it while working, and the claim expires if the worker dies. Another worker may take it only after expiry.

This gives you *at-least-once* execution — work is never lost, but may run twice. Exactly-once is not available across a network, so the design response is the one from Module 09: make the work **idempotent**, and running it twice stops mattering.

> **Lease + idempotent work is the practical substitute for exactly-once.**

The same shape covers pool checkout, distributed jobs, message consumption and seat holds. It's the multi-worker version of §6's middle state.

---

## 8. Consumption you can't undo: offsets and acknowledgement

When several parties read the same stream of things, a question appears that's easy to get backwards: *when is something considered consumed?*

If reading marks it consumed, a consumer that crashes mid-work loses the item — nobody will ever process it again. If consumption is a **separate acknowledgement** after successful work, a crash means the item is retried, which is recoverable.

> **Read and acknowledge must be separate operations, and the acknowledgement must come after the work.**

And the consequence is once again idempotency — because "retried after a crash" means "possibly processed twice". You'll notice the same answer keeps arriving from different directions; that's a sign it's load-bearing.

The related metric is *how far behind* a consumer is. It's the first thing anyone asks about a queue in production, and a design that can't answer it is incomplete.

---

## 9. Distribution as a modelling problem

When work must be spread across machines, the naive mapping — take the identifier, divide by the number of machines — has a property that only shows up on the day you add a machine: **almost everything moves**. Caches empty, connections shuffle, load spikes.

The alternative is to place machines and keys on a shared circular space and assign each key to the next machine clockwise. Adding a machine now steals only the arc between it and its neighbour; everything else is undisturbed.

Two details are the difference between working and not: each machine needs **many positions** on the circle (one position each gives wildly uneven shares), and keys past the last position must **wrap** to the first.

You rarely implement this in an LLD round. But recognising *"this design moves everything when membership changes"* as a flaw — and naming the shape of the fix — is exactly the kind of thing that distinguishes a hard-problem answer.

---

## 10. Cost models: "closest" is usually wrong

A recurring trap in scheduling problems: choosing by the most obvious metric rather than the real one.

The nearest elevator may be the slowest to arrive, because it's travelling away from you and must finish its run first. The nearest driver may be furthest in time because of the direction they're heading. The least-loaded worker may be slowest if its queue holds long jobs.

> **The right cost is "time until this candidate can actually serve me", not "distance right now".**

Building that cost means simulating the candidate's plan far enough to see when it reaches you. That's more work than a subtraction — and it's the difference between a scheduler that feels sane and one that doesn't.

The transferable question: *what is the true cost function here, and what am I substituting for it because it's easier to compute?*

---

## 11. How to talk about what you didn't build

The deferral is part of the design, so present it that way:

> *"I've built matching, the ride lifecycle, and fare calculation. I've deliberately left out persistence, notifications and the geospatial index. The index matters most — I'd put it behind a `DriverIndex` protocol so the naive scan can be replaced by a geohash lookup without touching the matcher. That seam is in the design already."*

Three moves in that paragraph: name the boundary, rank what's missing, and show that the missing part has a *place to attach*. The last one is what proves the design anticipates it rather than ignores it.

Compare with "I didn't have time for the rest", which communicates nothing about your judgment.

---

## 12. The thinking procedure for a hard problem

1. **Write the three lists** — in, out, deferred-with-a-plan. Then hold the line.
2. **Cut by responsibility**, and check each cut with "could this change alone?"
3. **Separate policy from mechanism** everywhere you see choose/prefer/best/priority.
4. **Model every lifecycle explicitly** — states × events, and fill in the grid.
5. **Find the long operations** and give each one three beats, with expiry and compensation.
6. **Find the contended resources** and decide who may claim them, for how long.
7. **Find what must be idempotent** — anything a client can retry.
8. **Name the cost function** for every selection, and check you're not substituting an easier one.
9. **Say what you deferred and where it attaches.**

Nine steps, and notice only one of them is about patterns. At this size, patterns are the least interesting part of the answer.

---

## ✅ Concept checkpoint
1. Why does a coherent 40% beat an incoherent 80%?
2. Give the test for whether a decomposition is real.
3. Define policy versus mechanism, and list the requirement words that signal policy.
4. Why do two layers of validation beat one clever one, and what reuse does it enable?
5. Give the three beats of a long operation and the three consequences.
6. Why is "lease plus idempotent work" the practical substitute for exactly-once?
7. Why is "nearest" usually the wrong cost function?

Then read the module `README.md`.
