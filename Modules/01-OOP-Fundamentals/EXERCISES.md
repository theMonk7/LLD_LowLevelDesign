# Module 01 — Exercises

Open [`Code/Exercises.swift`](Code/Exercises.swift) and replace every `fatalError("TODO ...")`.
**Do not change the public signatures** — the grader in [`Tests/M01Tests.swift`](Tests/M01Tests.swift) compiles against them.

```bash
swift test --filter M01        # all 8
swift test --filter E3Shape    # one exercise
```

Expect red first. Red → green on your own code is the whole exercise.

---

### E1 — `Money`: a value type that cannot be invalid  *(encapsulation, value semantics)*
Build a `Money` struct that **refuses to exist** in an invalid state: negative amount or a currency that isn't a 3-letter uppercase code returns `nil` from the failable initialiser. `Money.add` throws `.currencyMismatch` across currencies.

*Concept under test:* validation belongs in the type, not in every caller. Compare with a `struct Money { var amount: Decimal }` that anyone can set to `-999`.

---

### E2 — `BankAccount`: invariants enforced by behaviour  *(encapsulation)*
`balance` is `private(set)`. Deposits and withdrawals validate, mutate, and append a **signed** amount to `history`. A rejected operation must leave both `balance` and `history` untouched.

*Concept under test:* "the balance can never go negative" is a property of the class, not of the caller's discipline. Watch the failure-atomicity detail — validate before you mutate.

---

### E3 — `Shape`: abstraction + subtype polymorphism
Implement `Circle`, `Rectangle`, `Triangle` conforming to `Shape`, then `totalArea(_:)` and `namesOfShapesLarger(than:in:)` over a **heterogeneous** `[any Shape]`.

*Concept under test:* the caller treats all shapes identically; each type supplies its own `area()`. Notice you wrote **zero** `if shape is Circle` checks — that's what polymorphism buys. (A `switch` over shape types here would be a Module 02 open/closed violation.)

---

### E4 — `Notifier`: composition over inheritance
`Notifier` holds `[any Channel]` and delivers to each in order. `adding(_:)` returns a **new** `Notifier` without mutating the receiver.

*Concept under test:* one `Notifier` + N channels replaces 2^N subclasses. The immutability of `adding` is what makes value-type composition safe to share.

---

### E5 — `Playlist` vs `SharedPlaylist`: value vs reference semantics
Same data, two semantics. Struct copies must be independent; class references must alias; `copy()` on the class must be a genuine defensive copy.

*Concept under test:* the single most common machine-coding bug. If you can't predict all three assertions before running the test, re-read §2 of the README.

---

### E6 — `Vehicle`: protocol + extension as Swift's abstract class
Give `Bike` and `Truck` their `name`/`wheels`. Implement the shared `summary` in the extension. `Bike` inherits the default `honk()`; `Truck` overrides it with `"HOOONK"` — and the override must still win when called through `any Vehicle`.

*Concept under test:* the static/dynamic dispatch trap. `honk()` is declared in the protocol body, so the override wins. If it were extension-only, the array test would print `"beep"` twice.

---

### E7 — `PortfolioService`: low coupling through injection
Depend on `any PriceFeed`, never construct a feed inside. Unknown tickers are skipped by `totalValue` and reported by `unpricedTickers`.

*Concept under test:* the test injects a stub feed, and a second test injects a completely different one. Neither could exist if you'd hardcoded `LivePriceFeed()`. This is coupling level 6 (message coupling) and a preview of Dependency Inversion.

---

### E8 — `UserService`: high cohesion by splitting responsibilities
Orchestrate only: validate → duplicate check → save → mail, in that order, short-circuiting on each failure. `UserService` must contain no persistence and no mail logic.

*Concept under test:* the God-class split. The "don't mail if save throws" test is checking that you used `try` (propagate) rather than `try?` (swallow) — silent failure is a design bug, not a style nit.

---

## Stretch (not graded)

1. Make `Money` conform to `Comparable` and `CustomStringConvertible`. What breaks if you allow comparing different currencies?
2. Add an `AuditedAccount` **by composition** (wraps `BankAccount`, records every call) instead of by subclassing. Which is easier to test, and why?
3. Change `Notifier.send` so one failing channel doesn't stop the rest. What does the signature have to become? What does that tell you about error design?
4. Rewrite E7's `PortfolioService` with a generic `<F: PriceFeed>` instead of `any PriceFeed`. What do you gain, what do you lose?
