# Module 08 — Choosing the Right Pattern

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** stop asking "which pattern do I know?" and start asking "**what varies, and who should own that variation?**" — then reach for the smallest thing that solves it, which is often no pattern at all.

Modules 05–07 taught you 23 patterns. This module is about *restraint and retrieval*: pulling the right one out fast, and recognising when the right answer is a function.

---

## 1. The selection method

Four questions, in this order. Do not skip to the pattern.

### Q1. What varies?
Write the sentence: **"The ___ varies by ___."**
- "The *fee calculation* varies by *pricing plan*." → algorithm varies → Strategy
- "The *behaviour of every method* varies by *machine status*." → behaviour varies by lifecycle state → State
- "The *set of listeners* varies at runtime." → who reacts varies → Observer
- "The *concrete type created* varies by *config*." → creation varies → Factory
- "The *layers of optional behaviour* vary per request." → composition varies → Decorator

If you cannot complete the sentence, **you don't need a pattern yet**.

### Q2. Does it vary *now*, or might it vary *later*?
- Now, with two or more real cases → build the abstraction.
- Later, hypothetically → YAGNI (Module 03 §3). Write the concrete thing. Extracting later is cheap; deleting a wrong abstraction that three teams built on is not.

### Q3. Who should own the variation?
Apply Information Expert (Module 03 §10). The type holding the data usually owns the rule — unless the rule spans entities, in which case invent a Pure Fabrication.

### Q4. What's the smallest thing that works?
In order of increasing cost:
```
a parameter  <  a closure  <  an enum + switch  <  a protocol + 2 types  <  a full pattern
```
Start at the left. Move right only when the left fails. Most real code lives in the first three.

---

## 2. Symptom → pattern lookup table

Memorise this. It's the fastest path from "I see a problem" to "I know the move".

| Symptom in the code or requirement | Pattern | Why |
|---|---|---|
| `switch` over a type tag you keep extending | Strategy / Factory / polymorphism | OCP |
| `switch` on a `status` field in *every* method | State | behaviour varies by state |
| Chain of `if/else if` picking who handles it | Chain of Responsibility | handler varies |
| Subclass per combination of features | Decorator | combinations explode |
| `NotificationCenter` string soup | Observer (typed) | type-safe broadcast |
| Caller reads properties and decides | Tell-Don't-Ask / move the method | Information Expert |
| Constructor with 8 parameters, 6 optional | Builder / default arguments | construction complexity |
| Third-party type doesn't fit your protocol | Adapter | interface mismatch |
| Five calls in the same order every time | Facade / Template Method | sequence is knowledge |
| Object graph that must render one and many alike | Composite | recursive uniformity |
| Expensive object created but often unused | Proxy (virtual) / `lazy` | deferred creation |
| Permission check repeated at every call site | Proxy (protection) | access control |
| "Undo", "redo", "queue", "retry", "audit" | Command | requests as objects |
| "Snapshot", "checkpoint", "restore" | Memento | state capture |
| "Iterate in several orders" | Iterator (`Sequence`) | traversal varies |
| N components each referencing the other N−1 | Mediator | N² coupling |
| `if x == nil` around an optional dependency | Null Object | absence as behaviour |
| "Keep adding operations over a stable hierarchy" | Visitor / enum + switch | operation axis varies |
| Two dimensions producing M×N classes | Bridge | independent hierarchies |
| Millions of near-identical instances | Flyweight | shared intrinsic state |
| `let x = Concrete()` inside a service | Dependency Injection | DIP |
| Two families of objects that must match | Abstract Factory | family consistency |

---

## 3. Decision trees

### Creation
```
How do I get this object?
├─ one shared instance, immutable/OS resource → Singleton (injectable)
├─ concrete type depends on input
│    ├─ closed set   → enum + factory function
│    └─ open set     → Factory Method / closure registry
├─ families that must match → Abstract Factory
├─ many optional params
│    ├─ all known at once → default arguments (no pattern)
│    └─ incremental / cross-field validation → Builder
├─ expensive to build, cheap to copy → Prototype (free with structs)
├─ expensive and reusable → Object Pool
└─ anything else → Dependency Injection
```

### Structure
```
I need to wrap or arrange objects…
├─ interface is wrong           → Adapter
├─ add behaviour, stackable     → Decorator
├─ control access or lifecycle  → Proxy
├─ simplify a subsystem         → Facade
├─ tree, one and many alike     → Composite
├─ two independent dimensions   → Bridge
└─ huge instance count          → Flyweight
```

### Behaviour
```
Behaviour is the problem…
├─ algorithm varies             → Strategy (or a closure)
├─ varies by internal state     → State (or enum state machine)
├─ many need to know            → Observer (or Combine/AsyncStream)
├─ request needs a lifetime     → Command (+ Memento)
├─ try handlers in order        → Chain of Responsibility
├─ skeleton fixed, step varies  → Template Method
├─ traversal varies             → Iterator / Sequence
├─ N×N communication            → Mediator
├─ new ops over stable types    → Visitor (or enum + switch)
└─ optional collaborator        → Null Object
```

---

## 4. Patterns that travel together

Recognising *combinations* is what makes a design look experienced.

| Combination | Where it shows up |
|---|---|
| **Strategy + Factory** | factory picks the strategy from config |
| **Composite + Iterator** | traverse a tree uniformly |
| **Composite + Visitor** | run operations over a tree (this is a compiler) |
| **Command + Memento** | undo where some commands aren't reversible |
| **Command + Composite** | macro commands |
| **Observer + Mediator** | components observe the mediator, not each other |
| **State + Singleton/Flyweight** | stateless state objects shared across machines |
| **Decorator + Factory** | factory assembles the decorator stack |
| **Facade + Adapter** | simplified entry point over adapted legacy pieces |
| **Abstract Factory + Bridge** | factory chooses the implementation side of a bridge |
| **Template Method + Strategy** | fixed skeleton, one step injected |
| **Proxy + Flyweight** | shared, lazily loaded resources (image caches) |

Typical real design: *DI at the root → Factory builds a Decorator stack around an Adapter → domain uses Strategy for the varying rule → Observer notifies the UI.* Four patterns, and none of them announced themselves; each solved a named variation.

---

## 5. When the answer is "no pattern"

These are the highest-scoring answers in an interview when true:

| Situation | Correct answer |
|---|---|
| One implementation, no second one in sight | concrete type, no protocol |
| One-method strategy used once | a closure, or just a parameter |
| Closed set of cases (directions, suits, HTTP methods) | `enum` + exhaustive `switch` |
| Simple data with no behaviour | `struct` |
| A value that must be valid | failable init, not a Validator class |
| Sorting/filtering | standard library, not Strategy |
| Copying a value | value semantics, not Prototype |
| Notifying one listener | a delegate or closure, not Observer |
| Two fixed steps | a function, not Template Method |

**Sentence to have ready:** *"I'd keep this concrete. There's one implementation today, and introducing a protocol now would be an abstraction shaped by a guess. When the second case appears, extracting it is a 10-minute refactor."*

---

## 6. Anti-patterns to name (and avoid)

| Anti-pattern | Looks like | Cost | Fix |
|---|---|---|---|
| **God Object** | `AppManager` doing everything | nothing is testable or reusable | split by actor (SRP) |
| **Anemic Domain Model** | structs of fields + `…Service` for all logic | procedural code in OOP costume | Information Expert |
| **Singleton-itis** | `.shared` everywhere | global state, hidden deps | inject |
| **Pattern fever** | 9 patterns in a Tic-Tac-Toe | unreadable, slow to change | KISS/YAGNI |
| **Poltergeist** | classes that just forward once and die | pure noise | delete |
| **Golden Hammer** | every problem is Strategy | wrong-shaped solutions | Q1 of §1 |
| **Spaghetti inheritance** | 4-level hierarchies for code reuse | fragile base class | composition |
| **Magic container** | service locator resolving everywhere | runtime failures, invisible deps | init injection |
| **Yo-yo problem** | logic split across a deep hierarchy | you read 6 files for one flow | flatten, compose |
| **Leaky abstraction** | `protocol Store { func executeSQL(...) }` | swapping is impossible | phrase in domain terms |

---

## 7. Over-engineering detector

Run these checks on your own design before the interviewer does:

1. **Count the types.** Tic-Tac-Toe with 14 types is a red flag; with 4–6 it's right.
2. **Protocol-to-conformer ratio.** Every protocol with exactly one conformer and no test double needs a justification.
3. **Name the variation axis.** For each abstraction, say out loud what varies. If you can't, delete it.
4. **The deletion test.** Remove the pattern mentally. Does the code get worse, or shorter and clearer?
5. **Indirection depth.** If tracing one call takes more than three hops, reconsider.
6. **New-requirement test.** "Add feature X" should touch one or two files. If it touches eight, you under-designed. If adding X requires understanding six patterns first, you over-designed.

---

## 8. How to talk about patterns in an interview

**Do:**
- Name the variation *before* naming the pattern: *"pricing varies by plan, so I'll put it behind a protocol — that's Strategy."*
- Offer the cheaper alternative you rejected: *"a closure would do, but I want the strategy's name on the receipt."*
- State the cost: *"this adds a protocol and two types; the payoff is that new plans are one file."*
- Say no: *"I don't think we need a factory here — there's one implementation."*

**Don't:**
- Lead with the pattern name.
- Use a pattern because you prepared it.
- Say "I'll use the Singleton pattern" without thread-safety and testability.
- Add abstraction for requirements nobody stated.

---

## 9. Quick reference — all 23 in one table

| # | Pattern | Category | One-line trigger |
|---|---|---|---|
| 1 | Singleton | C | exactly one shared instance |
| 2 | Factory Method | C | subtype chosen elsewhere |
| 3 | Abstract Factory | C | matched families |
| 4 | Builder | C | complex/validated construction |
| 5 | Prototype | C | clone instead of construct |
| 6 | Object Pool | C | reuse expensive instances |
| 7 | Dependency Injection | C | caller supplies the implementation |
| 8 | Adapter | S | incompatible interface |
| 9 | Bridge | S | two varying dimensions |
| 10 | Composite | S | tree treated uniformly |
| 11 | Decorator | S | stackable added behaviour |
| 12 | Facade | S | simplify a subsystem |
| 13 | Flyweight | S | share intrinsic state |
| 14 | Proxy | S | control access |
| 15 | Chain of Responsibility | B | handler varies |
| 16 | Command | B | request as an object |
| 17 | Iterator | B | traversal varies |
| 18 | Mediator | B | N×N coupling |
| 19 | Memento | B | snapshot/restore |
| 20 | Observer | B | broadcast changes |
| 21 | State | B | behaviour per lifecycle state |
| 22 | Strategy | B | algorithm varies |
| 23 | Template Method | B | fixed skeleton, varying step |
| + | Visitor | B | new operations, stable types |
| + | Null Object | B | absent collaborator |

---

## ✅ Checkpoint
1. State the four selection questions in order.
2. Give three situations where the correct answer is "no pattern".
3. Name five pattern *combinations* and where each appears.
4. Apply the deletion test to a pattern in code you wrote last month.
5. For each of Strategy/State, Observer/Mediator, Command/Strategy, Decorator/Proxy — give the single distinguishing question.

Then: `EXERCISES.md` (30 drills) → `swift test --filter M08` → `SOLUTIONS.md` → `PROJECT.md`.
