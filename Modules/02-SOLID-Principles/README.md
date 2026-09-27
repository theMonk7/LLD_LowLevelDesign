# Module 02 — SOLID, Deeply

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** name a design smell, name the principle it violates, and fix it in Swift — in under a minute, out loud.

**Why this matters:** SOLID is the vocabulary interviewers grade you in. "I extracted this because the pricing rule and the persistence rule change for different reasons" scores; "I felt like splitting it" doesn't. Every design pattern in Modules 05–07 is a packaged solution to a SOLID violation.

The five principles answer one question each:

| | Principle | The question |
|---|---|---|
| **S** | Single Responsibility | *Why would I ever edit this type?* |
| **O** | Open/Closed | *Can I add a case without editing old code?* |
| **L** | Liskov Substitution | *Can I swap the subtype in and trust the callers?* |
| **I** | Interface Segregation | *Am I forced to implement things I don't need?* |
| **D** | Dependency Inversion | *Who decides which concrete type gets used?* |

---

## S — Single Responsibility Principle

> **A class should have one, and only one, reason to change.**
> Better phrasing (Martin's own correction): *a module should be responsible to one, and only one, actor.*

"One reason to change" is not "one method" or "does one small thing". It's about **who requests the change**. If the finance team's rule and the marketing team's rule live in the same type, two different actors can force edits to the same file — and their changes collide.

### The smell
- Class name contains `Manager`, `Handler`, `Util`, `Helper`, `Service` with no domain meaning.
- The honest description of the class needs "and".
- A method list that mixes vocabulary from different domains: `calculateTax`, `saveToDisk`, `renderHTML`.
- Merge conflicts on the same file from unrelated feature branches. That's SRP failing, measured.

### Violation

```swift
final class InvoiceProcessor {
    func calculateTotal(_ invoice: Invoice) -> Decimal { /* finance rules */ }
    func saveToDatabase(_ invoice: Invoice) throws { /* SQL */ }
    func emailToCustomer(_ invoice: Invoice) throws { /* SMTP */ }
    func renderPDF(_ invoice: Invoice) -> Data { /* layout */ }
}
```
Four actors: finance, DBA, marketing, design. Four reasons to change. One file.

### Fix

```swift
struct InvoiceCalculator { func total(of invoice: Invoice) -> Decimal { ... } }   // finance
protocol InvoiceRepository { func save(_ invoice: Invoice) throws }               // persistence
protocol InvoiceMailer    { func send(_ invoice: Invoice) throws }                // messaging
protocol InvoiceRenderer  { func pdf(for invoice: Invoice) -> Data }              // presentation

struct InvoiceService {                                                            // orchestration
    let calculator: InvoiceCalculator
    let repository: any InvoiceRepository
    let mailer: any InvoiceMailer

    func process(_ invoice: Invoice) throws {
        var priced = invoice
        priced.total = calculator.total(of: invoice)
        try repository.save(priced)
        try mailer.send(priced)
    }
}
```

`InvoiceService` still changes when the *workflow* changes — that's its one reason, and it's legitimate. Orchestration is a responsibility.

### Where SRP is over-applied
Splitting a 20-line type into six 4-line types with one method each doesn't reduce reasons to change; it spreads one reason across six files. **Cohesion is the goal; file count is not a metric.** If two things always change together, they belong together.

### iOS translation
Massive View Controller is SRP failure: view lifecycle + networking + parsing + formatting + navigation in one class. MVVM helps only if the ViewModel doesn't become the new dumping ground.

### Interview probe
*"What's the responsibility of this class?"* If you answer with "and", you've failed the probe. Then: *"who would ask you to change it?"*

---

## O — Open/Closed Principle

> **Open for extension, closed for modification.**
> Add new behaviour by adding code, not by editing working code.

Why it matters practically: edited code must be re-reviewed, re-tested and re-shipped, and it can break existing callers. Added code can't break what it doesn't touch.

### The smell
A `switch` or `if/else` chain over a *type tag* that you have to revisit every time a new case appears — especially if the same switch shape appears in more than one place.

### Violation

```swift
enum ShippingMethod { case standard, express, sameDay }

struct ShippingCalculator {
    func cost(for order: Order, method: ShippingMethod) -> Decimal {
        switch method {
        case .standard: return 50
        case .express:  return 150
        case .sameDay:  return 300
        }
    }
}
```
Adding `.drone` means editing this file — and every other switch over `ShippingMethod` in the codebase.

### Fix — polymorphism instead of branching

```swift
protocol ShippingPolicy {
    var name: String { get }
    func cost(for order: Order) -> Decimal
}

struct StandardShipping: ShippingPolicy {
    let name = "standard"
    func cost(for order: Order) -> Decimal { 50 }
}
struct ExpressShipping: ShippingPolicy {
    let name = "express"
    func cost(for order: Order) -> Decimal { 150 }
}
struct DroneShipping: ShippingPolicy {              // NEW FILE. Nothing above was edited.
    let name = "drone"
    func cost(for order: Order) -> Decimal { order.weightKg > 5 ? 900 : 450 }
}

struct ShippingCalculator {
    func cost(for order: Order, using policy: any ShippingPolicy) -> Decimal {
        policy.cost(for: order)
    }
}
```

That's the **Strategy** pattern (Module 07). OCP is *why* Strategy exists.

### The honest nuance — when a `switch` is correct
Swift's `enum` + exhaustive `switch` is a real strength: if the set of cases is **closed and stable** (`case north, south, east, west`), the compiler telling you about every unhandled case is a feature, not a violation. OCP applies when the set of variants is **expected to grow**.

Ask: *"will we add cases to this over time?"*
- Yes, frequently → protocol + conforming types.
- No, it's a fixed domain → enum and enjoy exhaustiveness.

Saying this distinction out loud is a strong senior signal; blanket "switch = bad" is a junior signal.

### Interview probe
*"Now add a new payment method / vehicle type / discount."* They're timing how many existing files you touch. One new file = pass.

---

## L — Liskov Substitution Principle

> **Subtypes must be substitutable for their base types without breaking correctness.**
> If `S` is a subtype of `T`, code written against `T` must work when handed an `S` — without knowing.

This is the most violated and least understood of the five. LSP is about **behavioural contracts**, not method signatures. The compiler checks signatures; only you can check contracts.

### The four contract rules

| Rule | Subtype must… | Violation looks like |
|---|---|---|
| **Preconditions** | not strengthen them | base accepts any `Int`; override requires positive |
| **Postconditions** | not weaken them | base guarantees a sorted result; override returns unsorted |
| **Invariants** | preserve them | base guarantees `balance >= 0`; override allows overdraft |
| **History** | not allow state changes the base forbids | base is immutable after init; subclass adds a setter |

### The canonical violation — Rectangle/Square

```swift
class Rectangle {
    var width: Double = 0
    var height: Double = 0
    var area: Double { width * height }
}

final class Square: Rectangle {              // mathematically a square IS a rectangle…
    override var width: Double { didSet { super.height = width } }
    override var height: Double { didSet { super.width = height } }
}

func stretch(_ r: Rectangle) {
    r.width = 5
    r.height = 4
    assert(r.area == 20)                     // ✅ Rectangle, ❌ Square gives 16
}
```
The lesson: **is-a in the real world is not is-a in code.** Substitutability is about behaviour under the caller's assumptions. Fix: don't subclass — make `Rectangle` and `Square` separate types conforming to a `Shape` protocol with a read-only `area`, and make them immutable.

### The Swift violation you'll actually write

```swift
protocol Storage {
    func write(_ data: Data, key: String) throws
}

struct ReadOnlyStorage: Storage {
    func write(_ data: Data, key: String) throws {
        throw StorageError.unsupported       // ❌ strengthened precondition: "only if writable"
    }
}
```
Every caller now needs to know which implementation it got — which destroys the point of the abstraction. Fix: split the protocol (that's ISP rescuing LSP):

```swift
protocol ReadableStorage { func read(key: String) throws -> Data }
protocol WritableStorage: ReadableStorage { func write(_ data: Data, key: String) throws }
```

Other everyday violations: an override that returns `nil` where the base never did; an override that logs and silently does nothing; a subclass that requires `configure()` to be called first when the base doesn't.

### Design responses
- Prefer **composition** — no subtype, no substitutability problem.
- Prefer `final` classes and `struct`s by default; inherit deliberately.
- Use **protocol hierarchies that only add capability**, never remove it.
- If a subtype can't honour the contract, the hierarchy is wrong, not the contract.

### Interview probe
*"Is `Square: Rectangle` okay?"* — say no, and explain with the mutable-setter argument, not with "because SOLID".

---

## I — Interface Segregation Principle

> **No client should be forced to depend on methods it does not use.**
> Many small, role-specific protocols beat one fat one.

### The smell
Conformances full of empty method bodies, `fatalError("not supported")`, or `return nil`. Every empty implementation is the compiler telling you the protocol is too big.

### Violation

```swift
protocol Worker {
    func work()
    func eat()
    func attendStandup()
    func submitTimesheet()
}

struct RobotWorker: Worker {
    func work() { ... }
    func eat() { }                      // ❌ meaningless
    func attendStandup() { }            // ❌ meaningless
    func submitTimesheet() { }          // ❌ meaningless
}
```

### Fix — role protocols

```swift
protocol Workable   { func work() }
protocol Feedable   { func eat() }
protocol Reportable { func attendStandup(); func submitTimesheet() }

struct Human: Workable, Feedable, Reportable { ... }
struct RobotWorker: Workable { func work() { ... } }     // conforms to exactly what it is
```

Swift makes this cheap: a type can conform to many protocols, and you can compose requirements at the use site with `some Workable & Reportable`.

### The "default implementation" trap
Swift lets you paper over a fat protocol with an extension:
```swift
extension Worker { func eat() {} }      // now RobotWorker "conforms" without noticing
```
Sometimes right (genuinely optional behaviour with a sane default), often a smell — it hides the fact that the protocol mixes unrelated roles. Ask: *is this a default, or an excuse?*

### iOS translation
`UITableViewDelegate` has ~40 optional methods — a fat protocol made tolerable by Objective-C optionality. `SwiftUI`'s many tiny protocols (`View`, `Identifiable`, `Hashable`, `Equatable`) are ISP done right. Note the direction Apple moved.

### Interview probe
*"This protocol has 9 methods — is that a problem?"* Answer in terms of **clients**: how many methods does each caller actually use? If callers use disjoint subsets, split along those subsets.

---

## D — Dependency Inversion Principle

> **High-level modules should not depend on low-level modules. Both should depend on abstractions.**
> **Abstractions should not depend on details. Details should depend on abstractions.**

Two separate claims. The second is the one people miss: the abstraction must be phrased in the *high-level module's* vocabulary, not the database's.

### Before — dependency points downward

```
OrderService  ──▶  PostgresOrderStore   (policy depends on mechanism)
```
```swift
final class OrderService {
    private let store = PostgresOrderStore()   // constructed inside, concrete, untestable
}
```

### After — dependency inverted

```
OrderService  ──▶  OrderStore (protocol, owned by the domain)
                        ▲
                        │ implements
               PostgresOrderStore
```
```swift
protocol OrderStore {                             // declared next to OrderService, not next to Postgres
    func save(_ order: Order) throws
    func find(id: String) -> Order?
}

final class OrderService {
    private let store: any OrderStore
    init(store: any OrderStore) { self.store = store }
}
```
The arrow from `PostgresOrderStore` now points **up** toward the policy. That reversal is the "inversion". `OrderService` is testable, portable, and doesn't recompile when you switch databases.

**The leak that cancels the benefit:**
```swift
protocol OrderStore { func executeSQL(_ query: String) -> ResultSet }   // ❌ abstraction depends on details
```

### Three injection styles in Swift

```swift
// 1. Initialiser injection — default choice: dependencies are explicit and non-optional
init(store: any OrderStore, clock: any Clock = SystemClock())

// 2. Property injection — for cases where the dependency arrives later (UIKit segues)
var analytics: (any Analytics)?

// 3. Method injection — for a dependency used by exactly one method
func export(using renderer: any Renderer) -> Data
```

Default to initialiser injection. It makes "what does this type need?" readable in one line and makes an unconstructable object impossible.

### DIP vs DI vs IoC
- **DIP** — a principle about which way dependency arrows point.
- **Dependency Injection** — a technique: pass dependencies in rather than constructing them.
- **Inversion of Control** — the broader idea that the framework calls you (Hollywood Principle, Module 03).

You can do DI without DIP (injecting a concrete type), and you get little benefit. The protocol is the point.

### Interview probe
*"How would you unit-test this?"* If the answer requires a live database, DIP is missing.

---

## How the five fit together

```
        SRP  ── splits responsibilities ──▶ small types
          │                                    │
          ▼                                    ▼
        ISP  ── splits protocols  ─────▶  small protocols
          │                                    │
          └────────────▶  DIP  ◀───────────────┘
                          │  depend on those protocols
                          ▼
                         OCP  ── add a new conformer, edit nothing
                          │
                          ▼
                         LSP  ── and the new conformer must behave
```

Read it as one sentence: **split responsibilities (S) into narrow protocols (I), depend on those protocols rather than concretions (D), so new behaviour arrives as new conformers (O) that callers can trust (L).**

Every GoF pattern is a named way of doing this. Strategy = OCP via composition. Decorator = OCP without subclassing. Adapter = LSP repair for a foreign interface. Abstract Factory = DIP for object creation.

---

## Smell → principle → fix (memorise this table)

| Smell | Violates | Fix |
|---|---|---|
| Class does persistence *and* business rules | SRP | extract a repository protocol |
| `switch` over a type tag you keep extending | OCP | protocol + one conformer per case (Strategy/Factory) |
| Override throws / returns nil / does nothing | LSP | split the protocol or use composition |
| Conformance with empty method bodies | ISP | split into role protocols |
| `let db = Postgres()` inside a service | DIP | inject `any Store` through `init` |
| Can't unit-test without network/disk/clock | DIP | inject the dependency |
| Same `if type == ...` in three files | OCP | move behaviour into the type |
| God class named `XManager` | SRP + ISP | split by actor |

---

## When NOT to apply SOLID

SOLID costs indirection, and indirection costs comprehension. Skip it when:
- There is exactly **one** implementation and no realistic second one. A protocol with one conformer and no test double is ceremony.
- The variation axis is **hypothetical**. YAGNI (Module 03) outranks OCP for things nobody asked for.
- The code is a **leaf**: a 30-line pure function with no dependencies needs no inversion.

Interviewers reward *"I'd keep this concrete until a second implementation appears"* far more than a pre-emptive five-protocol architecture for a Tic-Tac-Toe board.

---

## ✅ Checkpoint

Answer without notes:
1. State SRP in terms of actors, not methods, and give an example of two actors sharing a class.
2. Give one case where an exhaustive `switch` is the *right* answer despite OCP.
3. Name the four LSP contract rules and give a Swift violation of each.
4. What does an empty method body in a conformance tell you?
5. Explain DIP's second sentence ("abstractions should not depend on details") with a bad protocol.

Then: `EXERCISES.md` → `swift test --filter M02` → `SOLUTIONS.md` → `PROJECT.md`.
