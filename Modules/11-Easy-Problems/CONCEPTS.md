# Module 11 — Concepts: Reading a Small Problem Correctly

> Read before the README. Small problems are where design habits are cheap to build — and where bad ones hide, because everything works anyway.

---

## 1. The mental model: small problems are *diagnostic*

A small problem has an obvious solution, which is exactly what makes it useful. Since everyone can make it work, what's being measured is *how* you made it work:

- Did you enforce rules inside the type, or trust the caller?
- Did the data structure follow the access pattern, or the first thing you thought of?
- Did you find the concept that wasn't named?
- Would a second feature be an addition or an edit?

> **On a small problem, correctness is the entry fee. The design is the answer.**

This is why "it's just tic-tac-toe" is the wrong attitude. The interviewer already knows you can do tic-tac-toe.

---

## 2. Habit one: the type owns the rule

Every problem here has rules — you can't play out of turn, you can't book a taken seat, you can't pop an empty stack, the board fills up.

Two places a rule can live:

- **In the caller**, as a check before calling. Then the rule is copied into every caller, and the copies drift.
- **In the type**, as a guard inside the operation. Then it exists once and cannot be bypassed.

The second is the whole of Module 01 §3 in practice. And it has a corollary that appears in almost every problem in this module:

> **Validate everything before you mutate anything.**

If all the rejections happen before the first assignment, a rejected operation leaves the object exactly as it was. No rollback logic, no half-applied state. Get this ordering habit now and it will save you in Modules 12 and 13, where operations touch four pieces of state at once and a half-applied mutation is a real corruption.

---

## 3. Habit two: choose the structure from the *operations*

The reflex is to pick a container first — an array, usually — and then make the operations work. Reverse it.

> **List the operations and their required cost. The structure is whatever satisfies that list.**

A cache that must find by key *and* reorder by recency, both cheaply, cannot be an array: the lookup is fine, the reorder isn't. It cannot be a dictionary alone: the lookup is fine, there's no order. It needs both, wired together — and that conclusion is *forced* by the operation list, not invented.

A queue with a fixed capacity where every operation must be cheap can't shuffle elements on removal; it must move indices instead, which is why circular buffers exist.

A structure that answers "all words starting with this prefix" cannot be a list of words, because that's a scan of everything; it must share prefixes, which is what a trie *is*.

None of these are tricks to memorise. Each is the only shape that satisfies its operation list. If you derive rather than recall, you can handle a structure you've never seen.

### The sibling habit: store the derived value when recomputing is expensive
If a query is asked constantly and computed slowly, carry the answer along as you go. A stack that must report its minimum instantly can remember, with each element, the minimum at that point — so popping restores the previous answer for free.

The counterweight, from Module 03: only when recomputation is genuinely expensive. Two sources of truth are a permanent liability; buying speed with one is a decision, not a default.

---

## 4. Habit three: find the concept that isn't named

The prompt gives you nouns. The design usually needs one more.

The classic here: snakes and ladders. Two words, two directions, apparently two things. But both say *"from this square, go to that square"*. They are one concept with a sign. Model them as two types and every rule is written twice; model them as one and the difference is a comparison.

> **When two nouns have the same shape and differ only in a value, they are one type.**

The mirror of that skill is spotting when one noun is really two: a book (the title, the author — a catalogue entry) and a copy of a book (a physical object with a location and a borrower). "Is it available?" is a question about copies. Merge them and you can't express a library with three copies of one book.

The generalised question, worth asking of every noun:

> **"Would two of these with identical fields be the same thing, or two different things?"**

Same → one concept, possibly with a parameter. Different → you need identity, and maybe two types.

---

## 5. Habit four: make the untestable testable *by construction*

Three things silently make code untestable: the clock, randomness, and anything across a network.

The instinct to fight is "I'll just call the global one". A game engine that rolls its own dice cannot be tested, because you can't make it roll a four. A deck that shuffles itself cannot be verified, because you can't predict the order. A library that reads the current date cannot be checked for overdue books without waiting two weeks.

The fix is one idea: **make the unpredictable thing an input**. The engine is handed something that produces numbers; the test hands it a script. Nothing about the design gets worse; it gets *more* honest, because the dependency is now visible in the signature.

> **If you can't test it, you have a hidden input. Find it and make it explicit.**

This is the same move as dependency inversion, met earlier as a principle and appearing here as a practical necessity. That's the usual order: principles feel abstract until a test forces them.

---

## 6. Habit five: check only what changed

A naive win check scans the whole board. A better one notices that only lines through the *last move* can be newly complete.

This isn't primarily about performance — at three-by-three, nobody cares. It's about a way of thinking that scales:

> **After a change, ask what could possibly have become true. Check that, not everything.**

The same reasoning gives you incremental validation, efficient invalidation of caches, and change-driven UI updates. It's one of the few genuinely transferable optimisation instincts, and small problems are where it's cheap to practise.

---

## 7. Habit six: "the same action invalidates a different future"

Browser history: visiting a new page clears the forward stack. Undo systems: a new action clears the redo stack. Booking: a new reservation invalidates a previous hold.

All the same shape. You were maintaining an alternate timeline; the user did something that contradicts it; the alternate timeline must be discarded, not kept.

Forget it and the bug is uncanny rather than obvious — pages you never visited reappear, undone work returns, a released seat re-books itself. Nothing crashes. It's just haunted.

> **Whenever you keep "what could come next", identify what makes it invalid, and discard it there.**

---

## 8. What "easy" is really training

Reading the list of habits, notice none of them is about the specific problems:

- rules inside the type
- validate before mutate
- structure derived from operations
- derived-value caching as a deliberate trade
- unnamed concepts, in both directions
- explicit inputs for the unpredictable
- check only what changed
- invalidate contradicted futures

Each will reappear in Modules 12 and 13 at ten times the scale, where getting them wrong is expensive and hard to see. Building them now, on problems where you can hold the whole thing in your head, is the entire point.

---

## 9. How to practise these properly

**Design before reading.** Twenty minutes on your own version, then compare. Reading a solution you haven't attempted produces recognition, which feels like learning and isn't.

**Compare decisions, not code.** Where you differ, ask which is better and why — sometimes yours will be, and knowing that is worth more than matching.

**Extend before moving on.** Pick the next plausible feature, trace it, count the files. That number is the design's real quality score.

**Redo from blank.** A week later, rebuild it without notes. The second attempt is where design becomes yours; the first is transcription.

---

## ✅ Concept checkpoint
1. Why is correctness the entry fee rather than the answer on a small problem?
2. State the validate-then-mutate rule and say what it buys you.
3. Derive, don't recall: why can't a recency-ordered cache be built from an array alone?
4. Give the one-question test for "are these two nouns one concept?" and apply it to snake/ladder and book/copy.
5. Name the three ambient dependencies that make code untestable, and the single fix.
6. Give three situations that share the "invalidate the contradicted future" shape.

Then read the module `README.md`.
