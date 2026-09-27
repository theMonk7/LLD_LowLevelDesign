# Module 14 — Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).

## E1 — Mapping
```swift
let id = user_id.trimmingCharacters(in: .whitespaces)
guard !id.isEmpty else { throw MappingError.emptyID }
guard let raw = full_name?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
    throw MappingError.missingName
}
guard let date = ISO8601DateFormatter().date(from: created_at) else { throw MappingError.badDate }
```
The mapper is an **Adapter** (Module 06 §1) sitting on the data boundary, and it earns its keep three ways:
- **Optionality stops here.** `full_name: String?` becomes `name: String`. Without the mapper, every screen deals with the server's nulls forever.
- **Naming stops here.** `user_id` is the backend's vocabulary; `id` is yours. A backend rename touches one file.
- **Failure becomes typed and local.** "The server sent a date we can't parse" is a `badDate`, not a crash in a view model three layers up.

`mapAll` returning `(users, failedIDs)` rather than throwing is the right choice for a list endpoint: one malformed row shouldn't blank the screen. That's a product decision — worth saying out loud, since the alternative (fail the whole page) is right for a payments list.

## E2 — Networking
```swift
catch let error as TransportError { throw APIError.transport(error) }
guard (200..<300).contains(response.status) else { throw APIError.http(status: response.status) }
guard let value = decode(response.body) else { throw APIError.decoding }
```
**Three error kinds, because callers do three different things.** Transport failure → retry or show "you're offline". HTTP 401 → refresh the token; 404 → empty state. Decoding failure → a bug, log it and alert engineering. Collapse them into one `networkError` and the UI can't behave correctly.

```swift
public final class RetryingTransport: HTTPTransport { ... }
public final class LoggingTransport: HTTPTransport { ... }
let transport = RetryingTransport(base: LoggingTransport(base: real), maxAttempts: 3)
```
Both conform to the same protocol as the thing they wrap, so `APIClient` never learns they exist — textbook Decorator. Retry catches **only** `TransportError`: retrying a 400 just sends a bad request four times.

`log.append(...)` happens **before** the call, so a failed attempt is logged. Logging after the call loses exactly the entries you need at 3 a.m.

`Endpoint` is a value with a `url(base:)` method rather than a function that fires a request. Values can be compared, logged, stored in a retry queue and built in tests — a request that is a side effect can't.

## E3 — Image loader ⭐
```swift
if let hit = memory[url] { memoryHits += 1; return hit }
if let existing = inFlight[url] { return try await existing.value }

let task = Task<String, Error> { try await remote.fetch(url) }
inFlight[url] = task                     // publish BEFORE suspending
let value = try await task.value
```
The ordering is the whole exercise. `inFlight[url] = task` executes **before** any `await`, so it is atomic with respect to the actor: every later caller sees the task and awaits it. Move the assignment after the `await` and all 50 callers miss the check and fire 50 requests — a real bug that ships regularly, because it is invisible in a sequential test.

This is the table-view scroll case: 60 cells asking for the same avatar. One request, 60 awaiters.

**Failures are not cached** and the in-flight entry is cleared in the `catch`. Cache a failure and a transient 500 blanks that avatar for the rest of the session; leave the in-flight entry behind and the URL is permanently poisoned — every future caller awaits a task that already failed.

What a production version adds: a disk layer between memory and network, a cost-based eviction limit, decoding off the main thread, cancellation, and a check that the cell's URL still matches before assigning the image.

## E4 — Container
```swift
if entry.scope == .singleton, let cached = singletons[key] as? T { return cached }
guard let made = entry.make() as? T else { return nil }
if entry.scope == .singleton { singletons[key] = made }
```
Type-keyed registration with two lifetimes. `register` clearing `singletons[key]` matters: re-registering must not keep handing out the instance built by the old factory — the kind of thing that only bites in tests, where re-registration is common.

**Say the caveat.** This is a **Service Locator**. Used at the composition root to build graphs, it's a convenience. Injected into domain types so they call `container.resolve(...)` themselves, it undoes DIP: dependencies become invisible, the compiler stops checking them, and a missing registration becomes a runtime `nil` instead of a compile error. The rule: *containers build objects; objects receive dependencies through `init`.*

## E5 — ViewModel
```swift
public enum ProfileState: Equatable { case idle, loading, loaded(ProfileUI), failed(String) }

public func load(id: String) async {
    transition(to: .loading)
    do { transition(to: .loaded(ProfileUI(title: user.name, subtitle: ...))) }
    catch { transition(to: .failed(String(describing: error))) }
}
```
One `state` enum instead of `isLoading` / `data` / `errorMessage`. With three independent properties you can represent "loading AND has an error AND has data" — and eventually you'll ship it. The enum makes that unrepresentable (Module 12, `CopyState`).

The view model exposes **`ProfileUI`, not `User14`**: presentation formatting belongs here, so the view stays a dumb renderer and the formatting is unit-testable. That separation is what people mean by "a real ViewModel".

`retry` delegating to `load` guarantees the `.loading` state is re-entered — the test asserts the full history because "retry silently swaps the error for content" is a jarring bug.

It's an `actor` here so the tests can run it without a main-thread runtime. In an app it would be `@MainActor final class ProfileViewModel: ObservableObject` with `@Published private(set) var state` — same design, different isolation annotation, and the tests barely change.

## Self-check
| If you… | Re-read |
|---|---|
| let the server's optionality into the domain type | E1 |
| collapsed transport/HTTP/decoding into one error | E2 |
| logged after the call instead of before | E2 |
| stored the in-flight task after the first `await` | E3 ⭐ |
| cached a failed fetch | E3 |
| let domain types call `container.resolve` | E4 |
| used three booleans instead of one state enum | E5 |
