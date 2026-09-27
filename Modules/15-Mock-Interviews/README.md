# Module 15 — Mock Interviews & Retention

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** convert knowledge into performance. You already know the material; this module is about doing it **out loud, on a clock, under someone else's questions**.

There is no code to write here. The deliverables are eight recorded mocks, a grading sheet, and a revision schedule.

---

## 1. How to run a mock alone

You will not always have a partner. Solo mocks still work if you keep them honest:

1. **Record yourself** (voice memo or screen recording). This is non-negotiable — you cannot hear your own silences while you're in them.
2. **Set a visible timer** and follow the Module 10 §9 time-box.
3. **Narrate everything.** If you're thinking, say what you're thinking about.
4. **Use the interviewer script** in `EXERCISES.md`: each mock has follow-up questions delivered at fixed times, whether or not you're ready.
5. **Grade yourself from the recording, not from memory.** Memory says you explained the tradeoff; the recording says you mumbled "yeah so like, strategy or whatever".

With a partner, swap roles. Being the interviewer is the fastest way to learn what a weak answer sounds like.

---

## 2. The grading sheet

Score each mock out of 50. Use the recording.

| # | Criterion | 0 | 3 | 5 |
|---|---|---|---|---|
| 1 | Clarified before designing | started coding | asked 2–3 | 6+ targeted, with scope written down |
| 2 | Stated what's out of scope | never | implied | explicit list, confirmed |
| 3 | Entities and boundaries | god class | partial | each type's responsibility stated in one sentence |
| 4 | Found implied entities | none | one | 2+, unprompted |
| 5 | Named variation axes before patterns | pattern-first | mixed | "X varies by Y, therefore Z" every time |
| 6 | Justified every abstraction | none | some | each one, in one line; and rejected at least one |
| 7 | Handled edge cases | none | 2–3 | 6+ across categories, unprompted |
| 8 | Answered the extension question in ≤2 files | rewrote | 3–4 files | 1–2 files |
| 9 | Communication | long silences | patchy | continuous narration, no gap over 20 s |
| 10 | Finished something runnable | nothing | fragments | core path works or is credibly pseudocoded |

**Target trajectory:** mock 1 around 25–30, mock 8 above 42. If you're not improving, the problem is almost always criterion 1 or 9, not knowledge.

---

## 3. The eight failure modes, and the fix

| Failure mode | What it sounds like | Fix |
|---|---|---|
| **Diving into code** | typing at minute 3 | force yourself to fill the three scope lists first |
| **Pattern-first** | "I'll use a factory here" with no reason | always say the variation sentence before the pattern name |
| **Over-engineering** | 14 types for Tic-Tac-Toe | run the deletion test (Module 08 §7) out loud |
| **Silence** | 90 seconds of typing with no words | narrate the *next* decision, even if unsure |
| **Requirement drift** | building features nobody asked for | re-read your own in-scope list at the halfway mark |
| **Defensive answers** | arguing when challenged | "that's a good point — let me think about that case" |
| **No edge cases** | only the happy path | run the Module 10 §7 checklist aloud |
| **Running out of time** | 60% built, nothing runs | at the halfway checkpoint, cut scope and say so |

---

## 4. Recovering mid-interview

| Situation | Script |
|---|---|
| Can't find the entities | *"Let me walk the main use case in plain English and pull the nouns out as I go."* |
| Stuck choosing a pattern | *"Let me name what varies here first — the pricing rule changes per city, so that's the thing I want behind a protocol."* |
| Realise your design is wrong | *"I've realised this puts the rule in the wrong place. Rather than patch it, let me move it to X — it's a small change and it makes the extension question easier."* |
| Interviewer challenges you | *"You're right that this costs an extra indirection. I'd take that trade because Y; if Y doesn't hold, I'd keep it concrete."* |
| Running out of time | *"I have about ten minutes. I'll finish the booking path so it runs, and describe the cancellation flow rather than code it."* |
| Asked something you don't know | *"I haven't used that. My instinct would be X because Y — is that the direction you'd expect?"* |

**Changing your mind mid-design is a strength**, provided you say *why*. Silently rewriting looks like flailing; narrated revision looks like engineering.

---

## 5. Spaced repetition schedule

Dates are days after finishing Module 14. Each session is 30–45 minutes.

| Day | Session |
|---|---|
| +1 | Recall SOLID + the 23 patterns from memory onto a blank page. Check against Module 08 §9. |
| +3 | Redo the 30 selection drills (Module 08). Target 30/30 in under 10 minutes. |
| +5 | Re-solve Tic-Tac-Toe and LRU from scratch, no notes, 40 minutes total. |
| +7 | Mock 1 + 2. |
| +10 | Re-read Module 09; write the reserve/confirm flow from memory. |
| +12 | Mock 3 + 4. |
| +15 | Re-solve Parking Lot from scratch, 45 minutes. Compare against Module 12. |
| +18 | Mock 5 + 6. |
| +21 | Re-read your mistake log in `PROGRESS.md`. Redo the two problems you scored worst on. |
| +25 | Mock 7 + 8. |
| +30 | Full review: all module checkpoints, answered aloud. |

Then monthly: one mock, one re-solve, one pass over the mistake log.

---

## 6. Night-before cheat sheet

**The framework:** Discover → Entities → Structure → Interfaces → Gaps → Nail it down.

**First three questions:** Who are the actors? What's likely to change? Is this concurrent?

**Variation → pattern:** algorithm → Strategy · lifecycle behaviour → State · listeners → Observer · creation → Factory · optional layers → Decorator · handler → Chain · one step of a process → Template Method · matched families → Abstract Factory · complex construction → Builder.

**SOLID in one line each:** one reason to change · extend without editing · subtypes must honour the contract · no forced unused methods · depend on abstractions.

**Edge-case categories:** empty · full · boundary · duplicate · invalid · concurrent · failure/compensation · time · money.

**Swift specifics:** `struct` for values, `class` for identity · `static let` singletons are thread-safe · `any P` for heterogeneous collections · declare in the protocol what conformers must override · `Decimal` for money · inject `Clock`/`RNG`/transport · `actor` for shared mutable state · no `await` inside a critical section.

**Things to say:** *"Let me clarify scope first."* · *"X varies by Y, so I'll put it behind a protocol."* · *"I'd keep this concrete — there's one implementation."* · *"Two users doing this at once is a check-then-act; I'd make it atomic."* · *"With more time I'd add…"*

---

## 7. What "good" sounds like

A strong 45-minute round, compressed:

> *(0–6)* "Before I design — is this one lot or many? In-memory or persisted? … Let me write what I'm assuming: in scope, out of scope, and non-functional. I'll assume payments are out of scope."
> *(6–13)* "Actors are the driver and the admin. Nouns: lot, floor, spot, vehicle, ticket. Ticket isn't in the prompt but it has to exist — it holds the entry time the fee depends on."
> *(13–25)* "Here's the class diagram. Spots are composed into floors because a spot has no meaning outside its floor. A spot holds zero or one vehicle — that multiplicity is the invariant I'll enforce in code."
> *(25–30)* "Public API: park, unpark, availability. Let me trace 'driver parks and exits' through it… that works, and it shows I need `availability(for:)` on the lot, not on the floor."
> *(30–35)* "Pricing varies by vehicle type and will change — that's a Strategy. Allocation could vary too, but there's one rule today, so I'll keep it concrete and note the seam. Edge cases: lot full, ticket reused, zero-duration stay, partial hour rounding, two gates racing for the last spot."
> *(35–55)* "Coding the core now — values first, then the lot, then a demo."
> *(55–60)* "It runs. With more time: free-list per size for O(1) allocation, an actor around `park`, and a persistence protocol."

Notice: no pattern is named before its reason, one abstraction is explicitly *declined*, and the concurrency question is raised by the candidate rather than the interviewer.

---

## ✅ Checkpoint
You're ready when you can, cold, on an unfamiliar prompt:
1. Produce three scope lists in six minutes.
2. Name two implied entities.
3. Draw a class diagram with correct ownership and multiplicity in ten minutes.
4. Name every abstraction's variation axis, and decline at least one.
5. List six edge cases unprompted.
6. Answer "now add X" by touching one or two files.
7. Talk continuously while doing all of it.

Then: `EXERCISES.md` (8 mocks) → `SOLUTIONS.md` (model answers) → `PROJECT.md` (final assessment).
