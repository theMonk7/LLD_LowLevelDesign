# Module 04 — Concepts: Why Draw At All

> Read before the README. This module looks like notation. It isn't — it's about making *ownership* visible, and notation is just the ink.

---

## 1. The mental model: a diagram is a thinking tool that happens to be shareable

People treat UML as documentation — something you produce after designing, for someone else. That's the least valuable use of it, and why most teams abandoned it.

The valuable use is the opposite:

> **A diagram is a device that forces you to answer questions you'd otherwise leave vague.**

You cannot draw a line between two boxes without deciding *what kind* of line. You cannot write multiplicity without deciding whether a spot can hold two cars. You cannot draw the boxes without deciding what the types are.

Prose lets you stay vague — "the order has some items" — and vagueness survives all the way to code, where it becomes someone else's bug. A diagram makes vagueness *visible*, immediately, because you'll be sitting there with a pen wondering which arrowhead to use. That moment of hesitation **is** the design work.

So the right question isn't "should I draw UML?" It's "do I currently know the answers a diagram would demand?" If not, drawing is the fastest way to find out.

---

## 2. What a class diagram really encodes

Strip away the notation and a class diagram states three things:

1. **What exists.** Which concepts are worth naming.
2. **Who owns what.** Which things die with their container and which outlive it.
3. **How many.** Whether a relationship is one, optional, or many — which is where most invariants live.

That's it. Three facts, and all three are things you must decide anyway. The diagram just refuses to let you skip them.

Notice what's *not* on it: implementation, algorithms, performance, sequencing. That omission is deliberate. A class diagram is about **structure**, and structure is what constrains change.

---

## 3. Ownership: the one distinction that carries real weight

Every relationship line answers: *what happens to B when A goes away?*

- **B dies too** — A truly owns B. B has no independent existence; it was created by A and means nothing outside it. An order line without its order is noise.
- **B survives** — A merely refers to B. A library knows its books; delete the library and the books still exist. A playlist knows its songs.
- **A just borrows B briefly** — B is passed in, used, and forgotten. Not a relationship at all, really; a momentary acquaintance.

Why this matters beyond drawing: it tells you **who creates it**, **who validates it**, **who deletes it**, and **whether the reference should be strong**. Four code decisions fall out of one arrowhead.

### The intuition pump
A house and its rooms: demolish the house, the rooms cease to exist. A house and its occupants: demolish the house, the people are still people.

If you can't decide, ask: *"could this thing be moved to a different owner and still make sense?"* If yes, it's not owned — it's referenced.

---

## 4. Multiplicity is where invariants hide

"A spot holds zero or one vehicle." That sentence is a *rule*, and writing it on a diagram commits you to enforcing it in code. Without it you'll write an array and discover, eventually, that a spot has two cars in it.

The four you need:
- exactly one → a non-optional field, and something must guarantee it exists
- zero or one → an optional, and every reader handles absence
- many → a collection
- at least one → a collection **plus an invariant you must actively enforce**, because the type system won't

That last one is worth dwelling on. "At least one" is the multiplicity that languages don't express, so it's the one that quietly becomes "zero" in production. Seeing it on a diagram is the reminder to guard it in the initialiser.

---

## 5. Why the *shape* of the diagram tells you about the design

Before reading any labels, the silhouette already tells you things:

- **One huge box with lines to everything** → God Object. The hub knows all, so all change flows through it.
- **A deep vertical chain of inheritance** → a hierarchy built for reuse; expect fragile-base-class trouble.
- **No dashed "conforms to" lines anywhere** → there are no extension points; the next feature will be an edit, not an addition.
- **Everything pointing at one concrete low-level box** (a database, a network client) → dependencies point *downward* at mechanism; DIP is missing.
- **Boxes named `Manager`, `Helper`, `Processor`** → the author didn't find the responsibility and named the container instead.

You can read all of that from across a room. That's the argument for drawing before coding: design flaws have a *visual signature* long before they have a stack trace.

---

## 6. The other diagrams, and the single question each answers

You do not need all of UML. You need four questions:

**"Who calls whom, in what order?"** → a sequence diagram. Its real value is that arrows must land on methods that exist. Drawing one reliably reveals a missing method, or a step that needs data the caller doesn't have — which means a boundary is in the wrong place. Ten minutes of drawing saves an hour of rewriting.

**"How does this one thing behave over its lifetime?"** → a state diagram. Anything with a status field is secretly a state machine; drawing it exposes the transitions nobody specified. The questions it forces — *can you cancel after shipping? what happens to a held seat if the app crashes?* — are exactly the ones interviewers ask.

**"Who are the actors and what do they want?"** → a use case sketch. Sixty seconds, and its output is your public API surface. Then stop.

**"What's the flow when things branch and fail?"** → an activity diagram. Worth drawing only when compensation matters — the "release the seats if payment fails" step that candidates forget until a diagram leaves a dangling arrow.

---

## 7. How to think while drawing (the mechanical method)

The reason to be mechanical is that it works under pressure, when inspiration doesn't:

1. **Underline nouns** in the agreed requirements. Those are candidate types.
2. **Strike the fakes**: "system", "data", "info", and anything that's really an attribute ("duration", "status", "name").
3. **Hunt implied nouns.** This is where the marks are. Whenever a relationship *has its own data or lifetime*, it's a type nobody named: a loan, an assignment, a reservation, a payment attempt, a session, an audit entry.
4. **Underline verbs** and attach each to the noun that already holds the data it needs.
5. **Draw boxes**, two to four members each — only the ones that carry a decision.
6. **Connect and decide ownership**, then write multiplicity on every line.
7. **Mark variation points** with a distinct shape. These are your answer to "how would you add X?"
8. **Walk one use case as a sequence** and fix what's missing.

Steps 3 and 6 are where the design lives. Steps 1, 2, 4, 5 are clerical — and being clerical about them is exactly what frees your attention for 3 and 6.

---

## 8. The discipline of leaving things out

A diagram with every field and method on it communicates nothing, because the reader can't tell which parts carry the design. It's the same failure as a comment that restates the code.

> **Put on the diagram the things a reviewer would argue about.**

The fee strategy is arguable. The `id` field is not. Ownership is arguable. Getter names are not.

This is a general skill — the same one that makes a good commit message, a good pull-request description, and a good verbal explanation. Selecting what to omit *is* the communication.

---

## 9. What this buys you in an interview

Three concrete things:

- A correct diagram lets the interviewer **see your design in ten seconds** instead of reconstructing it from your speech.
- Arrow types and multiplicity prove you thought about **ownership and invariants** rather than just listing classes.
- The variation-point boxes are a **pre-answer** to the inevitable "how would you extend this?"

And one indirect thing, which matters more: drawing keeps you at design altitude for the first twenty minutes. Candidates who type immediately slide into implementation and never come back up.

---

## ✅ Concept checkpoint
1. Why is a diagram a thinking tool rather than documentation?
2. Give the one-question test for ownership and apply it to: playlist/song, order/line, elevator/door, university/student.
3. Which multiplicity is the one languages *don't* enforce, and what must you do about it?
4. Name three design flaws visible from the silhouette of a diagram alone.
5. What design bug does drawing a sequence diagram reliably catch?
6. What belongs on a diagram, and what should be left off?

Then read the module `README.md`.
