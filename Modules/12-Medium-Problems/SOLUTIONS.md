# Module 12 — Solo Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).
Solved-problem code: [`Solutions/Solved.swift`](Solutions/Solved.swift).

## SOLO 1 — LFU Cache
```swift
private struct Entry { var value: Value; var frequency: Int; var lastUsedTick: Int }

private func evictOne() {
    guard let victim = entries.min(by: { a, b in
        a.value.frequency != b.value.frequency
            ? a.value.frequency < b.value.frequency
            : a.value.lastUsedTick < b.value.lastUsedTick
    })?.key else { return }
    ...
}
```
LFU needs **two** orderings, which is what makes it harder than LRU. A monotonic `tick` gives a total order on recency without timestamps — no clock, no collisions, no injection needed.

Every mutation (`get`, `put` on existing, `put` of new) increments both `frequency` and `lastUsedTick`, so the two orderings stay consistent. The classic bug is forgetting that `get` is a use: the cache then evicts by insertion count and behaves like a broken FIFO.

**Complexity, honestly:** eviction is O(n) because of the `min`. The O(1) design keeps a dictionary from frequency → doubly-linked list of keys at that frequency, plus a `minFrequency` pointer; eviction pops the tail of the `minFrequency` list. Write the simple version in an interview, state the complexity, and offer the O(1) structure as the follow-up. Attempting the O(1) version cold usually produces a bug.

## SOLO 2 — Coupon Engine
```swift
public func discount(for order: Order12) -> Decimal? {
    guard order.subtotal >= minSubtotal else { return nil }
    return min(order.subtotal * percent / 100, maxDiscount)
}
```
`Decimal?` carries two distinct meanings: `nil` = "doesn't apply", `0` = "applies but saves nothing". Collapse them into a plain `Decimal` and you can't tell a non-applicable coupon from a worthless one — which matters the moment the UI wants to say *why* a coupon didn't apply.

```swift
coupons
    .compactMap { c in c.discount(for: order).map { (code: c.code, discount: $0) } }
    .min { a, b in a.discount != b.discount ? a.discount > b.discount : a.code < b.code }
```
The engine contains **no knowledge of any coupon type** — no switch, no casts — which is why the grader's `AlwaysHalf` works untouched. That's OCP with a real test behind it.

Each rule lives in its own type: `min(amount, subtotal)` in `FlatCoupon` guarantees a flat coupon can't make the total negative, rather than the engine clamping afterwards. Invariants belong to the type that owns them.

## SOLO 3 — File System
```swift
private final class Node {
    var children: [String: Node]?     // non-nil => directory
    var contents: String?             // non-nil => file
}
private static func size(of node: Node) -> Int {
    if let children = node.children { return children.values.reduce(0) { $0 + size(of: $1) } }
    return node.contents?.utf8.count ?? 0
}
```
This is **Composite** (Module 06 §3): the same type is leaf or container, and `size` recurses without caring which. The alternative — an enum with `.file(String)` and `.directory([String: Node])` — is arguably more Swift-like and makes the two cases exclusive by construction. Both are good answers; the enum is stronger on correctness, the class is easier to mutate in place. Say which you chose and why.

Four distinct errors is not pedantry. `readFile("/a")` where `/a` is a directory is `notAFile`; `ls("/a/two.txt")` is `notADirectory`; a missing path is `notFound`. Returning `nil` for all three gives the caller no way to produce a useful message.

`writeFile` deliberately does **not** create parent directories, while `mkdir` does (`mkdir -p` semantics). Two functions, two policies, both stated in the doc comment — exactly the kind of thing to clarify in an interview rather than assume.

## SOLO 4 — Job Scheduler
```swift
let ready = remaining.map { byName[$0]! }.filter { $0.dependsOn.allSatisfy(done.contains) }
guard let next = ready.min(by: {
    $0.priority != $1.priority ? $0.priority > $1.priority : $0.name < $1.name
}) else { throw SchedulerError.cycleDetected }
```
Kahn's algorithm with a priority-aware selection. The key property: **priority only orders jobs that are already runnable.** A priority-100 job with an unmet dependency isn't in `ready`, so it can't jump the queue — the grader tests exactly this, because it's the mistake people make when they sort by priority first and then try to fix up the order.

Cycle detection falls out for free: if `remaining` is non-empty but `ready` is empty, every remaining job is waiting on another remaining job. No colouring, no DFS stack.

Validation is layered — duplicates, then unknown dependencies, then cycles — so the error you get is the most specific one available. `unknownDependency(String)` carries the name, because "some dependency is missing" is not an actionable error message.

Complexity is O(V²) as written (re-filtering every round). The O(V+E) version maintains in-degrees and a priority queue of ready jobs. For a build graph of 50 jobs, the simple version is correct and readable; say the improvement rather than writing it.

## SOLO 5 — Meeting Rooms
```swift
public func minimumRooms(_ meetings: [Meeting]) -> Int {
    let starts = meetings.map(\.start).sorted()
    let ends = meetings.map(\.end).sorted()
    var i = 0, j = 0, inUse = 0, peak = 0
    while i < starts.count {
        if starts[i] < ends[j] { inUse += 1; peak = max(peak, inUse); i += 1 }
        else { inUse -= 1; j += 1 }
    }
    return peak
}
```
The sweep line: walk the sorted starts and ends together; the peak concurrent count *is* the room count. `starts[i] < ends[j]` (strictly less) is what makes a meeting ending at 10 and another starting at 10 share a room. Change it to `<=` and you silently need an extra room per back-to-back pair.

Pairwise overlap checking gives the wrong answer for three mutually overlapping meetings that overlap in different pairs — the classic wrong solution, and why that test exists.

```swift
if let room = freeAt.indices.first(where: { freeAt[$0] <= meeting.start }) { ... }
```
Assignment reuses the lowest-numbered free room, which is why `m3` lands back in room 1. `freeAt` grows only when no room is free, so it ends at exactly `minimumRooms` — the two functions agree by construction rather than by coincidence.

`RoomCalendar` keeps meetings sorted on insert so `meetings(in:)` is already ordered, and rejects invalid intervals before checking overlaps (cheapest check first).

## Self-check
| If you… | Re-read |
|---|---|
| forgot that `get` counts as an LFU use | SOLO 1 |
| returned `0` instead of `nil` for an inapplicable coupon | SOLO 2 |
| collapsed the four filesystem errors into one | SOLO 3 |
| let priority override a dependency | SOLO 4 |
| used `<=` in the sweep line | SOLO 5 |
| checked overlaps pairwise | SOLO 5 |
