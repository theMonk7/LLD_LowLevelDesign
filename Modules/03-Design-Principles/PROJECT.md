# Module 03 Project — Principle Audit + Rewrite

**Time:** 2–3 hours. Two halves: find the violations, then fix them without over-correcting.

## Part A — Audit (60 min)

Create `SmellyCheckout.swift` with the code below and annotate **every** violation with a comment naming the principle. Target: 15+ findings.

```swift
import Foundation

struct Item { var sku: String; var price: Double; var qty: Int; var category: String }
struct Customer { var name: String; var tier: String; var address: Address }
struct Address { var line1: String; var city: City }
struct City { var name: String; var pincode: String }

final class CheckoutEngine {
    static let shared = CheckoutEngine()
    var enableLegacyPromoEngine = false
    var enableExperimentalTaxV2 = false
    var futureMultiCurrencySupport: String? = nil

    func checkout(items: [Item], customer: Customer, mode: String) -> String {
        var subtotal = 0.0
        for i in items { subtotal += i.price * Double(i.qty) }

        var discount = 0.0
        if customer.tier == "gold" { discount = subtotal * 0.10 }
        else if customer.tier == "silver" { discount = subtotal * 0.05 }
        else if customer.tier == "platinum" { discount = subtotal * 0.15 }

        var shipping = 0.0
        if subtotal - discount > 999 { shipping = 0 } else { shipping = 60 }
        if customer.address.city.pincode.hasPrefix("7") { shipping += 40 }

        var tax = 0.0
        for i in items {
            if i.category == "book" { tax += i.price * Double(i.qty) * 0.0 }
            else if i.category == "food" { tax += i.price * Double(i.qty) * 0.05 }
            else { tax += i.price * Double(i.qty) * 0.18 }
        }

        let total = subtotal - discount + shipping + tax

        if mode == "summary" {
            return "\(customer.name) from \(customer.address.city.name) pays \(total)"
        } else if mode == "detailed" {
            return "sub=\(subtotal) disc=\(discount) ship=\(shipping) tax=\(tax) total=\(total)"
        } else if mode == "json" {
            return "{\"total\":\(total)}"
        }
        return ""
    }
}
```

Findings to look for (don't peek until you've listed your own): `Double` for money · three growing if-chains · tier rule and tax rule duplicated in shape · Demeter chain into `City` · stringly-typed `mode` and `tier` · dead speculative flags (YAGNI) · singleton with mutable global config · anemic `Item`/`Customer` with all logic outside · no error handling for empty items · pincode rule buried in shipping · output formatting mixed with calculation · untestable (no injection) · `subtotal` loop where `reduce` exists · SRP: pricing + tax + shipping + formatting in one method · OCP: every new tier/category/mode edits this file.

## Part B — Rewrite (90 min)

Rules for the rewrite — this is where the module is really graded:

1. Fix every violation you listed.
2. **Do not** add an abstraction you can't name a second implementation for. Every protocol must earn its place; write a one-line justification beside each.
3. Money must not be `Double`.
4. `tier`, `category` and `mode` must not be `String`.
5. Adding a new customer tier, a new tax category, and a new output format must each be **one new file, zero edits**.
6. The engine must be constructible with test doubles and have no global state.
7. Keep the total calculation identical — write a characterisation test against the old code first so you can prove behaviour is preserved. (This is how real refactoring is done.)

## Rubric (/45)

| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Audit completeness | <6 findings | 6–12 | 15+, each named with a principle |
| DRY applied to *knowledge*, not shape | merged unrelated code | partial | right rules unified, coincidental duplication left alone |
| KISS/YAGNI discipline | 12 protocols for 1 use case | some excess | every abstraction justified in one line |
| Demeter | chains remain | partial | boundaries respected without bloat |
| Tell-Don't-Ask / Information Expert | anemic structs remain | partial | behaviour sits with data |
| Encapsulate what varies | if-chains remain | one extracted | tier, tax, format all isolated |
| Types over strings | stringly typed | partial | enums/value types throughout |
| Characterisation test written first | none | after | before, and it passes on both versions |
| Extensibility proof | edits needed | 1 edit | 3 new files, 0 edits |

**36+/45** → Module 04.

## Extension questions
1. Which of your new protocols would you delete if the product had exactly one tier forever? Why is that a *good* question to ask of every abstraction?
2. You unified tax and discount behind one `PricingRule` protocol. Argue why that might be wrong (hint: who owns each rule?).
3. Where does rounding belong, and what breaks if two components round independently?
4. The pincode shipping surcharge: domain rule or configuration? How does the answer change the design?

Ask me to review your rewrite against this rubric.
