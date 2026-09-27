# Module 03 — The Other Design Principles

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** the judgement layer. SOLID tells you *how* to structure; these tell you **how much** structure, and **where responsibility belongs**.

Most bad LLD code fails one of these, not SOLID. Over-abstraction fails KISS and YAGNI. Fragile call chains fail Demeter. Anemic models fail Tell-Don't-Ask and Information Expert.

---

## 1. DRY — Don't Repeat Yourself

> **Every piece of *knowledge* must have a single, unambiguous, authoritative representation in a system.**

The original phrasing says *knowledge*, not *code*. That distinction is the whole principle.

### What DRY actually forbids
Duplicating a **rule**. If "a username must be 3–20 chars, alphanumeric" appears in the signup screen, the profile screen and the admin importer, then a rule change means three edits and one will be missed.

```swift
// ❌ the rule lives in three places
if name.count >= 3 && name.count <= 20 && name.allSatisfy(\.isLetter) { ... }

// ✅ the rule lives once
struct Username {
    let value: String
    init?(_ raw: String) {
        guard (3...20).contains(raw.count), raw.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        value = raw
    }
}
```

### What DRY does NOT forbid — the important half
**Coincidental duplication.** Two pieces of code that look alike today but answer to different actors are *not* duplication — and merging them couples two things that must be free to change apart.

```swift
// These look identical. They are NOT duplication.
struct InvoiceLine { var total: Decimal { qty * price } }      // finance rounding rules coming soon
struct CartLine    { var total: Decimal { qty * price } }      // promo rules coming soon
```
Extract a shared `LineTotal` helper and the first divergent requirement forces a flag parameter — and flags are control coupling (Module 01 §9).

**The test:** *if this rule changes, must all copies change?* Yes → real duplication, extract. No → leave it.

The failure mode of over-applied DRY is a parameterised super-function with six booleans. That's worse than the duplication it replaced. Sandi Metz's line is worth memorising: **"duplication is far cheaper than the wrong abstraction."**

### Rule of three
Two occurrences: wait. Three: extract. By the third you can see the real shape of the abstraction; at two you're guessing.

---

## 2. KISS — Keep It Simple

> **Prefer the simplest design that satisfies the stated requirements.**

Simple ≠ short. Simple = few moving parts, few concepts, obvious flow.

Complexity you should be able to spot instantly:
- A protocol with one conformer, no test double, and no second implementation planned.
- A generic type parameter used at exactly one concrete type.
- A factory that returns one product.
- An event bus where a direct method call would do.
- Inheritance three levels deep to share one method.

```swift
// ❌ over-built for "add up an array"
protocol Reducer { associatedtype T; func reduce(_ xs: [T]) -> T }
struct SumReducer<T: Numeric>: Reducer { func reduce(_ xs: [T]) -> T { xs.reduce(0, +) } }
let total = SumReducer<Int>().reduce(values)

// ✅
let total = values.reduce(0, +)
```

**In an interview**, complexity you can't justify reads as insecurity. Say instead: *"a plain function is enough here; I'd introduce a protocol when a second implementation appears."* That is a senior answer, not a lazy one.

---

## 3. YAGNI — You Aren't Gonna Need It

> **Don't build it until a real requirement asks for it.**

YAGNI is about *speculative generality*: the plugin system for the one plugin, the multi-currency support for the single-country product, the `enum Environment { case dev, staging, prod, qa, canary }` for two environments.

The cost of speculation isn't the hour you spend writing it. It's:
- Code you must maintain, test and understand forever.
- An abstraction shaped by a guess, which is usually the wrong shape when the real requirement lands.
- Other people building on the wrong shape.

**KISS vs YAGNI vs OCP — how they coexist:** OCP says *be open to extension along the axis that actually varies*. YAGNI says *don't invent axes*. Resolution: **ask which axis varies, then be open on that one only.** That's why "what's likely to change?" is the highest-value clarifying question in Module 00.

**The YAGNI exception:** things that are extremely expensive to retrofit — a missing `id` on a persisted entity, ignoring localisation entirely, hardcoding single-tenancy into a schema. Cheap-to-add-later → defer. Expensive-to-retrofit → decide now.

---

## 4. Law of Demeter — "Don't talk to strangers"

> **A method should only call methods on: itself, its parameters, objects it creates, and its own properties.**
> Not on objects returned by those objects.

### The train wreck
```swift
// ❌ knows about 4 types and their internal shapes
let city = order.customer.address.city.name
order.customer.wallet.balance -= order.total          // reaching in to mutate, worse
```
Any change to `Customer`, `Address` or `City` breaks this line. You've coupled to a whole object graph.

### The fix — ask the object you know
```swift
// ✅ each type answers for its own data
extension City    { var displayName: String { name } }
extension Address { var cityName: String { city.displayName } }
extension Customer { var cityName: String { address.cityName } }
extension Order   { var shippingCity: String { customer.cityName } }

let city = order.shippingCity
```
Now `Order` depends only on `Customer`, and a change to `City` stops at `Address`.

### The nuance
Demeter is about **behaviour chains**, not data pipelines. These are fine:
```swift
items.filter(\.isActive).map(\.name).sorted()      // fluent API on values — not a Demeter violation
```
The difference: `filter`/`map` return the *same kind of thing* (a collection); you're not navigating someone's private object graph.

Over-applied, Demeter produces hundreds of trivial forwarding methods ("Demeter bloat"). Apply it where the chain crosses a **meaningful boundary**, especially where you mutate.

---

## 5. Tell, Don't Ask

> **Tell an object what to do; don't ask it for data and make the decision yourself.**

```swift
// ❌ Ask: the rule lives in the caller, and will be copy-pasted
if account.balance >= amount {
    account.balance -= amount
    ledger.record(amount)
}

// ✅ Tell: the rule lives with the data
try account.withdraw(amount, recordingTo: ledger)
```

Symptom: a caller reading a property, branching on it, then writing a property back. That's the object's own logic living outside the object.

**The counterweight — Anemic Domain Model**: types that are just `struct`s of public fields, with all behaviour in `…Service` classes. It's procedural code wearing an OOP costume. Some architectures do this deliberately (DTOs at boundaries, CQRS read models) — that's fine. What's not fine is *domain* rules scattered across services.

When is Ask okay? Queries for display and reporting (`account.balance` to render a label), and boundaries where behaviour genuinely doesn't belong (serialisation).

---

## 6. Encapsulate What Varies

> **Identify the aspects that change, and separate them from what stays the same.**

This is the single most useful sentence in this whole course. It is the seed of nearly every GoF pattern:

| What varies | Pattern |
|---|---|
| an algorithm | Strategy |
| which object to create | Factory / Abstract Factory |
| optional layers of behaviour | Decorator |
| behaviour per lifecycle state | State |
| who reacts to an event | Observer |
| who handles a request | Chain of Responsibility |
| one step of a fixed process | Template Method |
| a subsystem's interface | Facade / Adapter |

Practice the question until it's reflexive: **"what varies here, and along which axis?"** Then put the varying part behind its own abstraction and leave the stable part alone.

---

## 7. Program to an Interface, Not an Implementation

> **Depend on what a thing *does*, not what it *is*.**

```swift
let store: any OrderStore = PostgresOrderStore()   // ✅ callers see the capability
let store = PostgresOrderStore()                   // ❌ callers see the mechanism
```

In Swift, "interface" means protocol — but also: a function type (`(Int) -> Bool`), an `enum` that models a closed set, or `some P`. A closure is often the smallest possible interface, and preferable to a one-method protocol.

```swift
// A one-method protocol…
protocol Validator { func isValid(_ s: String) -> Bool }
// …is often better as
typealias Validator = (String) -> Bool
```
Use the protocol when you need a *named* concept, multiple related methods, conformance on existing types, or identity. Use the closure when it's genuinely one operation.

---

## 8. Hollywood Principle / Inversion of Control

> **"Don't call us, we'll call you."**

Low-level components don't reach up into high-level ones; the high-level component (or framework) calls down at the right moment. You live inside this every day:

```swift
// You don't call UIKit's run loop; it calls you.
override func viewDidLoad() { ... }
func tableView(_:cellForRowAt:) -> UITableViewCell { ... }
// SwiftUI calls body; you never call body.
var body: some View { ... }
```

Patterns built on it: Template Method (the base calls your override), Observer (the subject calls you), Command, dependency injection containers.

Why it matters in LLD: it's how you keep a stable skeleton while letting the variable parts plug in — without the variable parts knowing the skeleton.

---

## 9. Separation of Concerns

> **Different concerns belong in different modules, with defined boundaries between them.**

The usual axes in an app:

```
Presentation  (views, view models, formatting)
     │  depends on
Domain        (entities, rules, use cases)        ← depends on NOTHING
     ▲  implemented by
Infrastructure(network, database, keychain, analytics)
```
The arrows are DIP at architecture scale: the domain defines protocols, infrastructure implements them. Module 14 builds this concretely for iOS.

SoC is SRP zoomed out one level: SRP governs a type, SoC governs a layer.

---

## 10. GRASP — where responsibility belongs

SOLID tells you a class should have one responsibility. **GRASP tells you *which* one.** These five carry the most weight in an interview:

### Information Expert
> Assign a responsibility to the type that has the information needed to fulfil it.

```swift
// ❌ the service knows how a cart totals itself
func total(of cart: Cart) -> Decimal { cart.items.reduce(0) { $0 + $1.price * Decimal($1.qty) } }
// ✅ the cart has the items, so the cart totals itself
extension Cart { var total: Decimal { items.reduce(0) { $0 + $1.subtotal } } }
```
Information Expert is the antidote to anemic models and the reason `Tell, Don't Ask` works.

### Creator
> `A` should create `B` if `A` contains/aggregates `B`, closely uses it, or has the data to initialise it.

`Cart` creates `CartItem`. `ParkingLot` creates `Ticket`. `Game` creates `Board`. When no type qualifies, that's when a Factory earns its place.

### Controller
> Assign the handling of a system event to a type representing the use case or the overall system — not to a UI type.

This is precisely why the View Controller should not contain checkout logic.

### Low Coupling / High Cohesion
The two evaluative principles: when two designs are otherwise equal, pick the one with fewer dependencies and tighter focus. Module 01 §9.

### Pure Fabrication
> When no domain concept fits a responsibility, invent a non-domain type for it rather than forcing it onto an entity.

`OrderRepository`, `PriceEngine`, `NotificationDispatcher` — none are real-world nouns, all are legitimate. This is the escape hatch that stops Information Expert from turning entities into God Objects.

*(The remaining GRASP principles — Polymorphism, Indirection, Protected Variations — restate OCP/DIP in different words.)*

---

## 11. The tension table — principles that pull against each other

| Principle | Pulls toward | Opposed by | How to resolve |
|---|---|---|---|
| DRY | one representation | KISS, decoupling | is it the same *knowledge*? |
| OCP | extension points | YAGNI, KISS | which axis actually varies? |
| ISP | many small protocols | KISS | do clients use disjoint subsets? |
| Information Expert | fat entities | SRP | use Pure Fabrication for cross-entity logic |
| Demeter | forwarding methods | KISS | apply at real boundaries only |
| Encapsulate what varies | more types | YAGNI | only for variation you can name |

**There is no design that maximises all of them.** Interviewers are testing whether you can *name the tension and pick a side with a reason*. "I'm duplicating this deliberately — the two rules belong to different teams and I expect them to diverge" is a better answer than any principle recited correctly.

---

## 12. Cheat sheet

| Symptom | Principle | Move |
|---|---|---|
| same rule in 3 files | DRY | extract the rule into a type |
| identical code, different owners | *not* DRY | leave it duplicated |
| protocol with one conformer, no double | KISS | delete the protocol |
| config for a feature nobody asked for | YAGNI | delete it |
| `a.b.c.d` | Demeter | forward at each level |
| caller reads a property, branches, writes it back | Tell-Don't-Ask | move the method into the type |
| structs with no methods + fat services | Information Expert | push behaviour onto the data |
| a growing `if` on a mode flag | Encapsulate what varies | strategy protocol |
| domain code importing UIKit | SoC | invert with a protocol |
| entity doing cross-entity orchestration | Pure Fabrication | invent a service type |

---

## ✅ Checkpoint
1. Give an example of duplicated code you should **not** extract, and say why.
2. State the difference between KISS and YAGNI in one sentence each.
3. Why is `items.map(\.name).sorted()` not a Demeter violation?
4. Rewrite an Ask-style snippet as Tell, and name the principle that says the logic belongs there.
5. Name three GoF patterns that are all "encapsulate what varies" applied to different axes.
6. Give a case where DRY and low coupling conflict, and say how you'd decide.

Then: `EXERCISES.md` → `swift test --filter M03` → `SOLUTIONS.md` → `PROJECT.md`.
