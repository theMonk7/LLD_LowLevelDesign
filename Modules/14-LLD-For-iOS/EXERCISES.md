# Module 14 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M14`.
No UIKit anywhere — that's the point. Everything here is the part of an app that must be testable without a simulator.

### E1 — DTO → Domain mapping
Validation order is fixed: empty id → missing name → bad date. `mapAll` partitions successes from failures instead of throwing on the first bad row.
*Design point:* the mapper is where wire-format optionality stops. After it, `User14.name` is a non-optional `String` and no screen ever writes `user.name ?? ""`.

### E2 — Networking layer
Typed `Endpoint`, an `HTTPTransport` seam, and a **three-way error taxonomy**: transport vs HTTP status vs decoding. Then two decorators — retry (transport failures only) and logging (before the call, so failures are logged).
*Design point:* the composition test asserts that logging *inside* retry records every attempt. Swap the order and you log once. Decorator order is semantics (Module 06 §4).

### E3 — Image loader ⭐
Memory cache, request coalescing, no caching of failures.
*Design point:* 50 concurrent requests for one URL must produce **one** fetch. The in-flight `Task` must be stored *before* the first `await`, or every caller misses the check — that's the actor-reentrancy trap from Module 09 E6, in the exact form it appears in a real iOS app.

### E4 — Dependency container
Register/resolve with `.transient` and `.singleton` scopes, keyed by type.
*Design point:* this is a service locator, and it's fine as a composition-root utility. It becomes an anti-pattern when domain types call `resolve` themselves — then dependencies are invisible again. Be ready to say exactly that.

### E5 — ViewModel as a state machine
Four states, a recorded history, an injected use case, and `retry` that goes back through `.loading`.
*Design point:* `stateHistory` is a test affordance that also documents the design: a screen that can show a spinner, content, and an error is a state machine, and modelling it as one kills the "spinner still visible behind the error" class of bug.

## Stretch (not graded)
1. Add a disk layer to E3 between memory and network. Where does it go, and what does it do to the coalescing logic?
2. Add cancellation to E3: a caller that goes away should not keep the fetch alive if it's the only one waiting. What do you need to track?
3. Give E2 an `AuthenticatingTransport` that refreshes an expired token — and make sure 10 concurrent 401s trigger **one** refresh. (Same coalescing idea.)
4. Convert E5 to `@MainActor final class ... ObservableObject` with `@Published`. Which test changes, and which doesn't?
5. Write the composition root that wires E1–E5 together into a working "load profile" feature.
