# Module 01 — Solutions & Commentary

Full compilable reference: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).
Read this **after** your own green run. The code matters less than the reasoning next to it.

---

## E1 — `Money`

```swift
public init?(amount: Decimal, currency: String) {
    guard amount >= 0 else { return nil }
    guard currency.count == 3, currency.allSatisfy({ $0.isUppercase && $0.isLetter }) else { return nil }
    self.amount = amount; self.currency = currency
}

public static func add(_ lhs: Money, _ rhs: Money) throws -> Money {
    guard lhs.currency == rhs.currency else { throw MoneyError.currencyMismatch }
    return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)!
}
```

**Why a failable init and not a `validate()` method?** Because `validate()` can be forgotten. A failable initialiser makes *"an invalid `Money` value does not exist"* a compile-and-runtime guarantee. This is the single most useful encapsulation habit in domain modelling.

**Why `let` properties?** Immutability removes a whole class of bugs and makes the type trivially thread-safe — relevant in Module 09.

**Why `Decimal`, not `Double`?** `Double` is binary floating point: `0.1 + 0.2 != 0.3`. Never model money with `Double`. Interviewers notice.

**The force-unwrap in `add`** is safe and deliberate: both amounts are non-negative and the currency already passed validation, so the invariant holds by construction. Say that out loud rather than adding a meaningless `guard let`.

---

## E2 — `BankAccount`

```swift
public func withdraw(_ amount: Decimal) throws {
    guard amount > 0 else { throw AccountError.nonPositiveAmount }
    guard amount <= balance else { throw AccountError.insufficientFunds }
    balance -= amount
    history.append(-amount)
}
```

**Validate-then-mutate ordering** gives you failure atomicity for free: every `throw` happens before any state changes, so a failed call leaves the object exactly as it was. If you mutate first and validate later you need rollback logic — which is where real bugs live.

**Why `private(set)` rather than `private` + a getter?** Same guarantee, less ceremony, and it reads well: *readable by all, writable by me*.

**Why a class, not a struct?** An account has **identity** — two references must see the same balance. That's the §2 rule. `Money` is a value; `Account` is an entity.

**Interview probe you should be ready for:** *"is this thread-safe?"* No. Two concurrent `withdraw` calls can both pass the guard and overdraw — a classic check-then-act race. The fix is an `actor` or a lock, and it's Module 09.

---

## E3 — `Shape`

```swift
public func totalArea(_ shapes: [any Shape]) -> Double { shapes.reduce(0) { $0 + $1.area() } }
```

**Why `[any Shape]` and not generics?** Generics give a *homogeneous* collection (`[Circle]` only). The point of the exercise is a mixed bag. `any` boxes each element and dispatches dynamically — slightly slower, infinitely more useful here.

**What you did not write:** `if let c = shape as? Circle { ... }`. Type-switching means the polymorphism is fake, and adding `Hexagon` would mean editing every switch. Each new shape here is one new file and zero edits — that's the Open/Closed Principle arriving early.

**`map(\.name)`** — keypath shorthand; idiomatic Swift and shorter than a closure.

---

## E4 — `Notifier`

```swift
public func adding(_ channel: any Channel) -> Notifier { Notifier(channels: channels + [channel]) }
```

**The inheritance version you avoided** would need `EmailNotifier`, `SMSNotifier`, `EmailAndSMSNotifier`, `EmailAndSlackNotifier`… 2^N types for N channels. Composition: N types, any combination at runtime.

**Why return a new `Notifier` instead of `mutating func add`?** Both are defensible. Returning a new value makes the type safe to share across threads and supports chaining. In an interview, state the tradeoff: immutable values are easier to reason about; mutation is cheaper when the collection is large.

**`forEach` vs `for`** — equivalent here. Use `for` when you need `break`/`continue`; `forEach` can't break.

This is already the **Composite** pattern in embryo (Module 06) and a `Notifier` that also accepted another `Notifier` as a `Channel` would be the full pattern. Worth trying.

---

## E5 — Value vs reference

```swift
public struct Playlist { public private(set) var songs: [String]
    public mutating func add(_ s: String) { songs.append(s) } }

public final class SharedPlaylist { public private(set) var songs: [String]
    public func add(_ s: String) { songs.append(s) }
    public func copy() -> SharedPlaylist { SharedPlaylist(songs: songs) } }
```

**`mutating` is required on the struct** because value-type methods can't change `self` otherwise; the compiler is forcing you to notice that mutation on a value type only affects *this* copy.

**Why no `mutating` on the class?** The reference is constant, the instance's storage is not. `let s = SharedPlaylist(); s.add("x")` compiles — and that asymmetry is exactly what bites people.

**Where this bug shows up for real:** a parking lot storing `struct Spot` in an array, a `for spot in spots { spot.occupy() }` loop (which iterates over *copies*), and a lot that never fills up. Either store a class, or mutate in place via index/`indices`.

**`copy()`** here is the **Prototype** pattern's core idea (Module 05), and it's what `NSCopying` formalises in Foundation.

---

## E6 — `Vehicle`

```swift
public protocol Vehicle { var name: String { get }; var wheels: Int { get }; func honk() -> String }
public extension Vehicle {
    func honk() -> String { "beep" }
    var summary: String { "\(name) with \(wheels) wheels" }
}
```

**The grading test that matters** is `test_overrideIsDynamicallyDispatchedThroughExistential`. `honk()` is declared **in the protocol body**, so conformers land in the witness table and `Truck`'s override wins even through `any Vehicle`. Delete that declaration, leaving `honk()` only in the extension, and the array prints `["beep", "beep"]` — silently wrong, no warning.

**Rule to memorise:** *extension-only member = static dispatch = not overridable. If conformers should be able to override it, declare it in the protocol.*

**`summary` is intentionally extension-only** — it's derived from `name` and `wheels`, nobody should override it, and static dispatch is the correct choice.

**How this replaces an abstract class:** required members = abstract methods, extension defaults = concrete superclass methods, and `struct` types can conform — which a Java abstract class could never offer.

---

## E7 — `PortfolioService`

```swift
public init(feed: any PriceFeed) { self.feed = feed }

public func totalValue(of holdings: [Holding]) -> Decimal {
    holdings.reduce(0) { running, h in
        guard let unit = feed.price(for: h.ticker) else { return running }
        return running + unit * Decimal(h.quantity)
    }
}
```

**The design point is one line: the dependency arrives through `init`.** That single decision gives you (a) testability — the suite passes a `StubFeed`; (b) swappability — live feed, cached feed, mock feed, all without touching this type; (c) explicit dependencies — the initialiser documents exactly what this service needs.

**Coupling level achieved:** message coupling (level 6 in README §9) — `PortfolioService` knows a protocol, nothing more.

**Why skip unknown tickers instead of throwing?** Because the spec said so — and that's the real lesson: "unknown ticker" is a *product decision* (skip / throw / treat as zero / return partial-with-warnings), not a coding decision. In an interview, ask.

**`Decimal(h.quantity)`** — Swift won't implicitly convert `Int` to `Decimal`. No accidental numeric coercions; a feature, not friction.

---

## E8 — `UserService`

```swift
public func register(_ user: User) throws {
    guard user.email.contains("@") else { throw RegistrationError.invalidEmail }
    guard !repository.exists(email: user.email) else { throw RegistrationError.duplicateEmail }
    try repository.save(user)
    try mailer.sendWelcome(to: user)
}
```

**Four lines, four responsibilities — none of them owned here.** `UserService` validates and sequences. Persistence lives behind `UserRepository`; messaging lives behind `Mailer`. That's high cohesion: the reason to change this type is *"the registration workflow changed"*, and nothing else.

**Cheapest check first** — the `@` validation needs no collaborator, so it runs before the repository lookup. Ordering guards by cost is a free win.

**`try` not `try?`.** `try?` would swallow a database failure and cheerfully send a welcome email for a user that was never saved. The test `test_doesNotMailIfSaveFails` exists to catch exactly that.

**What's still wrong with this code (be ready to say it):** save and mail are not atomic. If the mailer throws, the user is saved but never welcomed. Real fixes: enqueue the mail as an outbox job, or make the whole thing a transaction, or make the mail retriable and idempotent. Naming this unprompted is a senior signal.

**Preview:** you just wrote the **Repository** pattern, **Dependency Injection**, and a **Service** layer. Module 02 will name what makes it good (SRP + DIP); Module 14 shows the same shape inside an iOS app.

---

## Self-check

| If you… | Re-read |
|---|---|
| put validation in the caller instead of the type | §3 Encapsulation |
| wrote `if shape is Circle` anywhere | §6 Polymorphism |
| subclassed `Notifier` for each channel | §8 Composition over Inheritance |
| were surprised by any E5 assertion | §2 struct vs class |
| were surprised that `Truck` printed `"beep"` | §7 dispatch trap |
| constructed a `PriceFeed` inside `PortfolioService` | §9 Coupling |
| put `save` logic inside `UserService` | §9 Cohesion |
