# Module 06 Project — Coffee Shop Pricing Engine + Legacy Payment Adapter

**Time:** 3–4 hours. Two connected subsystems, five structural patterns, one runnable demo.

## Part 1 — Pricing engine

> A café sells drinks. A drink has a base (espresso, americano, latte) and any number of add-ons (extra shot, oat milk, syrup, whipped cream). Sizes (small/medium/large) multiply the base price. Combo deals bundle a drink and a pastry at a discount. A loyalty member gets 10% off the final total. Tax is applied to the final total. Receipts must itemise every component.

Requirements:
1. Add-ons are **stackable in any combination** — no class per combination.
2. A **combo** must be priceable as a single item, and a combo can contain another combo.
3. The receipt must list every component in the order it was applied.
4. Tax and loyalty must be applied exactly once, and in the right order, no matter how the drink was built. (Hint: they are *not* decorators. Justify your choice.)
5. Adding a new add-on must be one new file, zero edits.

Patterns you should end up with: **Decorator** (add-ons), **Composite** (combos), and a deliberate *non*-pattern for tax/loyalty.

## Part 2 — Payments

> The café must accept three payment providers: a modern `CardSDK` (typed, throwing), a `LegacyWalletGateway` (string status codes, amounts in rupees as `Double`), and a `CashDrawer` (no network at all). The app's checkout code must know about none of them. Payments should be logged and retried on transient failures. In staging, all payments go to a sandbox that always succeeds.

Requirements:
6. One `PaymentProcessor` protocol; three **Adapters**.
7. Logging and retry added as **Decorators**, not as code inside the adapters.
8. The sandbox is chosen at the composition root — no `if isStaging` anywhere in the domain.
9. A `CheckoutFacade` exposes a single `checkout(order:paymentMethod:)` for the UI layer.
10. An expensive `ReceiptPrinter` must not be constructed until a receipt is actually printed (**Proxy**).

## Deliverables
1. Source files (suggest `Pricing.swift`, `Payments.swift`, `Composition.swift`).
2. `demo()` covering all ten acceptance scenarios below.
3. Tests: add-on stacking, combo nesting, decorator ordering, each adapter's translation, retry behaviour, lazy printer.
4. Mermaid class diagram + a 8–12 bullet decision log, including **one pattern you considered and rejected**.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Large latte + oat milk + 2 shots | correct price, itemised receipt |
| 2 | Same add-ons in a different order | same total (or a documented reason it differs) |
| 3 | Combo (drink + pastry) inside a family combo | recursive total correct |
| 4 | Loyalty + tax on a combo | applied once each, in the stated order |
| 5 | New add-on registered from test code | works, zero library edits |
| 6 | Pay with the legacy wallet | rupee/paise translation correct, status mapped to typed error |
| 7 | Transient wallet failure ×2, then success | succeeds, 3 attempts, all logged |
| 8 | Permanent decline | fails immediately, exactly 1 attempt |
| 9 | Staging composition | every provider routes to the sandbox, domain code unchanged |
| 10 | Checkout without printing | `ReceiptPrinter` never constructed |

## Rubric (/50)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Decorator: add-ons stack, no combination classes | subclass per combo | partial | any combination works |
| Composite: nested combos | flat only | one level | arbitrary nesting |
| Tax/loyalty applied once, correct order | duplicated or order-dependent | partial | provably once, documented order |
| Adapters: all three translations each | interface only | partial | shape + units + errors |
| Decorators for logging/retry (not inline) | inline | one extracted | both, order justified |
| Facade delegates only | contains rules | partial | pure delegation |
| Proxy: lazy printer | eager | partial | built on first use, once |
| Composition root | scattered | partial | single place, staging switch lives only there |
| Tests | none | happy path | ordering, failures, extension |
| Decision log incl. a rejected pattern | absent | thin | tradeoffs + one rejection with reasons |

**40+/50** → Module 07.

## Extension questions
1. You used Decorator for add-ons and rejected it for tax. State the general rule you applied.
2. A regulator requires the receipt to show the pre-tax subtotal. Does your composition still allow that? If not, what does that reveal about deep decorator chains?
3. Where would a Flyweight help here, and would you actually implement it?
4. Convert the retry decorator to async with exponential backoff. What breaks, and why is Module 09 next-but-two?

Ask me to review your implementation against this rubric.
