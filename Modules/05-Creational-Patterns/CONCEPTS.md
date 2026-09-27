# Module 05 — Concepts: The Problem With `new`

> Read before the README. No pattern names for the first half — first understand the pressure, then the catalogue will feel inevitable instead of arbitrary.

---

## 1. The mental model: construction is a decision, and decisions want to live in one place

When you write code that creates a concrete object, you have made three commitments at once:

1. **Which** type exists.
2. **When** it comes into being.
3. **How** it is configured.

The trouble is *where* you made them: inside code whose actual job is something else entirely. A checkout flow that constructs a payment gateway has taken a position on vendor choice, credentials, and lifetime — decisions that belong to the people who assemble the application, not to the people who express its rules.

> **Creational patterns exist because knowing *how to make* something is a different responsibility from knowing *what to do with* it.**

That's SRP applied to object construction, and every pattern in this module is a variation on separating those two.

---

## 2. Why hard-coded construction is expensive

Three costs, in increasing order of pain:

**You can't substitute.** Tests must use the real thing. A test that needs a network is slow, flaky, and often impossible in CI. This alone is why the technique exists.

**You can't vary.** Staging wants a sandbox gateway; enterprise customers want a different one; a migration wants both at once. All of those are changes to *which type*, and if the choice is buried in a method body, changing it means editing business logic.

**You can't see the dependencies.** A type that constructs its collaborators internally lies about what it needs. Read its initialiser and you learn nothing; the real requirements are scattered through the method bodies. Newcomers discover them one crash at a time.

That third cost is the sneaky one. An honest initialiser is documentation that the compiler enforces.

---

## 3. The first and most important move: hand it in

Before any pattern, there is a plain technique: **let the caller supply the collaborator**.

It sounds trivial. It is the single highest-leverage habit in this course, and it dissolves most of the problems the patterns address. Once construction happens *outside*, you can substitute, vary, and read dependencies off the signature.

The natural follow-up question — *"but then who constructs it?"* — has an answer: **one place, as close to the program's entry point as possible.** Everything below that place receives what it needs and constructs nothing important.

The intuition pump: a **kitchen**. Ingredients arrive at the door; cooks don't each drive to a farm. There is exactly one place where "where do tomatoes come from" is answered, and it's not in the middle of a recipe.

That one place is the composition root. Its whole job is knowing concrete types. Everything else gets to be ignorant, and ignorance is what makes code reusable.

---

## 4. When handing it in isn't enough

Injection solves "who chooses", but three pressures survive it:

**a) The choice depends on runtime input.** You don't know which parser until you see the file extension. Someone must map input to type, and doing it in one place — rather than at every call site — is the *factory* idea.

**b) The object is genuinely hard to build.** Many parameters, some optional, and rules that span several of them ("a GET request may not have a body"). Those rules can't live in any single property; they need a moment where the whole configuration is inspected before the object exists. That's the *builder* idea.

**c) Several objects must agree with each other.** A dark-theme button beside a light-theme checkbox is a bug that no individual object can prevent, because each is locally correct. Consistency is a property of the *set*, so something must produce the set. That's the *family factory* idea.

Notice that each pressure is a different *reason*, which is why there are several patterns rather than one. Memorising names is useless; recognising which of these three pressures you're under is the whole skill.

---

## 5. The one shared instance, and why it's contentious

Some things genuinely exist once: the file system, the screen, a loaded configuration.

The pattern that expresses this is simple. Its reputation is terrible. Both facts deserve explanation.

**Why it's tempting:** global access is convenient. No plumbing, reachable from anywhere.

**Why that's the problem:** "reachable from anywhere" means *any* code can depend on it without declaring so. Dependencies become invisible, tests share state, and mutation from unknown places makes behaviour irreproducible.

The decisive question is not "is it single?" but:

> **"Is it mutable, and can anyone reach it?"**

A shared *immutable* value is close to harmless — it's a constant. A shared *mutable* object is the strongest coupling in software: every module is connected to every other through it, invisibly. Under concurrency it's also a data race waiting to be discovered.

The mature position: keep the convenience, remove the harm. Let the type be obtainable as a shared instance, but let callers accept it as a parameter with the shared instance as the default. Convenient at the call site, substitutable in a test, and honest about the dependency. That compromise is what a strong answer sounds like — not "singletons are bad".

---

## 6. Building versus constructing

Most objects can be made in one step: you know everything, you say it once. Named parameters with defaults handle this beautifully, and reaching for a pattern here is ceremony.

Two situations break the one-step model:

**Construction is spread over time or code.** A query assembled across several functions; a request that gains headers as it passes through layers. There's no single moment where all arguments are available.

**Validity is a property of the whole.** Individual fields are each fine; the combination is not. Checking that requires a point *after* all fields are set and *before* the object is usable.

Both are the same underlying idea: **separate the accumulation of configuration from the creation of the object**. You get a mutable, permissive thing during assembly and an immutable, validated thing afterwards.

The shape to remember — **mutable builder, immutable product** — is worth generalising beyond this pattern. It's the same reason form state is messy and the submitted record is clean.

---

## 7. Copying as a creation strategy

A different question: what if the cheapest way to make a new object is to duplicate one you already have?

This matters when construction is expensive (parsing, loading, computing a layout) or when the "template" was configured at runtime and can't be expressed as a class.

The conceptual trap is **how deep the copy goes**. If your object holds references to other mutable objects, copying the outer shell gives you two objects sharing insides. Mutating the "copy" changes the "original", and the bug appears far away from the copy.

In Swift this is less common, because value types copy automatically and cheaply. That's worth understanding rather than memorising: the language made copy-on-write the default, so the pattern mostly disappears — and reappears exactly where you chose a reference type, which is exactly where identity mattered. The design question resurfaces as: *does copying this even make sense, given that I chose it for its identity?*

---

## 8. Reuse as a creation strategy

Another angle: what if creating is so expensive that you'd rather not, and the objects are interchangeable enough to recycle?

That's a pool, and it's a genuine design with three unavoidable questions:

1. **What happens when everything is checked out?** Fail, wait, or exceed the limit. Each is defensible; silently exceeding is how you exhaust the resource you were protecting.
2. **How is state cleared between users?** A recycled object carrying the previous user's data is a *security* bug, not a performance detail.
3. **What if a borrower never returns it?** Leak. Either scope the borrowing so returning is automatic, or expire the loan.

You already use a pool every day — reusable cells in a scrolling list — and the "prepare for reuse" callback is question 2 made visible in an API.

---

## 9. Choosing, without memorising

Run these in order. Stop at the first "yes":

1. **Is there exactly one, is it immutable, and is it an OS-level resource?** → a shared instance is fine; still accept it as a parameter.
2. **Does the concrete type depend on runtime input?** → centralise the mapping. Closed set of options → one exhaustive switch in one place. Open set, third parties adding types → a registry keyed by something they supply.
3. **Must several objects match each other?** → produce them together, from one thing.
4. **Are there many optional parameters?** → default arguments first. Only if construction is incremental or validation spans fields do you need a builder.
5. **Is it expensive to make and cheap to copy?** → copy. And check whether a value type gives it to you free.
6. **Is it expensive and recyclable?** → pool, and answer the three questions.
7. **Otherwise** → hand it in. This is the answer most of the time.

That last line is the point of the module. The patterns are for the cases injection doesn't cover — not the default.

---

## 10. The failure mode to watch for in yourself

Creational patterns are the most over-applied family, because they're the easiest to add without changing behaviour — which makes them feel free. They aren't. Each one adds a hop between "I want an X" and "here is an X", and each hop costs a reader.

Signals you've overshot:
- A factory that can return exactly one type.
- A builder for three parameters that are always all supplied.
- A pool for objects that are cheap to create.
- A shared instance that exists so you don't have to pass anything.
- Three different ways to obtain the same object, with three different lifetimes.

The corrective habit: for every creational construct, say out loud what *choice* it preserves. No choice, no pattern.

---

## ✅ Concept checkpoint
1. What three commitments does hard-coded construction make, and why do they belong elsewhere?
2. What is a composition root, and what does the kitchen metaphor capture?
3. Which question decides whether a shared instance is acceptable?
4. Name the two situations where one-step construction genuinely fails.
5. Why does the copy pattern mostly vanish in Swift — and where does it come back?
6. Give the three questions any pool design must answer, and say which one is a security issue.

Then read the module `README.md`.
