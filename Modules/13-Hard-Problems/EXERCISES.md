# Module 13 — Solo Problems

Four hard designs in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M13`. Time-box each to 75 minutes.

### SOLO 1 — Retrying Job Queue
Priority polling, exponential backoff, dead-letter queue, injected clock.
- An attempt starts when a worker **polls**, so `attempts` increments there.
- Backoff after the k-th failure is `baseDelay * 2^(attempts-1)` from *now*.
- A job that has used its final attempt goes to the DLQ and is never polled again.
- `fail`/`complete` on a job that isn't in flight must throw.
*Design point:* the in-flight set is what stops two workers running the same job. In a distributed version it becomes a lease with an expiry — see the design-only section 7 in the README.

### SOLO 2 — Topic Broker
Pub/sub with per-group offsets.
- `poll` does **not** advance the offset; `commit` does. That separation is why at-least-once delivery works.
- Two groups on one topic each see every message.
- Rewinding (committing an older offset) and committing beyond the last message both throw.
*Design point:* lag = messages − committed offset, the single most useful operational metric in any queue.

### SOLO 3 — Consistent Hash Ring
Virtual nodes, clockwise lookup, minimal movement on membership change.
- Virtual node keys are `"<node>#<i>"` — the grader's injected hash depends on that exact format.
- A key hashing past every position wraps to the lowest.
- Adding one node must move only the keys in its arc, not reshuffle everything.
*Design point:* virtual nodes exist to smooth distribution. With one replica per node, a three-node ring can easily give one node 70% of the keys.

### SOLO 4 — Elevator LOOK Scheduler
The scheduling algorithm behind SOLVED 1.
- `.up` from floor f: all stops ≥ f ascending, then all stops < f descending. Mirror for `.down`.
- `distance` sums the travel along that order.
- `bestCar` inserts the request into each car's stop set and measures travel until the request floor is reached.
*Design point:* this is why a car heading up past your floor is a *better* choice than an idle car two floors below — the cost model has to account for direction, not just distance.

## Stretch (not graded)
1. Give the job queue a visibility timeout: an in-flight job whose worker dies returns to ready automatically. What did you just build? (SQS.)
2. Add partitions to the broker so one group can be consumed by several workers in parallel. What ordering guarantee survives?
3. Measure your hash ring's distribution with 1,000 keys at 1, 10 and 100 virtual nodes. Plot it mentally — how many replicas do you actually need?
4. Extend `bestCar` to account for the time doors stay open and the number of stops already queued. Does the ranking change?
