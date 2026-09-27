# Module 14 — LLD for iOS Engineers

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** connect everything so far to the code you actually write. This is the module that makes the rest pay off in *your* interviews, because Apple, Uber, Swiggy, Zomato, PhonePe and Flipkart iOS rounds ask architecture questions, not parking lots.

**The shift:** in Modules 11–13 you designed *systems*. Here you design **app architecture** — layers, boundaries, and the seams that make an app testable.

---

## 1. The architecture families, compared honestly

### MVC (Apple's, not the original)
```
View ←→ ViewController ←→ Model
```
The View Controller owns the view lifecycle, formatting, navigation, and often networking. Apple's MVC is really "Massive View Controller" because `UIViewController` is *both* controller and view.

**Verdict:** fine for genuinely small screens. The failure is gradual: nothing is wrong at 200 lines, everything is wrong at 2,000.

### MVVM
```
View (VC/SwiftUI) → ViewModel → Model/Services
         ↑ bindings ↓
```
The ViewModel holds presentation state and formatting, exposes it as observable values, and knows nothing about UIKit.

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    enum State: Equatable { case idle, loading, loaded(ProfileUI), failed(String) }

    private let loadProfile: any LoadProfileUseCase
    init(loadProfile: any LoadProfileUseCase) { self.loadProfile = loadProfile }

    func onAppear() async {
        state = .loading
        do { state = .loaded(ProfileUI(try await loadProfile.execute())) }
        catch { state = .failed(error.localizedDescription) }
    }
}
```
**The test for a real MVVM:** does the ViewModel file `import UIKit`? If yes, it isn't one. A ViewModel must be testable with no view, no simulator, no network.

**Verdict:** the right default for most apps. Cheap, testable, works with UIKit and SwiftUI.

### MVP
View is passive, Presenter pushes updates through a `View` protocol. Effectively MVVM with explicit method calls instead of bindings. Common in older UIKit codebases and in Android-influenced teams.

### VIPER
```
View → Presenter → Interactor → Entity
          ↓
       Router
```
Five roles per screen, each a protocol. Extremely explicit boundaries; 5–8 files per screen.

**Verdict:** justified on large codebases with many teams and strict module boundaries. On a 12-screen app it is ceremony — and saying that is a better answer than praising it.

### Clean Architecture / layered
```
Presentation (View, ViewModel)
      ↓ depends on
Domain (Entities, UseCases, Repository PROTOCOLS)   ← depends on nothing
      ↑ implemented by
Data (API client, DB, Repository implementations, DTOs)
```
The critical rule: **the domain layer imports nothing** — not UIKit, not Alamofire, not CoreData. Arrows point inward, and the inward-pointing arrow from Data to Domain is DIP (Module 02 §D) at architecture scale.

**Verdict:** the right shape for a large app; adopt it partially (domain protocols + use cases) rather than religiously.

### How to answer "which architecture would you use?"
> *"MVVM with a thin domain layer. The ViewModel holds presentation state and is unit-testable without UIKit; repositories are protocols owned by the domain so the network and cache are swappable. I'd only reach for VIPER if we had many teams needing hard module boundaries — on a small team it's five files per screen for boundaries we could enforce with two."*

Named a choice, gave a reason, named the condition under which you'd choose differently. That's the answer.

---

## 2. Where the patterns actually live in iOS

| Pattern | In the frameworks you use | In your own code |
|---|---|---|
| Singleton | `UIApplication.shared`, `FileManager.default`, `URLSession.shared` | config, caches — injected, with a `.shared` default |
| Factory | `UIStoryboard.instantiateViewController`, cell providers | view-model factories, `Endpoint` builders |
| Builder | `URLComponents`, `@resultBuilder` (`ViewBuilder`) | request builders, test fixtures |
| Prototype | `NSCopying`, value-type copies | template objects |
| Adapter | DTO → domain mappers | wrapping third-party SDKs |
| Decorator | — | caching/logging/retry around repositories |
| Facade | `UIImagePickerController` | `SessionManager` over keychain + refresh + network |
| Proxy | `lazy var`, `@StateObject` | lazy heavy services, permission gates |
| Composite | `UIView` hierarchy, SwiftUI `View` trees | form/section models |
| Observer | `NotificationCenter`, KVO, Combine, `@Published`, `AsyncStream` | domain event bus |
| Delegate (1:1 Observer) | `UITableViewDelegate` | callbacks between coordinators |
| Strategy | `sorted(by:)`, layout objects | pricing, validation, retry policies |
| State | — | upload/download/playback state machines |
| Command | `UIAction`, `UndoManager`, `Operation` | undo, offline mutation queue |
| Template Method | `UIViewController` lifecycle hooks | base request flows |
| Iterator | `Sequence`, `AsyncSequence` | paginated API cursors |
| Coordinator (iOS-specific) | — | navigation |

---

## 3. The Coordinator pattern

**Problem:** view controllers that push other view controllers know about each other, so they can't be reused, reordered, or deep-linked into.

```swift
protocol Coordinator: AnyObject {
    var children: [any Coordinator] { get set }
    func start()
}

final class CheckoutCoordinator: Coordinator {
    var children: [any Coordinator] = []
    private let navigator: any Navigating           // protocol, not UINavigationController
    private let factory: any ScreenFactory

    func start() {
        let vm = factory.makeCartViewModel(onCheckout: { [weak self] cart in
            self?.showPayment(for: cart)
        })
        navigator.push(factory.makeCartScreen(vm))
    }
    private func showPayment(for cart: Cart) { ... }
}
```
The screen emits an *intent* (`onCheckout`); the coordinator decides what happens next. Deep links, A/B-tested flows and reordering become coordinator changes, not screen changes.

**Costs to admit:** child-coordinator lifetime management is fiddly (the classic leak is forgetting to remove a finished child), and SwiftUI's `NavigationStack` with a path enum covers much of it natively. Know both.

---

## 4. Designing a networking layer (a very common prompt)

Requirements you should extract: type-safe endpoints, pluggable auth, retries, caching, cancellation, testability, decoding errors distinguishable from transport errors.

```swift
// 1. Endpoint: a value, not a function call
struct Endpoint<Response: Decodable> {
    let path: String
    let method: HTTPMethod
    let query: [String: String]
    let body: Data?
}

// 2. Transport: the seam that makes everything testable
protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// 3. Client: composes endpoint + transport + decoding
struct APIClient {
    let transport: any HTTPTransport
    let baseURL: URL
    let decoder: JSONDecoder

    func send<R>(_ endpoint: Endpoint<R>) async throws -> R {
        let (data, response) = try await transport.send(endpoint.urlRequest(base: baseURL))
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.http(status: response.statusCode, data: data)
        }
        do { return try decoder.decode(R.self, from: data) }
        catch { throw APIError.decoding(error) }        // distinct from transport failure
    }
}

// 4. Cross-cutting behaviour as decorators, not as flags
struct AuthenticatingTransport: HTTPTransport { let base: any HTTPTransport; let tokenStore: TokenStore }
struct RetryingTransport: HTTPTransport { let base: any HTTPTransport; let policy: RetryPolicy }
struct LoggingTransport: HTTPTransport { let base: any HTTPTransport }

let transport = LoggingTransport(base: RetryingTransport(base: AuthenticatingTransport(base: URLSessionTransport())))
```

The graded points: `Endpoint` is **generic over its response** so `send` returns a typed value; the transport protocol is the test seam; cross-cutting concerns are **decorators** (Module 06 §4) composed at the composition root; and transport, HTTP-status and decoding failures are three different errors, because callers handle them differently.

---

## 5. Designing an image cache (SDWebImage / Kingfisher in an interview)

Requirements: memory cache, disk cache, deduplicate concurrent requests for the same URL, cancellation, eviction, decode off the main thread.

```swift
actor ImageLoader {
    private let memory: LRUCache<URL, ImageData>
    private let disk: any DiskCache
    private let remote: any RemoteImageFetching
    private var inFlight: [URL: Task<ImageData, Error>] = [:]

    func image(for url: URL) async throws -> ImageData {
        if let hit = memory.get(url) { return hit }                 // 1. memory
        if let task = inFlight[url] { return try await task.value } // 2. coalesce duplicates
        let task = Task<ImageData, Error> {
            if let onDisk = try? await disk.read(url) { return onDisk }   // 3. disk
            let fresh = try await remote.fetch(url)                       // 4. network
            try? await disk.write(fresh, for: url)
            return fresh
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let result = try await task.value
        memory.put(url, result)
        return result
    }
}
```

The four things interviewers look for:
1. **Layered lookup** memory → disk → network, each behind a protocol.
2. **Request coalescing** — 60 cells requesting the same avatar must produce one network call. This is the actor-reentrancy pattern from Module 09 E6, and it's the detail that separates a real answer from a sketch.
3. **Eviction** — LRU with a cost limit in memory (Module 11), size/age limit on disk.
4. **Cancellation** — a scrolled-away cell's task should be cancellable, which is why the work is a `Task`.

Follow-ups to be ready for: decoding on a background thread and storing decoded bitmaps; `prepareForReuse` and stale-image bugs (the cell must check the URL still matches); `NSCache` vs a hand-rolled LRU (automatic eviction under pressure vs predictable policy).

---

## 6. Repository + DTO/Domain separation

```swift
// Data layer — mirrors the wire format exactly
struct UserDTO: Decodable {
    let user_id: String
    let full_name: String?
    let created_at: String
}

// Domain layer — what your app actually means
struct User: Equatable {
    let id: String
    let name: String
    let joined: Date
}

// The mapper is an Adapter (Module 06 §1)
extension UserDTO {
    func toDomain() throws -> User {
        guard let name = full_name, !name.isEmpty else { throw MappingError.missingName }
        guard let joined = ISO8601DateFormatter().date(from: created_at) else { throw MappingError.badDate }
        return User(id: user_id, name: name, joined: joined)
    }
}

// Protocol owned by the DOMAIN, implemented in DATA — that's DIP
protocol UserRepository { func user(id: String) async throws -> User }
```
**Why not decode straight into the domain type?** Because then a backend rename breaks your domain model, optionality from the wire leaks into your business rules, and your domain type has to conform to `Decodable` forever. The mapper is the one place where "the server said `full_name` was null" becomes a typed domain error.

---

## 7. Dependency injection in Swift

```swift
// Composition root — one place that knows the concrete types
enum AppComposer {
    static func makeProfileViewModel() -> ProfileViewModel {
        let transport = RetryingTransport(base: URLSessionTransport(), policy: .default)
        let api = APIClient(transport: transport, baseURL: .production, decoder: .snakeCase)
        let repo = CachingUserRepository(base: APIUserRepository(client: api), cache: .shared)
        return ProfileViewModel(loadProfile: LoadProfile(repository: repo))
    }
}
```

| Style | Use for | Watch out |
|---|---|---|
| Initialiser injection | domain and view models | the default; makes dependencies visible |
| Property injection | UIKit objects created by storyboards | optionality, ordering |
| Method injection | one-off collaborators | little value elsewhere |
| Environment (SwiftUI) | cross-cutting, view-scoped values | runtime failure if unset |
| `@propertyWrapper` container | leaf utilities | a service locator in disguise — hides dependencies |

**Interview-safe answer:** initialiser injection with a composition root; a container only for leaves; never a global locator in domain types.

---

## 8. Testability: the seams that matter

Everything that makes iOS code untestable is one of five ambient dependencies:

| Ambient dependency | Seam |
|---|---|
| `Date()` | `protocol Clock { func now() -> Date }` |
| `UUID()` | `protocol IDProvider` |
| `URLSession.shared` | `protocol HTTPTransport` |
| `UserDefaults.standard` | `protocol KeyValueStore` |
| `DispatchQueue.main` | `@MainActor` + injected scheduler |

If a class can't be tested, look for one of these five. This list is worth memorising — it turns "how would you test this?" from a vague question into a checklist.

---

## 9. Offline-first and sync (a strong differentiator)

> "Users must be able to like a post offline."

- **Command pattern** for mutations: each queued mutation is an object with `execute`/`rollback`.
- **Optimistic UI** — apply locally, enqueue, reconcile on response.
- **Idempotency keys** on every mutation so replays are safe (Module 09 §6).
- **Conflict policy** — last-write-wins, server-wins, or merge. Pick and justify; there's no default.
- **Outbox** persisted to disk so the queue survives a cold launch.

Naming idempotency and a conflict policy unprompted is a senior signal in an iOS design round.

---

## 10. iOS-specific interview prompts and what they're really testing

| Prompt | Actually testing |
|---|---|
| "Design an image-loading library" | layering, coalescing, eviction, cancellation |
| "Design a networking layer" | generics, decorators, error taxonomy, test seams |
| "Design an analytics SDK" | facade over multiple providers, buffering, PII discipline |
| "Design a feature-flag system" | strategy per flag kind, caching, defaults when offline |
| "How do you make a VC testable?" | DIP, the five ambient dependencies |
| "MVVM vs VIPER?" | judgment, not recitation |
| "How would you structure a 30-screen app?" | modules, layers, coordinators, dependency direction |
| "Design offline sync" | command queue, idempotency, conflicts |

---

## ✅ Checkpoint
1. Give the one-sentence test for whether a ViewModel is really a ViewModel.
2. State Clean Architecture's dependency rule and name the principle it is.
3. Why decode into a DTO rather than straight into the domain type?
4. Name the four things an image cache must do, and which one is the actor-reentrancy problem.
5. List the five ambient dependencies that make iOS code untestable, with their seams.

Then: `EXERCISES.md` → `swift test --filter M14` → `SOLUTIONS.md` → `PROJECT.md`.
