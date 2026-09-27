# Module 06 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — Adapter
```swift
let rupees = Double(amountInPaise) / 100.0
let raw = sdk.makePayment(rupees, ref: orderID, currency: "INR")
guard let status = raw["status"] as? String else { throw PaymentError.malformedResponse }
guard status == "OK" else { throw PaymentError.declined }
guard let txn = raw["txn"] as? String else { throw PaymentError.malformedResponse }
```
Three translations, in three lines, and each one is a place bugs live in real code:
- **Units.** Money in paise as `Int` inside the domain, rupees as `Double` only at the SDK edge. Keeping `Double` money out of the domain is half the value of the adapter.
- **Shape.** Parameter names and order are the SDK's problem now, not the domain's.
- **Errors.** A status string becomes a typed Swift error. Note the separate `.malformedResponse`: a missing `txn` on an "OK" response is a *different* failure from a decline, and collapsing them would hide a server bug as a payment decline.

The domain now depends on `PaymentProcessor` only, so swapping to a new gateway is one new adapter and one line at the composition root.

## E2 — Bridge
```swift
public struct Circle6: Shape6 {
    private let radius: Double
    private let renderer: any Renderer        // ← the bridge
    public func draw() -> String { renderer.renderCircle(radius: radius) }
}
```
Two shapes and three renderers = **five** types. Without the bridge it's six, and with five shapes and four renderers it's twenty versus nine. The saving is multiplicative, which is why Bridge matters exactly when both dimensions grow.

The test that proves it adds `JSONRenderer` and both existing shapes render through it with zero edits.

Design wrinkle worth noticing: `Renderer` has one method **per shape**, so adding a shape means editing every renderer. That's the same axis asymmetry as Abstract Factory (Module 05 §3). The alternative — a generic `render(_ primitive: Primitive)` with a small primitive vocabulary — trades type safety for extensibility. Naming that tradeoff is the senior answer.

## E3 — Composite
```swift
public func size() -> Int { children.reduce(0) { $0 + $1.size() } }
public func paths(prefix: String) -> [String] {
    let here = "\(prefix)/\(name)"
    return [here] + children.flatMap { $0.paths(prefix: here) }
}
```
The composite calls the *protocol* method on its children, so nesting works to any depth without a single type check. `[here] + children.flatMap { ... }` gives parents-before-children ordering; swap the concatenation and you have post-order.

Note what is *not* here: `add(child:)`. Making `children` a `let` in the initialiser keeps the tree immutable and sidesteps the "does a file have `add`?" LSP problem entirely. When mutability is required, put `add` on `FolderItem` only and accept that callers must know they hold a folder — type safety over uniformity. Be ready to argue both sides; GoF chose the other one.

## E4 — Decorator (pricing)
```swift
public func cost() -> Decimal { base.cost() * (1 + rate) }
```
`Tax(Milk(Espresso()))` = 154; `Milk(Tax(Espresso()))` = 152. Same three objects, different composition, different answer.

That's not a flaw — it's the pattern being honest that **composition order is semantics**. In a real café, tax applies to the final line total, so tax must be outermost, and a good design makes that hard to get wrong (e.g. tax isn't a decorator at all; it's applied once by the till). Saying "I wouldn't model tax as a decorator, because it isn't optional and it isn't stackable" is a better answer than implementing it.

Each decorator is tiny and knows nothing about the others, so `Milk(Milk(Espresso()))` — double milk — works without anyone planning for it.

## E5 — Decorator (cross-cutting)
This is the version you'll actually write at work.

```swift
let fresh = try base.name(forID: id)   // a throw propagates and is NOT cached
cache[id] = fresh
```
**Not caching failures** is deliberate: cache a `.notFound` and the user who just signed up stays missing. If you *do* want negative caching, it needs its own TTL — a separate decision, not an accident of where you put the assignment.

```swift
log.append("get:\(id)")
return try base.name(forID: id)
```
Logging **before** the call means failed attempts appear in the log. Log after, and the entries you most need when debugging are the ones missing.

```swift
catch RepoError.transient { lastError = RepoError.transient; continue }
catch { throw error }
```
Retrying only transient errors is what separates a retry policy from an infinite loop against a permanent failure. `maxAttempts` counts *total* attempts, not retries — an ambiguity worth clarifying aloud, since "3 retries" and "3 attempts" differ by one call in production.

Ordering: the graded stack is `Caching(Retrying(Logging(base)))` — retries happen only on cache misses, and every physical attempt is logged. Invert caching and retrying and you retry cache lookups, which is pointless. Invert logging and caching and cache hits vanish from the log.

Four orthogonal concerns, four small types, wired once at the composition root, none aware of the others. That's the payoff.

## E6 — Facade
Four steps, one call, **no logic**. The moment a facade starts deciding *whether* to extract audio, it has business rules and is becoming a God Object. Keep it a wiring convenience and leave the subsystem reachable for advanced callers.

## E7 — Flyweight
```swift
if let hit = cache[name] { return hit }
```
Identity (`===`) is the whole test. 32 pieces hold 32 references to 6 objects, so the per-piece cost is a pointer plus square and colour.

Two correctness requirements the code embodies: `PieceType` has only `let` properties (shared mutable state would be a global-state bug), and the factory is the only way to obtain one. Not thread-safe as written — Module 09.

Honest framing for an interview: for a chess board, this is over-engineering and you should say so. For a particle system, a tile map, or a text editor's glyph cache, it's the difference between shipping and OOM.

## E8 — Proxy
```swift
guard role == .admin else { throw AccessError.forbidden }     // protection
if loaded == nil { makeCallCount += 1; loaded = make() }      // virtual
```
Both keep `Document6` unchanged — that's what makes them proxies rather than adapters. Neither adds a capability the caller asked for — that's what makes them proxies rather than decorators.

`LazyDocument` is a class because it caches; `SecureDocument` is a struct because it's stateless. Swift's `lazy var` is the same virtual-proxy idea built into the language.

## E9 — Identification
| Scenario | Pattern | Tell |
|---|---|---|
| SDK method names differ | Adapter | interface changes |
| add caching without changing the repo | Decorator | same interface, added behaviour |
| folder and file treated identically | Composite | recursive containment |
| one call over four steps | Facade | new simpler interface |
| deny reads unless admin | Proxy | same interface, access control |
| M shapes × N renderers | Bridge | two independent hierarchies |
| millions sharing one texture | Flyweight | shared intrinsic state |

## Self-check
| If you… | Re-read |
|---|---|
| let `Double` money into the domain | §1 |
| created a type per shape-renderer pair | §2 |
| put `add` on the leaf | §3 |
| were surprised by the tax ordering test | §4 |
| cached a failure, or logged after the call | §4 (cross-cutting) |
| put a branch inside the facade | §5 |
| made flyweight state mutable | §6 |
| couldn't distinguish proxy from decorator | §7 |
