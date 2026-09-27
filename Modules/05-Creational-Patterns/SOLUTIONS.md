# Module 05 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — Singleton
```swift
public static let shared = AppConfig(values: [...])
private init(values: [String: String]) { self.values = values }
...
public init(config: any ConfigProviding = AppConfig.shared) { self.config = config }
```
Three things are doing work here:
- **`static let`** gives lazy, once-only, thread-safe initialisation. Swift's runtime handles it with `swift_once`; you write no locking code. Interviewers who expect the Java double-checked-locking answer are testing whether you know the language you claim.
- **`private init`** is what actually enforces "only one". Without it you have a *convenience accessor*, not a singleton.
- **The defaulted parameter** is the whole trick: call sites stay clean (`FeatureGate()`), tests stay honest (`FeatureGate(config: StubConfig(...))`). You get the singleton's ergonomics without its untestability.

`values` is immutable, which is why this singleton is safe. A singleton holding mutable state needs an `actor` or a lock, and at that point ask whether it should be injected and owned instead.

## E2 — Simple factory vs registry
```swift
public static func make(_ kind: ShapeKind, size: Double) -> any Shape5 {
    switch kind { case .circle: Circle5(radius: size); case .square: Square5(side: size) }
}
```
The switch is *not* a smell here: `ShapeKind` is a closed enum, and exhaustiveness means adding a case produces a compile error pointing at the one place to update. That's the compiler enforcing OCP's intent better than a protocol could.

```swift
public func register(_ key: String, maker: @escaping (Double) -> any Shape5) { makers[key] = maker }
```
The registry is the open-set version, and it's the **idiomatic Swift Factory**: a dictionary of closures, no protocol, no one class per product. The grader's `Triangle5` — defined inside the test — works without touching `ShapeRegistry`.

`make` returns an Optional rather than trapping on an unknown key: unknown input is a normal condition at a registry boundary, not a programmer error.

## E3 — Factory Method
```swift
public func write(_ rows: [[String]]) -> (filename: String, body: String) {
    let exporter = factory.makeExporter()
    return ("report.\(exporter.fileExtension)", exporter.export(rows))
}
```
`ReportWriter` never names a concrete exporter, so `PipeFactory` drops in unseen. Note that `fileExtension` lives on the **product**, not the writer — otherwise the writer would need a `switch` to map factory to extension, re-introducing the coupling the pattern removed. Where information lives determines whether a pattern actually works (Information Expert, Module 03 §10).

Honest assessment: for two exporters in one app, `ReportWriter(exporter: any Exporter)` — injecting the product directly — is simpler and just as extensible. Factory Method earns its keep when the *creation itself* varies (needs configuration, pooling, or per-call construction). Say that out loud; it shows judgment rather than pattern reflex.

## E4 — Abstract Factory
```swift
public func render() -> [String] { [theme.makeButton().render(), theme.makeCheckbox().render()] }
```
The invariant the pattern buys is *consistency*: `SettingsScreen` cannot mix families because it never chooses products, only a factory. The grader's loop asserts every render starts with the theme name — that assertion is the pattern's entire reason to exist.

The cost, which the stretch exercise makes you feel: adding `Slider` means editing `ThemeFactory` and **every** conforming theme. Open to new families, closed to new products. If products churn faster than families, use separate Factory Methods or a registry keyed by `(family, product)`.

## E5 — Builder
```swift
public func build() throws -> HTTPRequest5 {
    if method == "GET", body != nil { throw BuildError.bodyOnGET }
    if retries < 0 { throw BuildError.negativeRetries }
    if body != nil, headers["Content-Type"] == nil { throw BuildError.missingContentTypeForBody }
    return HTTPRequest5(...)
}
```
All three rules span **more than one field**, so none of them can be checked in a property setter — that's precisely the condition under which Builder beats default arguments in Swift.

`@discardableResult ... -> Self` gives the fluent chain; `Self` (not the concrete class) keeps the chain working for subclasses.

The builder is a `class` deliberately: `test_incrementalConstructionAcrossFunctions` passes it to two functions that mutate it. A `struct` builder would hand each function a copy and silently lose their changes — the Module 01 §2 bug, appearing in a real design decision.

Note the request itself is an immutable `struct` with `let` fields. **Mutable builder, immutable product** is the shape you want: all the churn during construction, none afterwards.

## E6 — Prototype
```swift
public func deepCopy() -> TreeNode { TreeNode(value: value, children: children.map { $0.deepCopy() }) }
public func shallowCopy() -> TreeNode { TreeNode(value: value, children: children) }
```
One line apart, completely different semantics. The shallow test deliberately demonstrates the hazard: mutating `copy.children[0].value` changes the original, because both arrays hold the *same* `TreeNode` references. An array copy copies the references, not the objects.

This is why Prototype is a reference-type pattern. Make `TreeNode` a `struct` and `let copy = original` is already a deep copy, with copy-on-write making it cheap. Swift solved the common case at the language level; you need `deepCopy()` only where identity or class inheritance forces a class.

Foundation parallel: `NSMutableArray.copy()` is shallow. Knowing that distinction is a routine interview question.

## E7 — Object Pool
```swift
public func acquire() throws -> PooledConnection {
    if let reused = available.popLast() { inUseIDs.insert(reused.id); return reused }
    guard created < maxSize else { throw PoolError.exhausted }
    created += 1
    ...
}
public func release(_ c: PooledConnection) throws {
    guard inUseIDs.remove(c.id) != nil else { throw PoolError.foreignObject }
    c.reset()
    available.append(c)
}
```
Every line answers one of the three pool questions:
- **Exhaustion** → throw. The alternatives (block with timeout, grow past max) are equally valid *if stated*; silently growing is how you exhaust the database instead of the pool.
- **Reset on release** → `c.reset()` before it goes back. Skip it and connection #1 hands the next client the previous client's `scratch`. That's a data-leak bug, and it's the one interviewers probe for.
- **Foreign / double release** → `inUseIDs.remove` returning nil catches both. Without that guard, a double release puts the same connection in `available` twice and two clients get the same connection — the worst possible pool bug, and the reason the test asserts `availableCount == 1`.

`created` is tracked separately from `available.count + inUseIDs.count` so the pool never exceeds `maxSize` lifetime instances even as objects move between the two collections.

Not thread-safe as written. Under concurrency it needs a lock or an `actor` — Module 09.

## Self-check
| If you… | Re-read |
|---|---|
| left `init` internal on `AppConfig` | §1 |
| wrote a registry when the set was closed (or vice versa) | §2 |
| mentioned a concrete exporter inside `ReportWriter` | §2 Factory Method |
| let a screen construct products directly | §3 Abstract Factory |
| validated fields in setters instead of `build()` | §4 |
| made `shallowCopy` recurse | §5 |
| forgot `reset()` or the double-release guard | §6 |
