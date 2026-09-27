# Module 05 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M05`.

### E1 — Singleton, done properly
`AppConfig.shared` with a `private init`, plus a `ConfigProviding` protocol so `FeatureGate` can be tested with a stub while still defaulting to the singleton.
*The graded idea:* a singleton you can substitute is a convenience; a singleton you can't is a liability.

### E2 — Simple factory vs registry
`SimpleShapeFactory` uses one exhaustive `switch` (closed set, compiler-checked). `ShapeRegistry` maps keys to closures (open set). The grader registers a shape type it defines itself.
*The graded idea:* pick the mechanism from whether the set of kinds is closed or open — not from pattern fashion.

### E3 — Factory Method
`ReportWriter` must depend only on `ExporterFactory`. The grader supplies a `PipeFactory` the writer has never seen.
*Watch for:* if `ReportWriter` ever mentions `CSVExporter`, the indirection bought you nothing.

### E4 — Abstract Factory
Two families, each producing a matching button and checkbox. The grader asserts renders always share the family prefix — i.e. you can never mix a light button with a dark checkbox.

### E5 — Builder
Fluent chaining with `@discardableResult func … -> Self`, and **three cross-field validations that can only run at `build()`**. One test builds the request across three separate functions — that's the scenario where Builder genuinely beats default arguments.

### E6 — Prototype
`deepCopy()` must recurse; `shallowCopy()` must deliberately share children, and the test proves the hazard by mutating through the copy.

### E7 — Object Pool
Acquire/release/reuse, plus the three design answers: exhaustion throws, release resets state, and a double release or foreign object throws instead of corrupting the pool.

## Stretch (not graded)
1. Rewrite `ConnectionPool` as an `actor`. Which method signatures change and why? (Module 09 preview.)
2. Turn `ShapeRegistry` into a generic `Registry<Key: Hashable, Product>`. Did it get better or just cleverer?
3. Add a `Director` to E5 that produces `makeJSONPost` and `makeAuthenticatedGET`. What does the director own that the builder doesn't?
4. Give `TreeNode` value semantics by turning it into a `struct` with an array of children. Does `deepCopy()` still need to exist?
5. Add `Slider` to E4's product family. Count the files you had to edit — that's Abstract Factory's known weakness, measured.
