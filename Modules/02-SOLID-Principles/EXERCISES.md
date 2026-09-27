# Module 02 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M02`.

### E1 — SRP: split `LegacyOrderProcessor`
The legacy class computes tax, saves, mails and renders in one method. Build the split version: `OrderTotalCalculator` (pure finance), `OrderStore`/`ReceiptMailer` (protocols), `OrderService` (orchestration only). Save must abort before mailing on failure.
*Watch for:* keeping the tax rate as a stored dependency rather than a hardcoded literal is what makes the calculator reusable and testable.

### E2 — OCP: a price engine closed for modification
Implement `NoDiscount`, `PercentageDiscount`, `FlatDiscount` and a `PriceEngine` that folds a list of policies. **No `switch`, no `if` over policy type.** The grader defines a brand-new policy inside the test — if your engine needs editing to support it, you failed the principle, not the test.

### E3 — LSP: repair the hierarchy
`FrozenArchive` is read-only. Make it conform to `ReadableStore` only, so it never needs a `write` that throws "unsupported". `copyAll(from:to:)` takes the narrow types and must work with any combination.
*Watch for:* the grader passes both `FrozenArchive` and `InMemoryStore` as the source — no type checks allowed.

### E4 — ISP: split the multifunction device
`BasicPrinter` conforms to `Printing` alone; `OfficeMachine` conforms to all three roles. `printAll` depends on the narrowest protocol that does the job.
*Watch for:* if you ever write an empty `func scan() {}`, you've recreated the fat protocol.

### E5 — DIP: invert clock and data source
`ReportService` takes `any Clock` and `any MetricsSource`. Calling `Date()` inside `report(for:)` fails the grader — deliberately, because that's the untestable habit being trained out.

### E6 — Smell → principle
Fill the mapping in `principleViolated(by:)`. Pure recall; if you get one wrong, re-read that section.

## Stretch (not graded)
1. Make `PriceEngine` report *why* a price is what it is (a breakdown per policy). Which SOLID letter pushed you toward the new type?
2. Add an `OrderStore` that writes to disk. How many existing files did you edit? If more than zero, DIP is incomplete.
3. Design a `ShippingPolicy` set where one policy needs the customer's tier. Does the protocol change, or the input type? Argue both.
4. Find a `switch` in your own day-job codebase that is *correctly* a switch (closed domain). Write down why.
