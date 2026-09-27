# Module 01 — OOP Fundamentals in Swift

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** by the end you can look at a requirement and carve it into types with clean boundaries, and you can explain every OOP term an interviewer throws at you *in Swift terms*, not Java terms.

**Why this matters:** every later module is built on this. SOLID is a set of rules about class boundaries. Design patterns are named arrangements of classes. If your instinct for "what should be a type and what should it own" is weak, patterns become cargo cult.

---

## 1. What OOP actually is

OOP = modelling a system as **objects** that own **state** and expose **behaviour**, and that **collaborate by sending messages**.

The point is not "classes". The point is **locality of change**: if a rule about money lives in one type, changing that rule touches one file.

Three ways to organise code, for contrast:

```swift
// Procedural: data and behaviour separate
struct AccountData { var balance: Double }
func withdraw(_ a: inout AccountData, _ amt: Double) { a.balance -= amt }  // anyone can also do a.balance = -999

// Object-oriented: data and the rules that guard it live together
final class Account {
    private var balance: Double        // nobody outside can corrupt it
    func withdraw(_ amt: Double) throws { /* rules enforced here */ }
}

// Functional: data immutable, behaviour is transformation
func withdrawing(_ a: AccountData, _ amt: Double) -> AccountData { .init(balance: a.balance - amt) }
```

Swift is multi-paradigm. Good Swift LLD uses **objects for identity and lifecycle**, **values for data**, and **functions for transformation**. Interviewers in Java-land expect classes for everything; you should know when Swift's value types are the better answer and be able to say why.

### The four pillars — one line each

| Pillar | One-line definition | The question it answers |
|---|---|---|
| **Encapsulation** | Bundle state with the behaviour that guards it, hide the rest. | *Who is allowed to change this?* |
| **Abstraction** | Expose *what* a thing does, hide *how*. | *What do I need to know to use this?* |
| **Inheritance** | Define a type in terms of another, reusing/refining it. | *What is this a kind of?* |
| **Polymorphism** | One interface, many runtime behaviours. | *How do I treat different things uniformly?* |

---

## 2. Classes vs Objects (and Swift's twist)

A **class** is a blueprint. An **object/instance** is a thing made from it, with its own state and an **identity**.

```swift
final class Car {          // blueprint
    let plate: String
    var speed: Double = 0
    init(plate: String) { self.plate = plate }
}
let a = Car(plate: "KA-01")   // object 1
let b = Car(plate: "KA-02")   // object 2 — separate state, separate identity
```

Swift adds `struct` and `enum`, which are also full types with methods — but they have **no identity** and **value semantics**.

### `struct` vs `class` — the decision you will be asked about

| | `struct` (value) | `class` (reference) |
|---|---|---|
| Assignment | copies | shares |
| Identity | none (`===` illegal) | yes (`===`) |
| Mutation | needs `var` + `mutating` | any reference can mutate |
| Inheritance | no | yes |
| Deinit | no | `deinit` |
| Thread safety | easy (copies don't share) | hard (shared mutable state) |
| Typical LLD role | Money, Coordinate, Card, Move, DTO, Event | Account, ParkingLot, Elevator, Game, Repository |

**Rule of thumb for LLD:** if two references to "the same" thing must see each other's changes, it's a `class`. If it's just a bag of data compared by its contents, it's a `struct`.

```swift
struct Point { var x: Int }
var p1 = Point(x: 1); var p2 = p1; p2.x = 99
// p1.x == 1  — copy

final class Node { var x = 1 }
let n1 = Node(); let n2 = n1; n2.x = 99
// n1.x == 99 — shared
```

This exact distinction is the bug source in half of all machine-coding rounds: a `struct Seat` stored in an array, mutated through a local copy, and the booking silently doesn't stick.

---

## 3. Encapsulation

**Definition:** keep state private and expose a narrow, rule-enforcing API. The object is responsible for never being in an invalid state.

**Smell that you lack it:** callers reading a property, computing something, and writing it back. That business rule now lives in the caller — and in every other caller.

```swift
// ❌ No encapsulation — invariants live nowhere
final class BadAccount {
    var balance: Double = 0
}
acct.balance -= 500      // overdraft? negative balance? nobody checks.

// ✅ Encapsulated — the invariant "balance never goes negative" is guaranteed by the type
final class Account {
    private(set) var balance: Decimal          // readable, not writable, from outside
    private var transactions: [Transaction] = []

    init(opening: Decimal) { self.balance = opening }

    func deposit(_ amount: Decimal) throws {
        guard amount > 0 else { throw AccountError.nonPositiveAmount }
        balance += amount
    }

    func withdraw(_ amount: Decimal) throws {
        guard amount > 0 else { throw AccountError.nonPositiveAmount }
        guard amount <= balance else { throw AccountError.insufficientFunds }
        balance -= amount
    }
}
```

### Swift access control — your encapsulation toolbox

| Level | Visible to |
|---|---|
| `private` | the enclosing declaration + its extensions in the same file |
| `fileprivate` | the whole file |
| `internal` (default) | the whole module |
| `public` | other modules, but classes can't be subclassed outside |
| `open` | other modules, subclassable/overridable outside |

`private(set) var x` — read publicly, write privately. Use it constantly; it kills a whole category of bugs.

**Interview line:** *"I made `balance` `private(set)` so the only way to change it is through `deposit`/`withdraw`, which enforce the invariants."*

---

## 4. Abstraction

**Definition:** expose the essential interface, hide the implementation. Encapsulation hides *data*; abstraction hides *complexity*.

```swift
protocol PaymentGateway {
    func charge(amount: Decimal, token: String) async throws -> String   // returns transactionID
}
```

The caller knows nothing about Stripe SDKs, retries, or HMAC signing. That's abstraction. Swapping Stripe for Razorpay touches one file.

**The test for a good abstraction:** could you write a second, genuinely different implementation without changing the protocol? If not, the protocol is just a copy of one class's methods.

**Leaky abstraction smell:**
```swift
protocol PaymentGateway {
    func charge(...) async throws -> String
    var stripeAPIVersion: String { get }   // ❌ leaks the implementation into the contract
}
```

---

## 5. Inheritance

**Definition:** a subclass gets the superclass's members and can add or override.

```swift
class Employee {
    let name: String
    var baseSalary: Decimal
    init(name: String, baseSalary: Decimal) { self.name = name; self.baseSalary = baseSalary }
    func monthlyPay() -> Decimal { baseSalary / 12 }
}

final class Salesperson: Employee {
    var commission: Decimal = 0
    override func monthlyPay() -> Decimal { super.monthlyPay() + commission }
}
```

Swift rules worth knowing: single inheritance only; `override` is mandatory; `final` blocks subclassing (and lets the compiler devirtualise); `required init`; designated vs convenience initialisers; a subclass must call a designated `super.init` after initialising its own stored properties.

### When inheritance is right
- A genuine **is-a** relationship that is stable over time.
- The subtype is substitutable everywhere the supertype is (LSP — Module 02).
- You're sharing *identity and lifecycle*, not just code.

### When it's wrong (most of the time)
- You inherited only to reuse a method → use composition.
- Subclasses override methods to make them throw or do nothing → LSP violation.
- The hierarchy multiplies: `SUVWithSunroofElectric` → combinatorial explosion, use Decorator/Strategy.

---

## 6. Polymorphism

Three kinds, all present in Swift:

**a) Subtype polymorphism (runtime, dynamic dispatch)**
```swift
let staff: [Employee] = [Employee(name: "A", baseSalary: 1_200_000),
                         Salesperson(name: "B", baseSalary: 900_000)]
let payroll = staff.reduce(0) { $0 + $1.monthlyPay() }   // each dispatches to its own override
```

**b) Protocol polymorphism — the idiomatic Swift form**
```swift
protocol Shape { func area() -> Double }
struct Circle: Shape { let r: Double; func area() -> Double { .pi * r * r } }
struct Rect: Shape   { let w, h: Double; func area() -> Double { w * h } }

func totalArea(_ shapes: [any Shape]) -> Double { shapes.reduce(0) { $0 + $1.area() } }
```
Note `[any Shape]` — an *existential*, heterogeneous, dynamically dispatched. Contrast with generics:
```swift
func totalArea<S: Shape>(_ shapes: [S]) -> Double   // homogeneous, statically dispatched, faster
```
In LLD you almost always want `any Shape` (a heterogeneous collection is the whole point). Mentioning the tradeoff is a strong signal in an iOS interview.

**c) Parametric polymorphism (generics)**
```swift
struct Stack<Element> { private var items: [Element] = [] /* ... */ }
```

**d) Ad-hoc polymorphism (overloading)** — same name, different parameter types. Resolved at compile time.

---

## 7. Protocols: Swift's interfaces (and its "abstract classes")

Swift has **no `abstract class` keyword**. Know the two idiomatic replacements:

**Pure interface → protocol**
```swift
protocol Drivable {
    var wheels: Int { get }
    func drive()
}
```

**Interface + shared default behaviour → protocol + protocol extension**
```swift
protocol Vehicle {
    var wheels: Int { get }          // subtype MUST supply  (like an abstract member)
    var name: String { get }
}
extension Vehicle {                  // shared implementation (like a concrete superclass method)
    var description: String { "\(name) with \(wheels) wheels" }
    func honk() { print("beep") }    // overridable by conformers
}

struct Bike: Vehicle { let wheels = 2; let name = "Bike" }
```

**The dispatch gotcha you must know.** Methods declared *only* in the extension use **static dispatch**:

```swift
protocol Greeter { func hello() }            // in the protocol → dynamic
extension Greeter {
    func hello() { print("protocol hello") }
    func bye()   { print("protocol bye") }   // NOT in the protocol → static
}
struct S: Greeter {
    func hello() { print("S hello") }
    func bye()   { print("S bye") }
}
let g: any Greeter = S()
g.hello()   // "S hello"       ← witness table, dynamic
g.bye()     // "protocol bye"  ← static, picks the extension. Surprise.
```
Rule: **if conformers should be able to override it, declare it in the protocol body**, not just the extension.

**Protocol vs abstract class — comparison table**

| | Swift protocol (+ extension) | Class inheritance |
|---|---|---|
| Multiple conformance | ✅ many protocols | ❌ one superclass |
| Stored properties | ❌ (only computed / requirements) | ✅ |
| Works with `struct`/`enum` | ✅ | ❌ |
| Shared state | ❌ | ✅ |
| Default implementation | ✅ via extension | ✅ |
| "Cannot instantiate" | ✅ by nature | ❌ needs convention |

**Emulating an abstract class when you genuinely need shared stored state:**
```swift
class Report {                                   // don't instantiate directly
    let title: String
    init(title: String) { self.title = title }
    func body() -> String { fatalError("subclass must override body()") }   // abstract-ish
    final func render() -> String { "# \(title)\n\(body())" }               // template method
}
```
Say out loud in an interview: *"Swift has no abstract classes; I'd normally use a protocol with an extension, but here I need shared stored state so I'm using a base class with a `fatalError` stub — the compiler can't enforce it, so it's a convention."*

---

## 8. Composition over Inheritance

**Composition** = an object holds other objects and delegates to them (**has-a**).
**Inheritance** = an object *is* a specialised other object (**is-a**).

The classic disaster:

```swift
// ❌ Inheritance explosion
class Notifier { func send(_ m: String) {} }
class EmailNotifier: Notifier {}
class SMSNotifier: Notifier {}
class EmailAndSMSNotifier: Notifier {}          // and now Slack? Email+Slack? SMS+Slack+Push?
```

```swift
// ✅ Composition — behaviours are parts, combined at runtime
protocol Channel { func deliver(_ message: String) }
struct Email: Channel { func deliver(_ m: String) { print("email: \(m)") } }
struct SMS:   Channel { func deliver(_ m: String) { print("sms: \(m)") } }
struct Slack: Channel { func deliver(_ m: String) { print("slack: \(m)") } }

struct Notifier {
    private let channels: [any Channel]
    init(channels: [any Channel]) { self.channels = channels }
    func send(_ message: String) { channels.forEach { $0.deliver(message) } }
}

Notifier(channels: [Email(), Slack()]).send("build failed")   // new combo, zero new types
```

Why composition wins in practice:
1. **Runtime flexibility** — swap parts after construction; inheritance is fixed at compile time.
2. **No fragile base class** — a superclass change can't silently break 12 subclasses.
3. **Testability** — inject a fake `Channel`; you can't inject a superclass.
4. **Avoids the diamond** — no ambiguity about whose implementation wins.
5. **Combinatorics** — N behaviours compose; they don't need 2^N subclasses.

Use inheritance only when the is-a is real, stable, and you need shared stored state or a template method. Otherwise compose.

**"Delegation" in Swift** is composition plus the UIKit-style `weak var delegate` naming convention — same idea, and it's why `UITableViewDataSource` isn't a subclass.

---

## 9. Coupling and Cohesion

These two words are how you *justify* every decision in an LLD interview.

### Coupling — how much one module knows about another. Want: **low**.

Degrees, worst to best:
1. **Content coupling** — A reaches into B's internals. (`b.internalArray[3] = x`)
2. **Common coupling** — both share global mutable state. (a Singleton everyone mutates)
3. **Control coupling** — A passes a flag telling B *how* to behave. (`render(isPDF: true)`)
4. **Stamp coupling** — A passes a whole object when B needs one field.
5. **Data coupling** — A passes exactly the data B needs. ✅
6. **Message coupling** — A only knows B's protocol. ✅✅

```swift
// ❌ Tightly coupled: OrderService hardcodes a concrete dependency. Untestable, unswappable.
final class OrderService {
    private let gateway = StripeGateway()          // concrete, constructed inside
    func place(_ o: Order) throws { try gateway.charge(o.total) }
}

// ✅ Loosely coupled: depends on an abstraction, injected from outside
final class OrderService {
    private let gateway: any PaymentGateway
    init(gateway: any PaymentGateway) { self.gateway = gateway }
    func place(_ o: Order) throws { try gateway.charge(o.total) }
}
// tests: OrderService(gateway: FakeGateway())
```
That's dependency injection, and it's also the D in SOLID (Module 02).

### Cohesion — how focused one module is. Want: **high**.

Low cohesion looks like this:

```swift
// ❌ God class: four unrelated reasons to change
final class UserManager {
    func createUser(...)        // domain rules
    func saveToDatabase(...)    // persistence
    func sendWelcomeEmail(...)  // messaging
    func renderProfileHTML(...) // presentation
}
```

```swift
// ✅ Split by reason-to-change
struct User { ... }                                    // entity
protocol UserRepository { func save(_ u: User) throws } // persistence boundary
protocol Mailer { func sendWelcome(to: User) throws }   // messaging boundary
struct UserService {                                    // orchestration only
    let repo: any UserRepository
    let mailer: any Mailer
    func register(_ u: User) throws { try repo.save(u); try mailer.sendWelcome(to: u) }
}
```

**Quick heuristic:** name the class. If the honest name needs "and" or ends in `Manager`/`Helper`/`Utils`, cohesion is probably low.

**The memorable pairing:** *high cohesion inside a type, low coupling between types.* Every design principle in Module 02–03 is a specific tactic for achieving those two.

---

## 10. Protocol-Oriented Programming (the Swift accent)

Apple's guidance: start with a protocol, not a base class. Practically, in LLD:

- Model **capabilities** as small protocols (`Drivable`, `Chargeable`, `Persistable`) and conform types to several, instead of one deep hierarchy.
- Put shared behaviour in **protocol extensions** with default implementations.
- Constrain extensions for specialised behaviour:
  ```swift
  extension Collection where Element: Shape {
      func totalArea() -> Double { reduce(0) { $0 + $1.area() } }
  }
  ```
- Use `some P` (opaque, one concrete type, static dispatch) for returns; `any P` (existential, heterogeneous, dynamic dispatch) for collections and stored dependencies.

Small protocols also give you the I in SOLID for free (Interface Segregation, Module 02).

---

## 11. Vocabulary you must be able to define instantly

| Term | Definition |
|---|---|
| **Class / Object** | Blueprint / instance with its own state and identity |
| **Encapsulation** | State + guarding behaviour together, internals hidden |
| **Abstraction** | Contract visible, implementation hidden |
| **Inheritance** | Type defined by extending another (is-a) |
| **Polymorphism** | One interface, many runtime behaviours |
| **Composition** | Type built from other types it delegates to (has-a) |
| **Aggregation** | has-a where the part outlives the whole |
| **Association** | Two types simply know each other |
| **Delegation** | Forwarding work to a held collaborator |
| **Coupling** | Degree of interdependence between modules (want low) |
| **Cohesion** | Degree of focus within one module (want high) |
| **Dynamic dispatch** | Method resolved at runtime via vtable/witness table |
| **Static dispatch** | Method resolved at compile time |
| **Existential (`any P`)** | Box holding some conforming type, dynamic |
| **Opaque (`some P`)** | One specific conforming type, hidden from caller, static |
| **Value semantics** | Assignment copies; no shared mutable state |
| **Reference semantics** | Assignment shares; identity matters |

---

## ✅ Checkpoint before moving on

You should be able to, without notes:
1. Explain value vs reference semantics and give an LLD bug caused by confusing them.
2. Give a Swift example of an abstraction that is *not* just encapsulation.
3. Convert an inheritance explosion into composition.
4. Name the coupling levels from worst to best and place a code snippet on that scale.
5. Explain why `g.bye()` printed `"protocol bye"` in §7.

Now: `EXERCISES.md` → `swift test --filter M01` → `SOLUTIONS.md` → `PROJECT.md`.
