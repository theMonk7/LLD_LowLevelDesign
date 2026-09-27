# Module 01 — Concepts: What an Object Really Is

> Read this before the README. Almost no code here — this is the intuition the syntax hangs on.

---

## 1. The mental model: an object is a *promise*, not a container

Most people are taught that an object is "data plus functions". That definition is true and useless, because it doesn't tell you how to design one.

Here is the model that does:

> **An object is a promise that some rule will always hold.**

A `BankAccount` isn't "a number and some methods". It's a promise: *the balance will never go negative*. A `Username` isn't "a string". It's a promise: *if this value exists, it's between 3 and 20 characters*. A `Reservation` promises *this seat is held until this instant, for this person*.

Once you think of types as promises, the design questions answer themselves:

- **What should be private?** Anything that, if outsiders could change it, would let them break the promise.
- **What methods should exist?** Exactly the operations that can be performed *without* breaking the promise.
- **Where does validation go?** At the boundary where the promise begins — the initialiser, or the method that changes the guarded state.
- **Why is a God Object bad?** It's promising nine unrelated things, so no single reader can hold all nine in their head, and every new method risks breaking one.

A type that promises nothing is not an object; it's a bag. Bags are fine (DTOs are bags), but they carry no design value — you can't reason about them, only about everyone who touches them.

---

## 2. Two kinds of things: values and entities

This is the distinction that Swift makes you confront, and it's genuinely the most useful modelling idea in the whole module.

**A value is something you compare by its contents.**
₹500 is ₹500. There is no "this particular five hundred rupees" — two notes of equal value are interchangeable. Dates, coordinates, colours, email addresses, money, a chess move: all values.

**An entity is something you track through time.**
Your bank account is *yours* even as its balance changes. A parking spot is that spot even when a different car is in it. An order is the same order after it ships. Identity survives change of content.

The test, which you should run on every noun in a requirement:

> **"If I have two of these with identical fields, are they the same thing, or two different things?"**

Identical → value. Different → entity.

Why this matters more in Swift than in Java: Swift gives values *different runtime semantics*. A value is copied when you hand it around, so nobody else can change yours. An entity is shared, so changes are visible to everyone holding a reference — which is exactly what you want for an account, and catastrophic for money.

The bug this prevents is real and common: you put a "thing with state" in an array, pull it out, change it, and the change vanishes — because you were holding a copy. That's not a language quirk; it's the language telling you that you modelled an entity as a value.

---

## 3. Encapsulation is not "use private". It's *who is allowed to break this?*

The textbook line — "hide your data" — makes encapsulation sound like politeness. It isn't. It's about **blast radius**.

Think of state as something with a *guard*. The guard's job is to reject operations that would put the object in a nonsense condition: a negative balance, a seat booked by two people, an order with no lines.

If the state is public, there is no guard — or rather, the guard is *every caller*, and callers forget. The rule is now duplicated across the codebase, and it will drift: the checkout screen checks it, the admin importer doesn't, and production discovers the difference.

So the real question of encapsulation is:

> **"If someone could set this field directly, what nonsense could they create?"**

If the answer is "nothing" (a `Point`'s `x`), public mutability is fine. If the answer is "a negative balance", the field belongs behind a method that enforces the rule.

### The intuition pump
An encapsulated object is a **vending machine**, not a shelf.

On a shelf, anyone can take anything, put anything back, and rearrange it. In a vending machine there are exactly three things you can do — insert, select, refund — and no sequence of them leaves the machine in an impossible state. The machine is *harder to use* and *impossible to corrupt*. That trade is encapsulation.

---

## 4. Abstraction is about *what the caller is allowed to know*

Encapsulation hides data. Abstraction hides **decisions**.

When you write "this thing can charge a payment", you've made a promise about capability while keeping every decision — which gateway, which retry policy, which signing algorithm — private. A caller written against that promise keeps working when all those decisions change.

The test for a real abstraction:

> **"Could I write a second, genuinely different implementation without changing the description?"**

If your "payment protocol" mentions Stripe's API version, the answer is no — you've written down one implementation and given it a fancy name. That's a *leaky* abstraction, and it's worse than none, because it looks like a seam and isn't.

The other failure is abstraction with nothing behind it: a protocol with exactly one conformer, no test double, and no second implementation in sight. That's not abstraction, it's indirection — a redirection sign pointing at one shop.

**Abstraction earns its cost when it buys you a choice.** No choice, no abstraction.

---

## 5. Inheritance: a promise about *substitutability*, not about reuse

The most expensive misunderstanding in object-oriented programming is that inheritance is a code-reuse mechanism. It isn't — or rather, it is, the way a marriage is a cost-sharing arrangement. Technically true, wildly under-describing the commitment.

Inheritance says: **anywhere the parent works, the child works, and the caller doesn't need to know which it got.**

That's a promise about behaviour, forever, made on behalf of code you haven't written yet. It's enormous. And the language checks almost none of it — the compiler verifies method signatures, not meanings.

So before writing "B is a kind of A", ask:

> **"Is there any caller of A who would be surprised by B?"**

Surprise = broken promise. An override that throws where the parent didn't. A subtype that requires setup the parent didn't. A subclass that makes a "write" do nothing.

The famous square/rectangle example exists to make one point: **"is-a" in the real world is not "is-a" in code.** A square *is* a rectangle mathematically. But a caller who sets width and height independently — which every rectangle permits — gets nonsense from a square. The hierarchy is wrong not because the taxonomy is wrong, but because the *contract* is.

### When inheritance is genuinely right
Rare, and worth naming: when you need shared **stored state** plus a **fixed skeleton** where subtypes fill in steps, and every subtype honours the parent's promises. That's it. Everything else composes better.

---

## 6. Polymorphism is the point of all of it

Here's the payoff that makes the previous five sections worth the trouble.

> **Polymorphism means the caller stops caring.**

A function that sums areas doesn't know what shapes exist. Add a hexagon and it keeps working. A payroll loop doesn't know what employee types exist. A renderer doesn't know what nodes exist.

And notice what *disappears* when polymorphism is present: the type checks. No `if it's a circle... else if it's a square...`. That chain is the signature of missing polymorphism, and it's the thing that makes adding a case expensive — because the chain is never in one place. It's in three files, and you'll find the third one in production.

So a practical heuristic you can apply immediately:

> **Every `if`/`switch` on "what kind of thing is this" is a design smell worth one minute of thought.**

Sometimes the answer is "it's fine, the set is closed and the compiler checks it". Often the answer is "that's a missing abstraction".

---

## 7. Composition: build things out of parts, not out of ancestors

Two ways to give an object behaviour it doesn't have:

- **Inherit it** — become a specialised version of something that has it.
- **Hold it** — keep a collaborator and delegate.

Inheritance fixes the relationship at compile time, one parent only, and couples you to the parent's internals. Composition lets you choose at runtime, combine several, swap one for a test double, and change one part without recompiling reasoning about the others.

### The intuition pump
Inheritance is **genetics** — you get whatever your parent had, forever, and you can't change parents.
Composition is **equipment** — you pick up what you need, put it down when you don't, and borrow someone else's for a test.

The combinatorial argument is the decisive one. Three optional behaviours produce eight combinations. With inheritance that's up to eight classes; with composition it's three small parts and a container. At five behaviours, inheritance has thirty-two classes and composition still has five parts.

This is why the advice "prefer composition over inheritance" survived thirty years. Not because inheritance is evil — because composition scales with the number of *behaviours*, and inheritance scales with the number of *combinations*.

---

## 8. Coupling and cohesion: the two words you'll use to justify everything

These are the measuring instruments. Every design argument you make for the rest of your career reduces to one of them.

**Coupling** = how much one thing must know about another to work.
**Cohesion** = how much the parts of one thing belong together.

You want **low coupling between** things and **high cohesion within** them.

### Why low coupling
Coupling is the wire along which change travels. Two modules coupled tightly means a change in one *propagates*. Loosen the coupling and the change stops at the boundary. That's the entire benefit: **change containment**.

The strongest form of coupling is shared mutable state — a global that anyone can change — because now every module is coupled to every other module *invisibly*. The weakest is "I only know an abstract capability", because then the only thing that can break me is a change in the promise itself.

### Why high cohesion
Cohesion is about *comprehension*. A type that does one thing can be understood in one sitting and changed with confidence. A type that does four can't — and worse, four different people have reason to edit it, so it's permanently in flux and permanently conflicted.

The practical detector: **name the type honestly**. If the name needs "and", or if you reach for `Manager`, `Helper`, `Util`, `Handler` — words that mean "stuff" — cohesion is low. Those names are what you use when there's no single responsibility to name.

---

## 9. How to think in Swift specifically

Swift changes the default answers in ways that matter for design:

**Start with a value type.** Values can't be aliased, can't be mutated behind your back, and are trivially safe to share across threads. Reach for a class when you need *identity* or *shared mutable state* — and notice that "shared mutable state" is exactly the thing that makes concurrency hard, which is why the language nudges you away from it.

**Start with a protocol, not a base class.** A type can conform to many protocols but inherit from one class. Small capability-shaped protocols compose; deep hierarchies don't. And protocols work on values, which base classes can't.

**Prefer making illegal states unrepresentable over validating them.** Two booleans can express four states, and often only three are legal. An enum with three cases can't express the fourth at all. This is the strongest form of the "promise" idea in section 1: instead of *checking* that the promise holds, arrange for breaking it to be *unsayable*.

**Let the compiler enforce closed sets.** When something genuinely has a fixed set of cases, an enum plus an exhaustive switch means the compiler tells you every place to update when a case is added. That's better than a protocol. The skill is knowing whether the set is closed — and that's a question about the product, not about the code.

---

## 10. The thinking procedure (use this on any requirement)

1. **List the nouns.** Cross out the ones that are attributes ("duration", "name") or noise ("the system").
2. **For each surviving noun, ask: value or entity?** Compare-by-content, or track-through-time?
3. **For each noun, ask: what promise does it make?** That's your invariant. It tells you what to hide.
4. **List the verbs. Assign each to the noun that holds the data it needs.** If no noun fits, you've found a missing type — often a service or a policy.
5. **For each type, ask: what would make me edit this?** More than one answer means split it.
6. **For each relationship, ask: does this thing need to *be* that, or just *use* it?** "Use" is composition, and it's almost always the answer.
7. **Look for the type checks.** Every `switch` on kind is a candidate for polymorphism.
8. **Ask what varies.** Put a name on it. That's your first abstraction — and if nothing varies, you're done.

Do this on paper, out loud, before any syntax. The design is finished when you can say what each type promises and why it exists. The code after that is transcription.

---

## ✅ Concept checkpoint
Answer in your own words:
1. What is an object a *promise* about, and how does that change what you make private?
2. Give the one-question test for value vs entity, and apply it to: `Money`, `ParkingSpot`, `Move`, `ChatMessage`, `UserSession`.
3. Why is a protocol with one conformer and no test double usually not an abstraction?
4. Why is inheritance a promise to code that doesn't exist yet?
5. Why does composition scale with behaviours while inheritance scales with combinations?
6. What does an `if x is TypeA` chain usually tell you is missing?

Then read the module `README.md`.
