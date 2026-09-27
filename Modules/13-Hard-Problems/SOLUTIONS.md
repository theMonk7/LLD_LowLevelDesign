# Module 13 — Solo Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).
Solved-problem code: [`Solutions/Solved.swift`](Solutions/Solved.swift).

## SOLO 1 — Retrying Job Queue
```swift
records[chosen.job.id]?.status = .inFlight
records[chosen.job.id]?.attempts += 1        // an attempt begins when a worker takes it

public func fail(_ jobID: String) throws {
    guard var record = records[jobID], record.status == .inFlight else { throw QueueError.notInFlight }
    if record.attempts < record.job.maxAttempts {
        record.status = .ready
        record.dueAt = now() + baseDelay * pow(2, Double(record.attempts - 1))
    } else {
        record.status = .dead
    }
}
```
**Where `attempts` increments is a design decision, not a detail.** Incrementing on `poll` means a worker that crashes without calling `fail` has still consumed an attempt — which is what you want, otherwise a job that reliably kills its worker retries forever. Incrementing on `fail` would be more "accurate" and less safe.

**Three states, one enum.** `ready` / `inFlight` / `dead` makes "two workers get the same job" unrepresentable, which is the queue's core invariant. The `dueAt` field turns backoff into a filter rather than a timer — no scheduling machinery needed, and tests advance a fake clock instead of sleeping.

**Backoff formula:** `base * 2^(attempts-1)` gives 10, 20, 40 for base 10 — doubling from the base rather than from zero. Worth stating explicitly, because "exponential backoff" is ambiguous about the first delay. Production systems add **jitter** (a random ±20%) so a thousand jobs failing at once don't all retry at the same instant — a stampede you can cause by being too precise.

**DLQ, not infinite retry.** A poison job that fails forever consumes a worker slot forever. The dead-letter queue is how the system stays alive while an operator investigates.

This is exactly SQS/Sidekiq/Celery in miniature; in a distributed version, `inFlight` becomes a **lease with an expiry** so a dead worker's job returns automatically (the stretch exercise).

## SOLO 2 — Topic Broker
```swift
public func poll(topic: String, group: String, max: Int) throws -> [Message] {
    let start = offsets[key(topic, group)] ?? 0
    ...                                        // does NOT advance the offset
}
public func commit(topic: String, group: String, offset: Int) throws {
    guard offset >= 0, offset < messages.count, offset + 1 > current else { throw .invalidCommit }
    offsets[key(topic, group)] = offset + 1
}
```
**Separating poll from commit is the entire design.** If polling advanced the offset, a consumer that crashed mid-processing would lose messages — at-most-once delivery. By committing only after successful processing you get **at-least-once**, which is why consumers must be idempotent (Module 09 §6). That trade is the thing to say out loud.

**Offsets are per (topic, group), not per consumer.** That single choice gives you both behaviours people expect: consumers in one group share progress (work splitting), while different groups each see the whole stream (fan-out). One dictionary key, two features.

**Commit validation** rejects rewinds and futures. A rewind would replay messages (sometimes wanted — but then it's an explicit `seek`, not a `commit`), and committing beyond the end would silently skip messages that don't exist yet.

`lag` is `count − committedOffset`: the number you'd alert on in production, and the first thing anyone asks about a queue.

Deliberately absent: partitions, retention, replication, acks — all HLD. Naming them as out of scope is the right move.

## SOLO 3 — Consistent Hash Ring
```swift
public func addNode(_ node: String) {
    for i in 0..<virtualNodes { ring.append((position: hash("\(node)#\(i)"), node: node)) }
    ring.sort { $0.position < $1.position }
}
public func node(for key: String) -> String? {
    guard !ring.isEmpty else { return nil }
    let h = hash(key)
    return (ring.first { $0.position >= h } ?? ring[0]).node
}
```
**Why consistent hashing exists:** with `hash(key) % n`, changing `n` from 3 to 4 moves ~75% of keys. On the ring, adding a node steals only the arc between it and its predecessor — about `1/n` of keys. The grader measures this: adding a node moves at most one of five keys.

**Why virtual nodes:** one position per node gives wildly uneven arcs. Replicas even out the distribution — 100–200 per node is typical in real systems. That's why `ringSize` is `nodes × virtualNodes` and why the constructor takes it as a parameter rather than hardcoding 1.

**`?? ring[0]` is the wrap-around**, and it's the line people forget: a key hashing past the highest position belongs to the first node clockwise, which is the lowest position. Forget it and every key above your largest virtual node crashes or misroutes.

The linear `first { $0.position >= h }` is O(n); since `ring` is sorted, a binary search makes it O(log n). Say it; with 100 nodes × 150 replicas that's 15,000 entries and it matters.

**Injected hash** again — deterministic tests, and it also lets you swap in a better distribution function (MD5/SHA of the key is common) without touching the ring.

## SOLO 4 — LOOK Scheduler
```swift
case .up:
    let ahead = stops.filter { $0 >= currentFloor }.sorted()
    let behind = stops.filter { $0 < currentFloor }.sorted(by: >)
    return ahead + behind
```
Six lines for the algorithm that makes elevators feel sane. LOOK = "continue in the current direction until nothing is left that way, then reverse" — unlike SCAN, it doesn't travel to the end of the shaft first.

`>= currentFloor` (inclusive) means a stop at the current floor is served immediately rather than after a full round trip — the `test_currentFloorIsServedFirst` case, and a real bug in naive implementations.

```swift
let plan = order(currentFloor: car.floor, direction: car.direction, stops: car.stops.union([requestFloor]))
guard let stopIndex = plan.firstIndex(of: requestFloor) else { return .max }
return travel(from: car.floor, along: Array(plan.prefix(stopIndex + 1)))
```
`bestCar` measures **travel until the request is served**, not straight-line distance. That's why a car at floor 8 heading down beats a car at floor 4 heading up for a request at floor 3, even though the second car is closer: the first passes floor 3 on its way, the second must finish its upward run first. Encoding "direction matters more than distance" into the cost function is the insight the whole problem is testing.

`travel` walking the plan and summing `abs` differences keeps the cost model honest and reusable for both `distance` and `bestCar` — one definition of cost, used everywhere.

## Self-check
| If you… | Re-read |
|---|---|
| incremented attempts in `fail` instead of `poll` | SOLO 1 |
| let `poll` advance the consumer offset | SOLO 2 |
| forgot the ring wrap-around | SOLO 3 |
| used one virtual node per physical node | SOLO 3 |
| ranked cars by straight-line distance | SOLO 4 |
| excluded the current floor from the "ahead" set | SOLO 4 |
