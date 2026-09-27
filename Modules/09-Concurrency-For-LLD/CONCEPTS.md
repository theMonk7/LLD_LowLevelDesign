# Module 09 — Concepts: What Breaks When Two Things Happen at Once

> Read before the README. The mental shift here is larger than it looks: you stop reasoning about *a* sequence of steps and start reasoning about *all possible interleavings* of several.

---

## 1. The mental model: your code is not a story, it's a set of stories

Single-threaded reasoning reads like a narrative: this happened, then this, then this. Concurrency destroys that. What you actually have is several narratives whose sentences are **shuffled together in an order you don't control and can't reproduce**.

> **A concurrency bug is a design that is correct in most shuffles and wrong in one.**

That's why these bugs feel supernatural. The code is right. It passed review, and the tests, and staging. It's wrong only in an ordering that happens once every ten thousand times — which, at a thousand requests a second, is several times a minute in production.

The practical consequence: **you cannot find these by testing harder**. You find them by reasoning about where a shuffle could hurt, and then designing so that it can't.

---

## 2. The one bug you must be able to see instantly

Most concurrency failures in LLD problems are a single shape:

> **You checked something, and then you acted on what you checked — and in between, the world changed.**

Is the seat free? Yes. Book it. Two people both saw "yes", both booked.
Is there stock? Yes. Decrement. Both saw "yes", inventory goes negative.
Is the cache empty? Yes. Fetch. Sixty callers all saw "empty", sixty network requests.

The check was true when you looked. By the time you acted, it wasn't. Nothing in the code is wrong *in isolation* — the wrongness is in the **gap**.

Once you can see the gap, the fix is obvious and always the same idea: **remove the gap.** Make the check and the act one indivisible operation, so no other story can slot a sentence between them.

Train the reflex: every time you read code that queries state and then modifies state based on the answer, mentally insert "…and now another thread runs" between the two lines and ask what breaks.

---

## 3. The second bug: read, modify, write

Even a single innocuous-looking increment is three operations: fetch the value, add one, store it back. Two threads can both fetch 5, both compute 6, both store 6. One increment vanishes.

This is the same gap as above, at a smaller scale — and it's worth internalising because it destroys the intuition that "small operations are safe". Size has nothing to do with it. **Indivisibility** does.

---

## 4. The third bug: waiting for each other

Two workers each hold something the other needs, and neither will let go. Neither makes progress; the system doesn't crash, it just stops.

The design response is boring and effective: **impose an order**. If everyone always acquires resources in the same order, a cycle of waiting cannot form. When you must lock several things — several seats, several accounts — sort them by some stable key first. One line, whole class of failure eliminated.

The subtler relatives are worth naming so you recognise them: everyone politely backing off and retrying forever, and one unlucky participant who never gets a turn.

---

## 5. The core design idea: shrink what is shared

Every concurrency mechanism you'll meet is a way of managing *shared mutable state*. So the most powerful move isn't a mechanism at all:

> **Have less shared mutable state.**

Three ways, in order of preference:

**Don't share.** Immutable values can be read by everyone simultaneously with no coordination at all. A design built mostly from values has almost no concurrency surface. This is the deepest reason value semantics matter, and why Module 01 spent so long on it.

**Share, but funnel.** Let exactly one component own each piece of mutable state, and let everyone else ask it to do things. Now the interleavings only matter inside one small, reviewable place instead of everywhere.

**Share and guard.** Multiple owners, with locking. Most error-prone, and the only reason to choose it is an API that must remain synchronous.

The design question that follows: **for every piece of mutable state, who owns it?** If you can answer that for each one, and each owner is small, your design is probably safe. If the answer is "several things, coordinated by convention", it isn't.

---

## 6. The trap that surprises everyone: awaiting inside a protected region

Modern concurrency lets you write asynchronous code that reads like synchronous code. That readability hides something crucial:

> **Every `await` is a place where the world can change.**

If a component protects its own state by serialising access, that protection lasts only until it suspends. At a suspension, other work runs. A condition you verified before the suspension may be false after it.

So a method that checks something, awaits a slow operation, and then acts on the earlier check **has the check-then-act bug**, even though it's inside the thing that was supposed to protect it. The protection is real; it just doesn't span the suspension.

The two disciplines that follow are worth learning as habits:

1. **Don't suspend in the middle of a decision.** Make the decision atomically; do the slow thing afterwards.
2. **If you must suspend, re-verify afterwards.** Assume everything you learned before the suspension is stale.

---

## 7. The pattern that solves most real problems: reserve, then act, then settle

This is the single most valuable structure in this module, because it appears in seat booking, inventory, parking, ride matching, and every "don't let two people take the same thing" requirement.

The naive design holds the resource locked while doing the slow work — a payment, a network call. Two problems, both serious: every other user of the system waits behind one slow operation, and if the slow operation hangs, everything hangs.

The correct shape has three beats:

1. **Reserve** — a fast, atomic claim on the resource. No slow work, no suspension. Either you got it or you didn't.
2. **Do the slow thing** — outside any protected region. Other users are unaffected.
3. **Settle** — confirm the reservation on success, or release it on failure.

Two refinements make it production-grade:

**Every reservation needs an expiry.** If step 2 never finishes — a crashed client, a lost connection — the resource must eventually return. Without a deadline, one crash removes a seat from sale forever.

**Failure must compensate.** Releasing on failure is not optional cleanup; it's part of the algorithm. Designs that forget it leak resources slowly until someone notices sales are down.

---

## 8. Two philosophies for contention

When several parties want the same thing, you can assume collisions are common or rare.

**Assume common.** Take exclusive control first, then work. Simple, correct, and it serialises everyone — fine for genuinely hot resources like the last seat of a sold-out show.

**Assume rare.** Work on a snapshot, then attempt to commit *only if nothing changed underneath you*; retry if it did. No one waits in the common case; the cost is occasional wasted work.

Choosing is an empirical question about your data: how often do two operations actually touch the same record? For a catalogue of a million products, almost never — assume rare. For a flash sale on one product, constantly — assume common, or the retries themselves become the load.

Being able to name both and say which your data implies is a strong senior signal, precisely because it shows you think about the workload rather than the mechanism.

---

## 9. The other half of correctness: doing it twice must be safe

Concurrency's sibling problem is **retries**, and in any system with a network they're unavoidable: a request times out, a user taps twice, a client reconnects and replays.

If repeating an operation produces a second effect, you will eventually double-charge someone. Nobody decided to; it's what "at least once delivery" means in practice.

The design response: let the caller supply an identifier for the *intent*, and make the operation return the same result for a repeated identifier instead of doing the work again. Then a retry is safe by construction and nobody has to be careful.

> **Idempotency is how you make "we might do this twice" a non-event.**

There's a concurrency trap hiding inside it, which is worth seeing: if the check for "have I done this already?" and the recording of "I have now done it" are separated by the slow operation, then simultaneous duplicates all miss the check. The fix is to record the *in-flight* attempt before starting the slow work, so later arrivals find it and wait for the same result rather than starting their own. The same idea deduplicates concurrent cache fills and token refreshes.

---

## 10. How this changes your designs

Concurrency isn't a feature you add at the end; it changes what a good design looks like:

- **Prefer values.** Fewer things can be shared, so fewer things can race.
- **Give every piece of mutable state exactly one owner**, and keep owners small.
- **Keep slow work out of protected regions.** This single rule prevents most throughput disasters.
- **Prefer derived state over stored state.** If a balance is computed from a log, two concurrent writers append rather than fight over one number.
- **Design the failure path with the success path.** Reserve/release, charge/refund, claim/expire are pairs. Half a pair is a leak.
- **Inject time.** Deadlines, expiries and backoffs are untestable otherwise, and a test that sleeps is a test that flakes.

---

## 11. The thinking procedure

For any design, run this pass before you call it finished:

1. **List every piece of mutable state, and name its owner.** Unowned state is the bug.
2. **Find every check-then-act.** Make each one atomic, or accept the race explicitly.
3. **Find every suspension inside a decision.** Move the slow work out, or re-verify after.
4. **For every claim on a resource, find the expiry and the release.** Missing either is a leak.
5. **For every externally-triggered write, ask: what if this arrives twice?**
6. **If several things must be locked, define an order.**
7. **Ask what happens when the thing you're coordinating is exhausted.** Fail, wait, or grow — decide.

Then, in an interview, volunteer one of these before being asked. Candidates who raise concurrency themselves are read very differently from those who need prompting.

---

## ✅ Concept checkpoint
1. Why can't you find concurrency bugs by testing harder?
2. Describe check-then-act in one sentence and give three examples from different domains.
3. Why does a suspension inside a protected region defeat the protection?
4. Give the three beats of reserve/act/settle, and the two refinements that make it production-grade.
5. When is "assume collisions are rare" the wrong choice?
6. Explain the concurrency trap hiding inside a naive idempotency check.

Then read the module `README.md`.
