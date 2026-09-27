# Module 02 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — SRP
```swift
public func process(_ order: Order) throws -> Decimal {
    let total = calculator.total(of: order)
    try store.save(order, total: total)
    try mailer.mailReceipt(for: order, total: total)
    return total
}
```
Four responsibilities became four types with four distinct actors: finance owns `OrderTotalCalculator`, infrastructure owns the `OrderStore` implementations, marketing owns the mailer, and the *workflow* — which is itself a legitimate responsibility — stays in `OrderService`.

`OrderService` is 4 lines because all the knowledge moved to where it belongs. That's the SRP payoff: orchestration code becomes boring, and boring code is correct code.

Note what did **not** happen: no `OrderManager`, no `OrderHelper`. Every type name states a responsibility.

## E2 — OCP
```swift
public func finalPrice(base: Decimal, policies: [any DiscountPolicy]) -> Decimal {
    policies.reduce(base) { running, policy in max(0, running - policy.discount(on: running)) }
}
```
The engine never learns what a policy *is*. `WeekendDoubleDiscount` in the test was written after the engine and works without touching it — that is the definition of "closed for modification, open for extension".

Two design decisions worth defending out loud:
- **Folding over the running amount** (rather than over `base`) means order matters. That's a product rule; a different business might want all discounts computed on the base. Ask.
- **Clamping at 0 inside the fold**, not only at the end, keeps every intermediate value legal.

`FlatDiscount` uses `min(amount, price)` so the *policy* guarantees it never over-discounts. Invariants belong in the type that owns them (Module 01 §3), not in the engine.

## E3 — LSP
The fix isn't clever code, it's a **smaller protocol**. `FrozenArchive` genuinely cannot write, so it must not claim to. Once the type system says so, `copyAll(from:to:)` can trust its parameters: it asks for `any WritableStore` as the destination and the compiler guarantees write works. No runtime "unsupported" branch exists to test, because it cannot be constructed.

Observe: `WritableStore: ReadableStore` **adds** capability. Protocol hierarchies are safe when subtypes only widen the contract. Trouble starts when a subtype narrows it.

This is also ISP — the two principles collaborate constantly. LSP violations are very often fat protocols that some conformer can't honour.

## E4 — ISP
```swift
public func printAll(_ documents: [String], on device: any Printing) -> [String]
```
The signature is the whole lesson: **depend on the narrowest role that does the job.** `printAll` works with a £40 printer and a £4000 office machine because it asks for neither — it asks for `Printing`.

In Swift you can also write `some Printing & Scanning` at the use site to require exactly two roles, which is composition of requirements without inventing a `PrintingScanner` protocol.

## E5 — DIP
```swift
public init(clock: any Clock, source: any MetricsSource) { self.clock = clock; self.source = source }
```
Two dependencies, both inverted, both injected through `init`. The grader's `FixedClock` proves the point: time became a *parameter* instead of an ambient global, so a report's timestamp is now a testable value.

`Clock` is the highest-value protocol most codebases are missing. Anything that calls `Date()`, `UUID()`, `Int.random()` or `URLSession.shared` deep inside domain logic is untestable for the same reason.

Note the abstraction's vocabulary: `values(for key:)` — domain language, not `SELECT * FROM metrics`. DIP's second sentence satisfied.

## E6 — Classification
| Smell | Principle | Why |
|---|---|---|
| persistence + business rules | SRP | two actors |
| growing switch over a type tag | OCP | every new case edits old code |
| override throws "unsupported" | LSP | strengthened precondition |
| empty method bodies in a conformance | ISP | protocol forces unneeded members |
| service constructs its own database | DIP | policy depends on mechanism |
| can't test without a real clock | DIP | ambient dependency not injected |
| subclass weakens a postcondition | LSP | caller's guarantee broken |
| God class named `XManager` | SRP | many reasons to change |

## Self-check
| If you… | Re-read |
|---|---|
| left tax logic inside `OrderService` | §S |
| wrote a `switch` in `PriceEngine` | §O |
| gave `FrozenArchive` a throwing `write` | §L |
| wrote an empty `scan()` | §I |
| called `Date()` inside `report(for:)` | §D |
