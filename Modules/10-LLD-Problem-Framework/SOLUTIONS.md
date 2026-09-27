# Module 10 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — Noun triage

| Noun | Verdict | Reasoning |
|---|---|---|
| parkingLot, floor, parkingSpot, vehicle, ticket | **entity** | each has identity and a lifecycle; two spots with the same attributes are still different spots |
| admin | **actor** | outside the model; shows up in use cases and permissions, not as a domain object |
| duration | **attribute** | derived from entry and exit timestamps. Storing it creates a second source of truth (DRY, Module 03 §1) |
| pricing | **strategy** | a *rule*, not data. It's the stated variation axis, so it belongs behind a protocol |
| system | **not modelled** | "the system" is the program |
| licensePlate, money | **value object** | compared by contents, no identity, and both want validation in a failable init |

The two that separate candidates: treating `duration` as a stored field (it isn't — it's a computation), and treating `pricing` as a number on the lot (it isn't — it's behaviour).

## E2 — Implied entities

| Fragment | Implied entity | Why it must exist |
|---|---|---|
| member borrows a copy for 14 days | **Loan** | the relationship has its own data (who, what, when, due) and lifecycle |
| partner is given an order | **Assignment** | partners and orders both pre-exist; the *pairing over time* is a thing |
| pays, may fail, may be retried | **Payment** | status, method, attempts, idempotency key. A `Bool` cannot hold that |
| seats held for 5 minutes | **Reservation** | it has a TTL — something must own the expiry |
| cart becomes an order, prices later change | **OrderLine with a price snapshot** | history must not be rewritten by a menu edit |
| user scores the restaurant | **Rating** | one per order, not per user — the entity is what makes that constraint expressible |
| card inserted … card ejected | **Session** | the bracket around a sequence of operations with its own state |
| every price change traceable | **AuditEntry** | append-only, immutable, distinct from the thing it describes |

**Pattern:** implied entities appear wherever a *relationship has its own data or lifetime*, or wherever a *fact must be frozen in time*. In an interview, scan the requirements for both.

## E3 — The machine

### Ordering of the guards
```swift
guard let drink = drinks[code] else { throw .unknownDrink }
guard stockCount(of: code) > 0 else { throw .soldOut }
guard paid >= drink.price else { throw .insufficientFunds(needed: drink.price - paid) }
guard let change = Self.makeChange(...) else { throw .cannotMakeChange }
```
Cheapest and most-informative check first. Reorder it and you tell a customer "insufficient funds" for a drink that is sold out — technically true, practically useless. **Ordering guards is a product decision**, which is why it's the question you should ask in a real round.

`insufficientFunds(needed:)` carries the shortfall rather than a bare flag: the machine knows the number, so the caller shouldn't recompute it (Tell-Don't-Ask, Module 03 §5).

### Atomicity — the part most candidates miss
```swift
var provisional = bank
for coin in inserted { provisional[coin, default: 0] += 1 }
guard let change = Self.makeChange(amount: paid - drink.price, from: provisional) else {
    throw MachineError.cannotMakeChange
}
for coin in change { provisional[coin, default: 0] -= 1 }
bank = provisional            // commit only after every rule passes
stock[code] = stockCount(of: code) - 1
inserted.removeAll()
```
The obvious implementation absorbs the inserted coins into `bank` first, then discovers it can't make change, and now the customer's money is gone. Computing on a **copy** and committing at the end is validate-then-mutate (Module 01 E2) applied to a multi-field update — a poor man's transaction, and exactly what the failing test checks.

This is the shape you want whenever a single operation touches several pieces of state.

### Change-making
```swift
for coin in Coin.allCases.sorted(by: >) {
    var count = available[coin] ?? 0
    while count > 0, coin.rawValue <= remaining { result.append(coin); remaining -= coin.rawValue; count -= 1 }
}
return remaining == 0 ? result : nil
```
Greedy, bounded by what's actually in the bank, returning `nil` rather than a wrong answer. For {1, 2, 5, 10} greedy is optimal; for arbitrary denominations it isn't, and for a limited bank it can fail where a DP solution would succeed. Say so out loud — recognising that greedy is a *chosen* tradeoff, not a universal truth, is the senior signal. (For real coin systems greedy is correct and O(denominations); DP is unjustified complexity.)

### Where the framework showed up
- **D** — the paragraph handed you the scope boundary; notice the effort that went into "money stays inserted on failure", which is a requirement you would otherwise have invented wrongly.
- **E** — entities: `Drink` (value), `Coin` (value), `DrinkMachine` (entity). No `MachineManager`.
- **S** — the machine owns three pieces of state and one invariant: *bank + stock + inserted are consistent after every operation*.
- **I** — the public API reads exactly like the use-case list: insert, select, refund, restock, loadCoins, collectCash.
- **G** — variation axis (pricing, deliberately *not* abstracted here, per YAGNI); edge cases: empty bank, exact money, sold out, unknown code, failure atomicity.
- **N** — values first, then the machine, then the failure ordering.

### What you'd add with more time (say this in an interview)
Thread safety (two coin slots — `select` is a check-then-act), a `PricingStrategy`, a maintenance state, sales reporting on the machine (Information Expert), and a persisted event log so the bank survives a power cut.

## Self-check
| If you… | Re-read |
|---|---|
| stored `duration` | §E1, DRY |
| missed `Loan`/`Reservation`/`Payment` | §4 implied entities |
| mutated `bank` before validating change | §8 and Module 01 E2 |
| returned a partial change list | §E3 change-making |
| ordered the guards differently without noticing | §E3 ordering |
