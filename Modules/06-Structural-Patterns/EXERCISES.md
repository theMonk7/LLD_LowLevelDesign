# Module 06 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M06`.

### E1 — Adapter
Wrap `LegacyPayGateway` (rupees as `Double`, `[String: Any]` result, status strings) behind `PaymentProcessor` (paise as `Int`, typed `throws`). Perform all three translations: shape, units, error model.

### E2 — Bridge
Two shapes × two renderers, as **four** types, not four combinations. The grader adds a third renderer and expects both existing shapes to work with it untouched.

### E3 — Composite
`FolderItem` and `FileItem` both conform to `FileSystemItem`. `size()` recurses; `paths(prefix:)` emits parents before children, depth-first. The last test sums a single file and a whole tree in one `reduce` — that uniformity is the pattern.

### E4 — Decorator (pricing)
Stackable `Milk`, `Caramel`, `Tax`. The `Tax` test proves **order matters**: taxing before or after adding milk gives different totals. Be able to explain which is correct for a real café and why that's a product question.

### E5 — Decorator (cross-cutting)
The production-grade version: `Caching`, `Logging`, `Retrying` around a repository.
Details the grader checks: failures are **not** cached; the log records attempts even when they throw; retry fires only on `.transient` and counts *total* attempts; a stacked chain behaves predictably.

### E6 — Facade
One `convert` call over a four-step pipeline. Keep it pure delegation — no branching, no rules.

### E7 — Flyweight
`PieceTypeFactory` returns the same instance per name. 32 pieces, 6 shared types, identity asserted with `===`.

### E8 — Proxy
Protection proxy (role check) and virtual proxy (build on first access, exactly once).

### E9 — Identification
Map each scenario to its pattern.

## Stretch (not graded)
1. Rewrite E5's decorators as one generic `Decorated<Base>` type. Is it better? What did you lose?
2. Add `remove(child:)` to E3. Put it on the protocol and on the composite only — write both versions and describe what breaks in each.
3. Make E7's factory thread-safe. Which of `NSLock`, a serial queue and an `actor` would you pick, and what changes in the call site? (Module 09.)
4. Express E4 with a `reduce` over an array of price modifiers instead of nested types. What did you gain, and what did the Decorator give you that this doesn't?
5. Convert E1's adapter into a retroactive `extension LegacyPayGateway: PaymentProcessor`. When is that better, and when is it a mistake?
