# Module 07 — Concepts: Who Decides, Who Knows, Who Acts

> Read before the README. Behavioural patterns are about the *flow of responsibility* between objects. Get the flow right and the code writes itself.

---

## 1. The mental model: behaviour is a thing you can move

A beginner thinks of behaviour as something a class *has*. A designer thinks of behaviour as something that can be **relocated** — extracted into its own object, handed around, stored, queued, swapped at runtime, or given to a different owner entirely.

> **Every behavioural pattern is an answer to: "this decision is in the wrong place — where should it live instead?"**

Once behaviour is an object rather than a method body, remarkable things become available: you can store it, pass it, replace it, undo it, log it, defer it, or let someone else choose which one runs. Most of this module is exploring what becomes possible after that move.

---

## 2. The first question: does this vary per *call*, or per *lifetime*?

Two patterns look nearly identical in code, and this question separates them.

**Varies per call, chosen from outside.** A calculation that's done differently depending on context — a plan, a configuration, a caller's preference. Whoever sets it up picks one, and it stays until someone picks another. The object being configured doesn't care which; it just delegates.

**Varies over the object's own lifetime, chosen by itself.** A machine that behaves differently when idle, dispensing, or out of stock. Nobody hands it a behaviour; it *moves* between behaviours as events happen, and each behaviour knows which one comes next.

The distinguishing questions:
- **Who chooses?** Outside → configurable algorithm. The object itself → lifecycle behaviour.
- **Do the alternatives know about each other?** Independent → algorithm. Each knows its successors → lifecycle.

That's the distinction. Not the class diagram, which is the same.

### Why the lifecycle version matters so much in practice
Any type with a `status` field is a state machine that someone forgot to model. The symptom is unmistakable: **every method begins by checking the same field**, and each check has slightly different branches. Each new status multiplies the branches, and eventually a combination is wrong in one method and right in the other four.

Modelling it properly means each state answers for itself: given this state, what does each event do, and where does it go next? Adding a state becomes additive rather than an edit to five methods.

And it is *the* interview tell. The follow-up "what happens if you press select while it's dispensing?" is trivially answerable when each state owns its rules, and a guessing game when the logic is spread across `if`s.

---

## 3. The second question: does anyone else need to know?

Some designs need one object to inform others that something changed — without knowing who they are, how many there are, or what they'll do.

The key property is **ignorance in the right direction**: the thing being observed must not know its observers. The moment it does, you've coupled the source of truth to every consumer, and adding a consumer means editing the source.

### The three things that break every naive implementation
Worth knowing before you write one, because they're where the bugs live:

**Lifetime.** If the notifier holds observers strongly, it keeps them alive. Screens that should have been released stay in memory and keep reacting to events. The fix — hold them weakly — is easy; *remembering* is the hard part.

**Re-entrancy.** An observer may unsubscribe (or subscribe something new) *while being notified*. If you're iterating the live collection while it mutates, you crash or skip someone. The fix is to iterate a snapshot.

**Ordering and duplication.** Is notification order guaranteed? What if someone subscribes twice — do they get two calls? These are design decisions; the failure is not deciding, and then depending on whatever the implementation happened to do.

### The related-but-different shape
When many objects all need to coordinate with *each other* — ten form controls that enable, clear and validate one another — broadcasting isn't the answer. Point-to-point links between N things is N² relationships, and every new control touches all the others.

Route it through a single coordinator instead. Now each component knows one thing, and the interaction rules live in one readable place. The risk is that the coordinator accumulates every rule in the system and becomes the God Object you were avoiding — so the discipline is: it coordinates, it doesn't decide business policy.

---

## 4. The third question: does this request need a life of its own?

Normally a request is a method call: it happens, it returns, it's gone. Sometimes that's not enough. You want to:

- undo it, so you must know how to reverse it
- queue it, so it must be storable
- retry it, so it must be repeatable
- schedule it, so it must be separable from the moment of asking
- audit it, so it must be describable
- send it elsewhere, so it must be serialisable

All six need the same thing: **the request must become an object** rather than a transient call.

Once it is, undo becomes natural — each request knows how to reverse itself. And here the two strategies for reversal are worth understanding as a pair:

**Reverse by inverse.** Know the opposite operation. Cheap — you store only what's needed to undo. Only possible when an inverse exists: appending text can be undone by removing that much.

**Reverse by snapshot.** Remember the state before. Always works, costs memory. Necessary when the operation destroys information: you cannot recover mixed case from text that has been uppercased.

Real editors use both: inverses for keystrokes, snapshots occasionally so undo doesn't have to replay from the beginning. Knowing *why* both exist is better than knowing either name.

### The detail that separates working undo from broken undo
After an undo, doing something new must **discard the redo history**. Otherwise redo replays work that no longer makes sense on top of the new action. Every undo system that feels haunted is missing that one line.

---

## 5. The fourth question: who should handle this?

Sometimes the answer isn't known at the call site. Several candidates could handle a request, and which one does depends on the request itself: an expense by amount, an HTTP request by whether auth passes, an event by whether the current view consumes it.

Give the candidates an order and let the request travel along it. Two flavours, and you should say which you're building:

- **First capable handler wins, then stop.** Approval chains, exception handling.
- **Everyone runs, unless someone rejects.** Middleware pipelines, filters, validation.

The question that catches people: **what happens when nobody handles it?** Falling off the end silently is the classic bug — a request vanishes and nothing logs it. Decide: a default handler, an explicit error, or a recorded drop.

---

## 6. The fifth question: is the *shape* fixed but the *steps* variable?

Some processes always have the same skeleton — read, parse, validate, save; or validate, price, tax, receipt — and only one step differs per case.

Two ways to express it, and they're the composition/inheritance choice again:

- **Fix the skeleton in one place, let the varying step be supplied by a subtype.** The framework calls you.
- **Fix the skeleton in one place, let the varying step be a collaborator you hold.** You call the thing you were handed.

The first is tighter and gives you shared stored state; the second is more flexible and testable. Same structural idea, and the choice is the same one from Module 01 §7.

The failure mode here is hook proliferation: a skeleton with nine overridable steps is not a shared process, it's a maze. If you're past about three, the "skeleton" isn't real — you've discovered that these cases don't actually share a process.

---

## 7. The sixth question: how do people walk over this?

Two ideas hide in "iterate".

**Hide the storage.** Callers shouldn't need to know whether you're backed by an array, a tree, or a paginated remote endpoint. They ask for the next element; you decide what that means.

**Support several orders.** A tree has at least two sensible traversals. Both should be available without the tree exposing its nodes, and without one traversal being privileged.

The second is the real design content. In a language with a built-in sequence abstraction, "implement iterator" mostly means "conform to the language's sequence protocol" — and the payoff is enormous, because every generic algorithm in the standard library immediately works on your type. Recognising that you should plug into the language's existing abstraction rather than invent a parallel one is itself a design judgment.

---

## 8. The seventh question: which axis is going to grow?

There's a deep symmetry worth understanding, because it recurs everywhere.

Consider a set of types and a set of operations over them.

- **Ordinary polymorphism** (each type implements each operation) makes **adding a type** cheap — write one new type — and **adding an operation** expensive, because every type must gain a method.
- **The inverted arrangement** (each operation knows every type) makes **adding an operation** cheap — write one new operation — and **adding a type** expensive, because every operation must handle it.

Neither is better. They are **mirror images**, optimised for opposite directions of growth. So the question is empirical:

> **Which is more likely: new kinds of things, or new things to do with them?**

Application code usually grows types (new payment methods, new vehicle kinds) → ordinary polymorphism. Compilers and document processors usually grow operations over a stable set of node types → the inverted arrangement.

In a language with exhaustive pattern matching over closed sets, the inverted arrangement is often just a switch statement — which also gives you a compiler error listing every operation to update when a type is added. Knowing that the language feature *is* the pattern is more useful than knowing the pattern's name.

---

## 9. The small one that prevents a lot of noise

When a collaborator is optional, the naive approach makes it optional at the *type* level, and every call site grows a check. Ten call sites, ten checks, and one of them will be forgotten.

The alternative: supply an implementation that does nothing, successfully. Absence becomes a behaviour rather than a condition, and the checks disappear.

The boundary of the idea: only where doing nothing is genuinely harmless. Analytics that no-ops is fine. A payment processor that silently "succeeds" is a catastrophe. The question is always *"is silence an acceptable outcome here?"*

---

## 10. The thinking procedure

Read the requirement and listen for the shape:

1. "…can be calculated in different ways" → an algorithm someone chooses from outside.
2. "…behaves differently depending on its status" → a lifecycle; model the states.
3. "…notify everyone interested" → observation, with the three hazards handled.
4. "…undo / queue / retry / schedule / audit" → the request becomes an object.
5. "…try A, then B, then C" → an ordered set of handlers; decide the no-handler case.
6. "…always these steps, but one differs" → a fixed skeleton with a variable step.
7. "…traverse it in several ways" → plug into the language's sequence abstraction.
8. "…these N components all affect each other" → one coordinator, no business rules.
9. "…snapshot and restore" → state capture, and ask what it costs in memory.
10. "…we keep adding operations to a stable set of types" → invert the axis.
11. "…this dependency is optional" → a do-nothing implementation.

Then always ask the counter-question: *what's the simplest thing that satisfies this?* Often it's a function, a closure, or an enum — and that's a better answer than the pattern.

---

## ✅ Concept checkpoint
1. Give the two questions that distinguish a configurable algorithm from lifecycle behaviour.
2. Name the three hazards in a naive observation mechanism and the fix for each.
3. Name the two ways to reverse an operation and when each is forced.
4. Why must a new action discard redo history?
5. State the symmetry between growing types and growing operations, and how to choose.
6. When is a do-nothing implementation dangerous?

Then read the module `README.md`.
