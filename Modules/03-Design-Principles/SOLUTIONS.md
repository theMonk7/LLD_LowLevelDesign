# Module 03 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — DRY
```swift
public init?(_ raw: String) {
    guard (3...20).contains(raw.count),
          raw.allSatisfy({ $0.isLetter || $0.isNumber }),
          raw.first?.isLetter == true
    else { return nil }
    self.value = raw
}
public func validate(username raw: String) -> Bool { Username(raw) != nil }
public func importUsers(_ raws: [String]) -> [Username] { raws.compactMap(Username.init) }
```
Both consumers are one line, because the knowledge lives in the type. This is DRY done through a **type**, not through a shared function — which is stronger: a shared `isValidUsername(_:)` function can be forgotten, but a `Username` value *cannot exist* unless the rule passed. The type carries proof.

`compactMap(Username.init)` — a failable initialiser is a function `(String) -> Username?`, so it drops straight into `compactMap`. Idiomatic and impossible to get out of sync.

## E2 — KISS
Normalising through celsius means each new scale costs **two** cases, not 2N pairwise conversions. Nine cases become six lines.

The "enterprise" version you avoided:
```swift
protocol TemperatureConverter { func toCelsius(_ v: Double) -> Double; func fromCelsius(_ v: Double) -> Double }
final class ConverterRegistry { static let shared = ConverterRegistry(); private var map: [TemperatureScale: any TemperatureConverter] = [:] ... }
```
It's not *wrong* — it's OCP-correct. It's just unpaid-for. There are three scales, there have been three since 1848, and a registry buys you an extension axis nobody will use. That trade is YAGNI's entire argument, and here the exhaustive `switch` is a *feature*: add a scale and the compiler names both places to edit.

**The interview sentence:** *"I'd use an enum and an exhaustive switch here because the set is closed; if scales were plugin-supplied I'd invert it behind a protocol."*

## E3 — Law of Demeter
Four one-line accessors. `Shipment` now depends on `Customer` only; `City`'s shape is invisible two levels up. Rename `City.name` to `City.title` and exactly one file changes.

Also notice the cost honestly: you wrote four methods to avoid one expression. Applied everywhere, this is Demeter bloat. Apply it where the chain crosses a boundary you expect to change, or where you would otherwise **mutate** someone else's internals — `order.customer.wallet.balance -= x` is the truly dangerous form, because it bypasses every invariant `Wallet` has.

## E4 — Tell, Don't Ask
```swift
public func shippingCost(freeOver threshold: Decimal, otherwise fee: Decimal) throws -> Decimal {
    guard !items.isEmpty else { throw CartError.emptyCart }
    return total >= threshold ? 0 : fee
}
```
The Ask version — `if cart.total >= 500 { 0 } else { 60 }` at the call site — puts the rule in the caller, so every caller repeats it and one will get it wrong. Here the cart decides; callers state intent.

`subtotal` on `CartItem` and `total` on `Cart` are **Information Expert**: the type holding the data does the computation. Once those exist, the anemic `CartCalculatorService` has nothing left to do — which is the correct outcome.

`add` merging by sku while keeping the first unit price is deliberately a rule you could not have guessed. In an interview you would *ask*; in this exercise it's written down. Both times, the rule belongs inside `Cart`.

## E5 — Encapsulate what varies
```swift
public func failures(for password: String) -> [String] {
    rules.filter { !$0.isSatisfied(by: password) }.map(\.describe)
}
```
What varies: the rules. What's stable: "run all rules, collect the failures". Separating them means a new rule is a new file.

Returning **which** rules failed rather than a `Bool` costs nothing and gives the UI real feedback. Design for the caller's actual need — an error-free boolean is usually a lossy API.

This is one step from the **Composite** pattern (a policy that contains policies) and identical in shape to E2 of Module 02 — the same skeleton, a different axis of variation. Recognising that two problems share a shape is what pattern fluency actually is.

## E6 — Classification
| Situation | Principle |
|---|---|
| same rule in three screens | DRY |
| protocol with one conformer, no double | KISS |
| config for unrequested features | YAGNI |
| `order.customer.address.city.name` | Demeter |
| read, branch, write back | Tell-Don't-Ask |
| service computes the cart's total | Information Expert |
| need an `OrderRepository` (not a domain noun) | Pure Fabrication |
| framework calls `viewDidLoad` | Hollywood |

## Self-check
| If you… | Re-read |
|---|---|
| re-implemented the username rule in the form | §1 |
| built a converter registry | §2, §3 |
| left `shipment.customer.address.city.name` | §4 |
| read `cart.total` in the caller to decide shipping | §5 |
| put an `if ruleType == ...` in `PasswordPolicy` | §6 |
