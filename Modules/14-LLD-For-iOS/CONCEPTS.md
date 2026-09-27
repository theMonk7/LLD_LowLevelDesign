# Module 14 — Concepts: Architecture Is Just LLD With Layers

> Read before the README. Everything you've learned applies here — the only new idea is that boundaries can exist between *groups* of types, not just between types.

---

## 1. The mental model: an app is rules surrounded by adapters

Strip an app down and there are only three kinds of code:

- **Rules** — what the product means. A user can borrow three books; an order over ₹999 ships free; a session expires after thirty minutes.
- **Mechanisms** — how things technically happen. HTTP, a database, the keychain, a push token.
- **Presentation** — how a human sees and drives it.

> **Rules are the only part that's actually yours. Everything else is replaceable, and should be arranged so that it is.**

That sentence dictates the whole layering. Rules must not know about HTTP, because HTTP is an accident of this decade. Rules must not know about the screen, because the screen changes every redesign. Rules sit in the middle, knowing nothing, and everything else attaches to them.

The arrows all point *inward*, toward the rules. That's dependency inversion (Module 02) applied at the scale of whole layers instead of single types.

---

## 2. Why the "massive controller" happens, and what it really is

Nobody sets out to write a two-thousand-line screen class. It happens because the framework hands you an object that is already at the centre of everything: it owns the view's lifetime, receives the user's taps, and has a convenient place to put "just one more thing".

So code accretes there by gravity, not by decision. And what accumulates is all four of: presentation, rules, mechanism, and navigation.

> **The massive controller is not a size problem. It's four responsibilities sharing a file.**

Which means splitting it by line count achieves nothing. The fix is to name the four responsibilities and give each one a home. Every architecture in the catalogue is a different opinion about where those homes are — which is why arguing about architecture names, rather than about responsibilities, is a waste of an interview.

---

## 3. What a presentation object is actually for

The layer between the screen and the rules has one job, and it's easy to state:

> **Turn domain facts into exactly what the view must render, and turn user intent into domain operations.**

Two implications follow, and they're the ones people get wrong.

**Formatting belongs here, not in the view.** "₹1,240.00" and "Member since March 2024" are *decisions* — about locale, currency, precision, phrasing — and decisions should be testable. A view should receive strings it renders verbatim.

**It must not know the framework.** The test is blunt and worth applying literally: does this file import the UI framework? If yes, it isn't a presentation *layer*, it's more view. The value of the separation is that this object can be exercised without a screen, and that value evaporates the moment it touches a view type.

---

## 4. Screen state is a state machine, and booleans are a trap

A screen is almost never just "has data". It's idle, loading, loaded, empty, failed, refreshing-while-showing-stale-content.

Model that with independent flags and you can express combinations that make no sense: loading *and* failed *and* holding data. The compiler permits it, so eventually you'll ship it — and the symptom is the spinner still visible behind the error message.

> **One value with several cases makes the impossible states unrepresentable; several booleans make them inevitable.**

This is Module 01's "make illegal states unrepresentable" arriving where it does the most visible good. It also gives you a checklist: enumerate the cases and you've enumerated what the screen must handle, including the empty state everyone forgets.

---

## 5. The boundary where the outside world stops

Network responses are shaped by someone else's decisions: their field names, their optionality, their date formats, their compatibility constraints. If those shapes reach your rules, then their decisions become your constraints forever.

So there's a wall, and the wall has a translator in it: a type that mirrors the wire exactly, and a conversion that produces your domain type.

Three things happen at that wall, and each is worth doing deliberately:

- **Optionality ends.** "The server might not send a name" becomes either a valid name or a typed failure. After the wall, nobody writes a fallback for it.
- **Vocabulary changes.** Their names become yours. A rename on their side touches one file.
- **Failure becomes typed and local.** "This row was malformed" is a value you can decide about — skip the row, fail the page — rather than a crash three layers up.

> **Decoding straight into your domain type saves ten minutes and costs you the boundary.**

---

## 6. Where cross-cutting behaviour goes

Authentication, retries, logging, caching, metrics: each applies to *many* operations and belongs to *none* of them.

Put them inside the operation and you've mixed responsibilities and duplicated the concern. Put them in the caller and you've duplicated it differently. The answer is the layering idea from Module 06: each concern becomes a thing that satisfies the same contract and delegates inward.

What this buys in an app specifically:

- Which concerns are active becomes **configuration**, decided in one place at startup — so a debug build can add logging and a test can remove retries without touching any feature code.
- Each concern is **testable alone**.
- The core operation stays **about its job**.

And the same caution applies: order is semantics, and depth has a debugging cost. Three layers is usually the sweet spot.

---

## 7. Navigation is a responsibility too

Screens that present other screens know about each other. That coupling is invisible until you need to reorder a flow, deep-link into the middle of it, or reuse one screen in a different journey — and then it's everywhere.

The separation: a screen announces *what happened* ("the user finished checkout"), and something above it decides *what happens next*.

> **Screens report intent. Something else owns the sequence.**

This is the Hollywood principle (Module 03) applied to flow, and it's the same reasoning as policy/mechanism (Module 13): the *what* is stable, the *sequence* is where product churn lands.

The honest counterweight: managing the lifetime of these flow objects is fiddly, and modern declarative navigation covers much of the need natively. Know the idea and know when it's overhead.

---

## 8. The five things that make code untestable

Almost every "I can't test this" reduces to one of five ambient dependencies:

- the current time
- randomness and identifier generation
- the network
- persistent storage and preferences
- the main thread / scheduling

Each is an **input the code took without declaring**. And each has the same fix: make it a parameter.

> **If you can't test it, find the hidden input.**

Worth memorising as a list, because it converts a vague complaint into a five-item checklist. It's also the honest answer to "how would you make this testable?" — a question that is, nine times out of ten, asking whether you reach for dependency inversion by reflex.

---

## 9. Concurrency arrives in apps as *duplicate work*

Server-side concurrency is about correctness under contention. In apps it more often shows up as **redundant work**:

- Sixty list cells request the same image.
- Three screens each notice the token expired and each refresh it.
- A user taps a button twice and two orders are created.

The shape is identical to Module 09's check-then-act: several callers check "is this already happening?", all see "no", and all start it.

The fix is also identical: record the *in-flight* attempt before starting the slow work, so later arrivals find it and wait for the same result. One download, one refresh, one order.

> **Deduplicate by the work's identity, not by locking the caller.**

This one idea — request coalescing — covers image loading, token refresh, and double-submit protection, which is why it's worth recognising as a single concept rather than three tricks.

---

## 10. Choosing an architecture, and how to say it

The catalogue differs mainly on **how many roles per screen** and **how strictly boundaries are enforced**. More roles means clearer boundaries and more files; fewer means less ceremony and more discipline required.

The choice is driven by context, not by fashion:

- **How many people, and do they collide?** More teams → harder boundaries, and preferably at the *module* level rather than per screen.
- **How long will it live?** Long-lived code pays back structure; a three-month prototype doesn't.
- **How much of it is rules versus screens?** A rules-heavy product earns a real domain layer; a thin client over an API mostly doesn't.

The answer that scores is a choice *with a condition attached*:

> *"I'd use [X] because [contextual reason]. If [condition] changed, I'd move to [Y]."*

That demonstrates you're reasoning about the situation rather than defending a preference. And when asked "why not [the heavier option]?", don't attack it — name what it buys and say why that isn't worth its cost here.

---

## 11. The thinking procedure for an app design question

1. **Sort the code into rules, mechanisms, presentation.** Everything belongs to one.
2. **Point all dependencies at the rules.** Contracts are owned by the rules and implemented outward.
3. **Find the boundary where external shapes stop** and put a translator in it.
4. **Model each screen as a state machine** with one value, not several flags.
5. **Name the cross-cutting concerns** and make each a layer configured at startup.
6. **Decide who owns the sequence** between screens.
7. **List the ambient dependencies** and make each an explicit input.
8. **Find the duplicate-work hazards** and deduplicate by work identity.
9. **Choose the structure for the team and lifetime you actually have** — and say the condition that would change your mind.

---

## ✅ Concept checkpoint
1. Which of the three kinds of code is "yours", and what does that imply about arrow direction?
2. Why is the massive controller not a size problem?
3. Give the blunt test for whether a presentation object is really separated.
4. Why do independent boolean flags on a screen guarantee an eventual bug?
5. Name the three things that happen at the wire boundary.
6. List the five ambient dependencies that make code untestable.
7. Explain request coalescing and name three situations it covers.

Then read the module `README.md`.
