# Module 03 — Concepts: Judgment, Not Rules

> Read before the README. SOLID told you how to structure. This module is about **how much** — the taste that stops you from turning every principle up to eleven.

---

## 1. The mental model: every principle is a *force*, not a law

Physics analogy, and it's a good one: a bridge is designed against several forces at once — gravity, wind, thermal expansion. No single force tells you the answer. The design is the point where the forces balance.

Design principles work the same way:

- DRY pulls toward **unification**.
- KISS and YAGNI pull toward **less structure**.
- Decoupling pulls toward **separation** — sometimes directly against DRY.
- Information Expert pulls behaviour **into** entities; SRP pulls it **out**.

A designer who knows one force builds a bridge that stands until the wind blows. **Knowing that the forces oppose each other is the actual skill**, and it's why "apply DRY" is not advice.

The practical consequence: whenever you feel two principles disagree, you haven't misunderstood — you've arrived at the decision. Name both forces out loud, pick a side, say why. That's what senior looks like.

---

## 2. DRY is about knowledge, and almost everyone gets it wrong

The rule is *"every piece of **knowledge** should have one authoritative representation"*. The word people drop is **knowledge**. They hear "never write similar code twice", which is a different and much worse rule.

### The distinction that matters
Two code fragments can be identical today for completely unrelated reasons. An invoice line total and a cart line total may both be `quantity × price`. That's not duplication — it's **coincidence**. They belong to different teams, they'll diverge the first time finance introduces rounding rules or growth introduces promotions, and if you've merged them you'll "fix" it with a boolean flag.

A flag parameter means "this function does two things and the caller picks". You've traded duplication for coupling — and coupling between two teams' rules is far more expensive than two similar lines.

### The test
> **"If this rule changes, must every copy change too?"**
> Yes → real duplication, extract it. No → coincidence, leave it alone.

### The line worth memorising
> **Duplication is cheaper than the wrong abstraction.**

Because duplication is *visible* and *local* — you can find it and fix it. A wrong abstraction is invisible and *global*: three teams have built on it, it has a plausible name, and correcting it means touching all three.

### Rule of three
Two occurrences: wait. At two you're guessing the shape. At three you can *see* what's common and what's incidental, and the abstraction you extract is the right one.

---

## 3. KISS and YAGNI: two different arguments against the same thing

They're often quoted together, but they answer different objections.

**KISS** is about **now**: given what you're building, is this the simplest structure that does it? The failure it prevents is cleverness — generic machinery for a problem that isn't generic, indirection you can't justify, an event bus where a function call would do.

**YAGNI** is about **later**: are you building for a requirement that exists, or one you imagined? The failure it prevents is speculation — the plugin system with one plugin, the multi-currency support for a single-country product, the five-environment configuration for two environments.

### Why speculation is so expensive
The hour of writing isn't the cost. The costs are:
- Permanent maintenance of code nobody asked for.
- An abstraction **shaped by a guess**, which is almost never the shape the real requirement wants.
- Other people building on the guessed shape, so by the time reality arrives you're not deleting one file — you're renegotiating with three teams.

### The exception that stops YAGNI being an excuse
Some decisions are cheap now and brutal later. Missing identifiers on persisted records. Baking single-tenancy into a schema. Ignoring localisation entirely. Storing money as floating point.

The discriminator is: **is this cheap to retrofit?** Cheap to add later → defer with confidence. Expensive or impossible → decide now, even without a current requirement. That's not a contradiction of YAGNI; it's the same cost calculation applied honestly.

---

## 4. Law of Demeter: stop navigating other people's insides

Written formally it sounds like bureaucracy. The intuition is simple:

> **Talk to your friends, not to your friends' friends.**

When you write a chain that walks through an object graph, you have silently declared a dependency on **every type in that chain and the shape of the relationships between them**. A rename three levels away breaks you, and you never agreed to that.

### Why the mutating version is much worse than the reading version
Reading through a chain is fragile. *Writing* through one is dangerous, because you've bypassed every guard between you and that field. The object that owned the invariant never got a say. Module 01's "promise" is broken from the outside, and the type that made the promise can't even detect it.

### The nuance that stops it becoming silly
Chains of *transformations* are not violations. Filtering a collection then mapping it then sorting it is not navigating someone's private structure — each step hands back the same kind of thing, and you're expressing a pipeline, not reaching through a wall.

The difference: **are you traversing a structure that belongs to someone else, or transforming a value that belongs to you?**

### The honest cost
Applied everywhere, Demeter produces forests of one-line forwarding methods. That's real bloat. Apply it where the chain **crosses a boundary you expect to change**, and especially wherever you would otherwise mutate through it.

---

## 5. Tell, Don't Ask: where behaviour wants to live

The symptom is a three-step dance in a caller: read a property, decide something, write a property back.

Every time that happens, a rule that *belongs to the object* is living outside it. And because it's outside, it's duplicated — the next caller writes their own version, slightly differently, and now there are two rules with one name.

> **Ask an object for data when you want to display it. Tell it what you want done when you want a decision made.**

### The connection to Module 01
This is the "promise" idea again, from the caller's side. If an object owns an invariant, it must own every operation that could threaten it. The moment a caller is making that decision, the object isn't really promising anything — it's hoping.

### The opposing failure, so you don't over-rotate
Push this too far and you get objects that do everything, which collides with SRP. And some designs *deliberately* separate data from behaviour: DTOs at boundaries, read models for queries, value types that are genuinely just data. Those are fine — the smell is when **domain rules** end up in services while the entities are empty shells.

The name for that failure is **anemic domain model**: procedural code wearing object-oriented syntax. Classes with only getters and setters, and all the meaning in `SomethingService`.

---

## 6. Encapsulate what varies: the master principle

If you extract one sentence from this entire course, extract this one:

> **Find what changes, separate it from what doesn't, put a boundary between them.**

Nearly every design pattern is this sentence applied to a specific *kind* of change:

- The thing that varies is an **algorithm** → you get Strategy.
- …**which concrete type to create** → Factory.
- …**optional layers of behaviour** → Decorator.
- …**behaviour across a lifecycle** → State.
- …**who needs to know** → Observer.
- …**who handles a request** → Chain of Responsibility.
- …**one step of an otherwise fixed process** → Template Method.
- …**an awkward external interface** → Adapter.

This is why Module 08 insists you say *"the ___ varies by ___"* before naming a pattern. Say the sentence and the pattern is usually implied. Reach for the pattern first and you'll force the problem into a shape you already know.

---

## 7. Program to an interface: what "interface" really means

The slogan says depend on what a thing *does*, not what it *is*. In Swift, "interface" is broader than "protocol":

- A **protocol** — when you need a named concept, several related operations, or conformance on types you don't own.
- A **function type** — when the dependency is genuinely one operation. A one-method protocol is often a closure wearing formalwear.
- An **enum** — when the set of variants is closed and you want the compiler to enforce exhaustiveness.

Choosing the smallest of these that expresses the idea is itself a design decision, and picking the protocol every time is the same reflex as picking inheritance every time.

---

## 8. Inversion of control: who is driving?

In a script, your code calls the library. In a framework, the framework calls your code. That flip — "don't call us, we'll call you" — is what makes a stable skeleton with pluggable parts possible.

You already live inside it: you don't call the UI run loop, it calls your lifecycle methods. You don't call `body`, the framework does.

The design insight to carry away: **the party that owns the sequencing is the party that stays stable.** If you own the order of steps and let someone plug into individual steps, you can change the steps' implementations freely. If everyone owns their own sequencing, there's no shared skeleton to rely on.

---

## 9. GRASP: the missing half of SRP

SOLID says a class should have one responsibility. It doesn't say **which**. GRASP answers that, and two of its principles do most of the work:

**Information Expert** — give a responsibility to the type that already holds the data. A cart knows its items, so the cart computes its total. This is the direct antidote to anemic models: behaviour follows data, not the other way round.

**Pure Fabrication** — when a responsibility belongs to no real-world noun, invent a type for it rather than jamming it onto an entity. Repositories, engines, dispatchers, mappers: none are domain nouns, all are legitimate. This is the escape hatch that stops Information Expert from turning entities into God Objects.

Those two in tension — *push behaviour onto data*, but *invent a type when it spans several* — is most of the judgment in day-to-day modelling.

The other three worth knowing: **Creator** (the thing that contains or initialises B should create B — and when nothing qualifies, that's when a factory earns its keep), **Controller** (a system event is handled by a use-case type, not by a UI type — this is why checkout logic doesn't belong in a view controller), and **Low Coupling / High Cohesion** as the tie-breakers when two designs are otherwise equal.

---

## 10. The thinking procedure

For any design you're reviewing — including your own, ten minutes after writing it:

1. **Is any rule written down more than once?** Check whether it's the *same* rule or a coincidence.
2. **Is there any structure I can't justify with a real requirement?** Delete it.
3. **Am I reaching through objects?** Especially to mutate.
4. **Is any caller reading, deciding, and writing back?** Move the decision.
5. **What varies here?** Say the sentence. If you can't, stop abstracting.
6. **Does behaviour sit with the data it needs?** If not, why not — and is a fabricated type the right answer?
7. **Which two principles are in tension in this design?** Name them and pick a side deliberately.

Step 7 is the one that separates people who've read the principles from people who use them.

---

## ✅ Concept checkpoint
1. Give an example of duplicated code you should **not** unify, and say what the merge would cost.
2. Distinguish KISS and YAGNI in one sentence each, then give the YAGNI exception.
3. Why is mutating through a chain worse than reading through one?
4. What is an anemic domain model, and which principle diagnoses it?
5. Say the "master principle" from memory and map it onto four patterns.
6. When does Pure Fabrication rescue Information Expert?

Then read the module `README.md`.
