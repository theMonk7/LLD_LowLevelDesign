# Module 07 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — Strategy
```swift
public func fee(hours: Int) -> Decimal { Decimal(max(0, hours - freeHours)) * rate }
```
Each strategy is a few lines because it owns exactly one rule. `ParkingLot7` holds `any PricingStrategy` as a `var` so it can change at runtime — that mutability is the difference between Strategy (client swaps it) and Bridge (fixed at construction).

The grader's `WeekendFree` strategy, defined inside the test, proves OCP: the lot accepts an algorithm that didn't exist when the lot was written.

In production Swift this would often be `let fee: (Int) -> Decimal`. Keep the protocol when you need `name` for receipts and audit — which is exactly why `name` is in the exercise. A closure can't be printed, persisted, or compared.

## E2 — State
```swift
public func select(_ item: String, _ m: VendingMachine) -> String {
    guard m.stock > 0 else { m.transition(to: SoldOutState()); return "sold out - refunded" }
    m.setPendingItem(item)
    m.transition(to: DispensingState())
    return "dispensing \(item)"
}
```
**Zero switch statements anywhere.** Each state answers all three events for itself, so "what happens if you press select while dispensing?" has exactly one place to look.

Three design decisions worth defending:
- **States are `struct`s, transitions create new ones.** They're stateless behaviour holders; all data lives on the machine. If a state needed its own data (a timeout deadline), it would become a class or carry associated values.
- **The machine owns the data, the state owns the rules.** `pendingItem` lives on `VendingMachine` because it must survive a transition. Put it on the state and it vanishes on the next transition — a classic bug.
- **`DispensingState.dispense` decides the *next* state** by checking stock after decrementing. Transition logic belongs to the state you're leaving, not to the machine.

The `enum` alternative — `enum State { case idle, hasMoney, dispensing(String), soldOut }` with one `transition(on:)` — is genuinely better for four states with short logic, and the compiler gives you exhaustiveness. Use the pattern when per-state behaviour is rich, when states need their own dependencies, or when third parties must add states. Say which and why; that's the whole question.

## E3 — Observer
```swift
public func update(symbol: String, price: Decimal) {
    purge()
    let snapshot = boxes.values.compactMap(\.value)     // iterate a COPY
    snapshot.forEach { $0.priceChanged(symbol: symbol, price: price) }
}
```
Four separate hazards, four mitigations:

1. **Retain cycles.** `WeakBox` holds observers weakly, so the ticker never keeps a view controller alive. The test that allocates an observer in a `do` block and checks `liveObserverCount == 0` afterwards is the memory-leak test.
2. **Mutation during iteration.** `SelfRemoving` unsubscribes *while being notified*. Iterating `boxes` directly would mutate the collection mid-loop; iterating a snapshot makes it safe, and every observer alive at notification time gets exactly one call.
3. **Duplicate subscription.** Keying by `ObjectIdentifier` makes `subscribe` idempotent — subscribing twice notifies once. With an array you'd get two calls, which is how duplicate analytics events happen.
4. **Zombie entries.** `purge()` drops boxes whose value is gone, so the dictionary doesn't grow forever in a long-lived app.

In production you'd use `Combine`, `AsyncStream` or a delegate. Being able to hand-roll this — with all four hazards handled — is what the interview is testing.

## E4 — Command + Memento
```swift
public func run(_ c: any Command) {
    c.execute()
    undoStack.append(c)
    redoStack.removeAll()        // a new action invalidates redo
}
```
That last line is the detail. Without it: type "abc", undo, type "xyz", press redo, and "abc" reappears on top of "xyz". Every undo system that feels broken is missing it.

The two commands show the two undo strategies side by side:
- `AppendCommand` stores the **inverse operation** — cheap (one string), but only possible because appending has an obvious inverse.
- `UppercaseCommand` stores a **snapshot** — a Memento — because `uppercased()` isn't reversible: you cannot recover "Hello World" from "HELLO WORLD".

Real editors use both: commands for keystrokes, snapshots every N operations so undo doesn't have to replay from the beginning.

`UppercaseCommand` is a `class` because it mutates `snapshot` during `execute()`; `AppendCommand` is a `struct` because it's immutable. The choice falls straight out of Module 01 §2.

## E5 — Chain of Responsibility
```swift
public extension Approver {
    func handle(_ amount: Decimal) -> String {
        if amount <= limit { return "\(title) approved \(amount)" }
        if let next { return next.approve(amount: amount) }
        return "rejected: \(amount)"
    }
}
```
Putting the routing in a protocol extension means each approver is three one-line members. Adding `VP` is a new type and one line in `buildChain` — no existing handler changes.

The terminal case is explicit: an unhandled request returns "rejected" rather than vanishing. A chain that silently drops requests is the classic bug; decide between a default handler, an error, and a sentinel, and say which you chose.

`buildChain` uses `zip(approvers, approvers.dropFirst())` to link neighbours — a neat Swift idiom for pairwise iteration. It returns an Optional because an empty chain has no head, which forces callers to handle "no approvers configured".

## E6 — Template Method
```swift
func run(_ path: String) -> String { save(validate(parse(read(path)))) }
```
Four steps, fixed order, defined once. `parse` is in the protocol body (required, dynamically dispatched, so `RawImporter`'s override wins); `validate` has a default in the extension *and* is declared in the protocol, which is what lets `RawImporter` override it — the Module 01 §7 dispatch rule showing up as a functional requirement.

`read` and `save` live only in the extension, so they're static — deliberately not overridable here.

Swift can't mark an extension method `final`, so "the skeleton must not be overridden" is a convention. In a class-based version you'd write `final func run(...)` and have the compiler enforce it. Mention the gap; it's real.

## E7 — Iterator
```swift
var stack = [root]
return AnyIterator {
    guard let node = stack.popLast() else { return nil }
    stack.append(contentsOf: node.children.reversed())   // reversed → left-to-right
    return node.value
}
```
Stack + `reversed()` gives preorder; queue + `removeFirst()` gives level order. The captured mutable state inside the closure is the iterator's state — `AnyIterator` makes this a four-line pattern in Swift.

`reversed()` is easy to omit and gives [1,3,6,2,5,4] instead of [1,2,4,5,3,6]. Worth understanding rather than memorising.

The real payoff is the last test: conforming to `Sequence` gives you `filter`, `reduce`, `prefix`, `map`, `lazy` and everything else for free. **In Swift, "implement Iterator" means "conform to `Sequence`".** Writing a bespoke `next()`-style protocol would be a red flag.

## E8 — Mediator
```swift
public func send(_ message: String, from sender: ChatUser) {
    users.filter { $0 !== sender }.forEach { $0.receive(message, from: sender.name) }
}
```
`ChatUser` holds a `weak` reference to the room and none to other users. Ten users = ten edges, not forty-five. Adding a rule like "muted users receive nothing" changes one place.

`room?.send(...)` means an unregistered user sending is a no-op rather than a crash — a small Null-Object-ish touch, and the reason the "lonely user" test passes.

The risk to name out loud: `ChatRoom` is one refactor away from owning moderation, rate limiting, delivery receipts and presence — i.e. becoming a God Object. Mediators coordinate; they shouldn't accumulate business rules. `UIViewController` is the cautionary tale.

## E9 — Null Object
```swift
public init(analytics: any Analytics7 = NoOpAnalytics()) { self.analytics = analytics }
```
No `if let analytics` at any call site, and tests get a real spy by passing one. The caveat: use it only where absence is genuinely harmless. A `NoOpPaymentProcessor` that silently "succeeds" would be a catastrophe — absence there is meaningful and must be an error.

## E10 — Identification
| Scenario | Pattern |
|---|---|
| fee hourly or flat | Strategy |
| behaves differently when idle/dispensing | State |
| notify every dashboard | Observer |
| undo/redo | Command |
| TeamLead → Manager → Director | Chain of Responsibility |
| five fixed steps, step three differs | Template Method |
| traverse depth-first and breadth-first | Iterator |
| ten controls affecting each other | Mediator |
| snapshot to restore later | Memento |
| new export formats over fixed node types | Visitor |
| optional logger | Null Object |

## Self-check
| If you… | Re-read |
|---|---|
| wrote a `switch` in `VendingMachine` | §2 |
| stored `pendingItem` on a state | §2 |
| held observers strongly, or iterated the live collection | §3 |
| forgot `redoStack.removeAll()` | §4 |
| let an unhandled request vanish | §5 |
| put `validate` only in the extension | §6 + Module 01 §7 |
| wrote a custom iterator protocol instead of `Sequence` | §7 |
| gave `ChatUser` references to other users | §8 |
