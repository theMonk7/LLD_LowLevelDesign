# Module 10 — Concepts: How to Start When You Don't Know How to Start

> Read before the README. The framework in the README is a procedure. This file is why the procedure is shaped that way, and what your mind should be doing at each stage.

---

## 1. The mental model: design is *narrowing*, not inventing

The blank-page feeling comes from a wrong belief: that you must invent a solution. You don't. The solution is largely determined by the problem — once the problem is actually stated.

> **Most of design is converting an under-specified prompt into a specified one. The specified one mostly designs itself.**

"Design a parking lot" has no correct answer, because a thousand systems match that sentence. The moment you've pinned down which vehicles, which pricing, whether it persists, whether it's concurrent, the space of reasonable designs collapses to a handful — and choosing between a handful is easy.

So when you feel stuck, you are almost never short of design ideas. You are short of **constraints**. The cure is questions, not inspiration.

---

## 2. Why the order matters (and why everyone gets it wrong)

The instinct under time pressure is to start producing visible output — classes, code — because that *feels* like progress. It is the most expensive mistake available, for a simple reason:

> **Every later step is cheap if the earlier ones are right, and worthless if they're wrong.**

Beautiful code for the wrong model is waste. A clean model of an unbounded problem is waste. The order — scope, then entities, then structure, then behaviour, then code — isn't ceremony; it's dependency order. Each step consumes the previous step's output.

And the payoff is asymmetric in your favour: six minutes of scoping saves twenty minutes of redesign, *and* it's the part interviewers weight most heavily. You are spending time on the thing that's both cheapest and most visible.

---

## 3. Stage 1 — Scoping: what your mind should be doing

You are converting prose into a contract. Three outputs, and the third is the one people skip:

**What's in.** A handful of things the system must do. Not features — *capabilities*.

**What's out.** Said explicitly. This is not a retreat; it's evidence that you know the space is larger than the time. Naming what you're not building proves you saw it.

**What's true but not functional.** Concurrency, expected scale, and — most importantly — **what is expected to change**. That last one determines where structure goes, which makes it the highest-value sentence in the conversation.

### The mental habit
Read the prompt and listen for **words that hide decisions**:
- "users" → one kind, or roles with different powers?
- "payment" → do I model money movement, or assume success?
- "real time" → sub-second, or eventually?
- "scalable" → extensible, or high-traffic? (These are different interviews.)
- "like [famous app]" → which slice? Nobody designs all of it.
- Any number that isn't there → ten items or ten million? The answer changes your data structures.

Each vague word is a question, and each question you ask converts guesswork into specification.

### The single best question
> **"What's likely to change in the next six months?"**

It tells you where to be flexible and — just as valuable — where to be rigid. Without it, you're distributing structure by guesswork.

---

## 4. Stage 2 — Entities: nouns are cheap, implied nouns are gold

The mechanical part is easy: underline nouns, strike the fakes, attach verbs to whichever noun holds the data.

The valuable part is finding the nouns **that aren't in the prompt**.

> **Whenever a relationship has its own data, its own lifetime, or must be frozen in time — it's a type nobody named.**

- "A member borrows a book for fourteen days." Who holds the due date? Not the member, not the book. There's a third thing.
- "Seats are held while the user pays." Who holds the deadline and the holder's identity? A third thing.
- "The user pays, and it might fail and be retried." A boolean cannot hold a status, a method, and an attempt count. A third thing.
- "A cart becomes an order; menu prices change later." If the order references the live price, history rewrites itself. The price must be *copied* at a moment in time — which means the line item is a thing, not a reference.

That last pattern — **snapshotting** — deserves its own mental alarm. Any time a record must remain true after the world moves on, something must be copied rather than referenced. Getting this wrong produces invoices that change retroactively, which is the kind of bug that reaches lawyers.

Finding two or three implied entities unprompted is, minute for minute, the highest-scoring thing you can do in an LLD interview. It's the clearest evidence that you're modelling rather than transcribing.

---

## 5. Stage 3 — Structure: five questions per type

For each candidate type, ask:

1. **Is it a value or an entity?** (Compare by content, or track through time?)
2. **What does it promise?** That's the invariant, and it tells you what to hide.
3. **What single reason would make me edit it?** Two reasons → split.
4. **Does it own its parts, or just know them?** Ownership determines creation, deletion, and reference strength.
5. **How many of each relationship?** Multiplicity is where invariants hide, especially "at least one".

Five questions, answered honestly, produce a diagram that's already good. And notice none of them is "which pattern?" — patterns come later, and only where variation was identified.

---

## 6. Stage 4 — Interactions: the cheapest bug-finder available

Writing down the public API and then *tracing one complete use case through it* is the highest-yield ten minutes in the whole process, for one reason:

> **Simulation finds missing pieces that inspection doesn't.**

A diagram can look complete and still be unusable. Walking a flow exposes three specific failures:

- A step with nowhere to land → a missing method.
- A step that needs data the caller doesn't have → a boundary in the wrong place.
- A returned value nobody uses → a responsibility assigned to the wrong type.

None of those are visible in a static picture. All of them are obvious the moment you try to use it.

---

## 7. Stage 5 — Gaps: where patterns finally enter

Only now is it legitimate to think about patterns, and only through the sentence from Module 08: *"the ___ varies by ___."* If you can't complete it, there's no pattern to apply — and saying so is a *good* answer.

This is also where edge cases belong, and there's a reason they're a checklist rather than inspiration: under pressure, memory fails and lists don't. Run the categories mechanically — empty, full, exactly at the boundary, duplicate, invalid, concurrent, partial failure, time, money — and you'll produce six cases in ninety seconds that would otherwise never surface.

The two that separate candidates:
- **Partial failure**: what compensates when step three of four fails?
- **Concurrent**: what if two actors do this at the same instant?

Volunteer those two before being asked.

---

## 8. Stage 6 — Code: what to write first, and what to say while writing

Order matters here too, because you'll run out of time:

1. **Values and closed sets** — fast, and they make everything downstream readable.
2. **Entities with their invariants** — the promises from stage 3.
3. **The happy path through the main service** — proving the model works end to end.
4. **One variation point** — the thing you said would change.
5. **A runnable demo.**
6. **Edge cases**, in the order you listed them.

And the rule that decides the outcome:

> **Something running beats everything half-written.**

Because a running core can be *extended* in conversation — "and here's where cancellation would hook in" — while a half-written everything can only be apologised for.

The corollary is that **stubbing out loud is a skill**. "I'll define the persistence boundary and use an in-memory implementation; a database version is straightforward" costs eight seconds and buys you the whole subsystem as understood-but-not-built.

---

## 9. The clock: what to do at the halfway mark

Set one checkpoint at the halfway point and enforce one rule:

> **If nothing runs at halfway, stop designing and start typing.**

The failure mode this prevents is the elegant unfinished design — which reads to the interviewer as "cannot ship". Half the allotted time is enough for a core if the model is decided, and the model should be decided by then.

Conversely, if you're typing at minute three, you're solving a problem nobody stated. Both failure modes are about the *ratio*, and the checkpoint is what keeps you honest about it.

---

## 10. On being stuck, and on being challenged

**Stuck on entities** → narrate the main use case in plain English. The nouns fall out of the sentences. Speech is a better search tool than staring.

**Stuck on a pattern** → say what varies. If nothing does, you're finished and didn't notice.

**Too many classes** → ask "what's the smallest thing that runs the happy path?" and rebuild from there.

**Challenged on a decision** → the reflex to defend is wrong. Restate the tradeoff, say what would change your mind. A designer who can articulate the conditions under which they'd choose differently is demonstrably thinking, not reciting.

**Realised your design is wrong** → say so and move. Narrated revision reads as engineering; silent rewriting reads as flailing. Changing your mind out loud is a strength, provided you say why.

**Out of time** → name what's left and how you'd build it. An honest inventory of remaining work is itself a design artefact.

The only unrecoverable state is silence. Every other situation has a sentence that improves it.

---

## 11. Why the procedure beats talent

Under pressure, people fall back on habit, not ability. That's precisely why a mechanical procedure outperforms improvisation in interviews: it survives adrenaline.

The framework also produces something improvisation doesn't — a **legible trace**. The interviewer can see the scope lists, the entity table, the diagram, the variation sentences. They're not guessing at your reasoning; they're reading it. And what they're actually assessing is not whether you found the best design, but whether your *process* would find a good design on a problem they haven't seen.

That's the thing being bought. The procedure is how you show it.

---

## ✅ Concept checkpoint
1. Why is "I'm stuck" usually a shortage of constraints rather than of ideas?
2. Why does step order matter — what makes later steps worthless if earlier ones are wrong?
3. Give the rule for spotting an implied entity, and explain snapshotting with an example.
4. What three failures does tracing a use case reveal that a diagram doesn't?
5. What's the halfway-point rule and which failure does it prevent?
6. What's the only unrecoverable state in an interview, and why?

Then read the module `README.md`.
