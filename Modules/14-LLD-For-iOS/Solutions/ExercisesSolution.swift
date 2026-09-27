//  Module 14 reference solutions.
//
//  HOW TO READ THIS FILE
//  Everything here is the part of an app that must be testable WITHOUT a simulator.
//  The comments answer one recurring question: where is the boundary, and what
//  stops at it?
//    - the wire boundary stops the server's optionality and vocabulary
//    - the error taxonomy stops "something went wrong" from reaching the UI
//    - the transport seam stops the network from reaching your tests
//    - the state enum stops impossible screen states from existing
//
//  The image loader is the one to study hardest: its ordering bug is invisible in
//  any sequential test.
//
//  Not part of the M14 target.

import Foundation

// MARK: - E1 Mapping

public struct UserDTO: Equatable, Sendable {
    public let user_id: String
    public let full_name: String?
    public let created_at: String
    public init(user_id: String, full_name: String?, created_at: String) {
        self.user_id = user_id; self.full_name = full_name; self.created_at = created_at
    }
}

public struct User14: Equatable, Sendable {
    public let id: String
    public let name: String
    public let joinedEpoch: Double
    public init(id: String, name: String, joinedEpoch: Double) {
        self.id = id; self.name = name; self.joinedEpoch = joinedEpoch
    }
}

public enum MappingError: Error, Equatable, Sendable { case missingName, badDate, emptyID }

public extension UserDTO {
    // THE WALL WHERE THE OUTSIDE WORLD STOPS. Three things happen here, and each
    // is worth doing deliberately:
    //  1. OPTIONALITY ENDS. `full_name: String?` becomes `name: String`. After
    //     this line nobody writes `user.name ?? ""` ever again.
    //  2. VOCABULARY CHANGES. `user_id` is the backend's word; `id` is yours. A
    //     rename on their side touches exactly one file.
    //  3. FAILURE BECOMES TYPED AND LOCAL. "The server sent an unparseable date"
    //     is a value you can decide about, not a crash three layers up.
    //
    // Decoding straight into the domain type saves ten minutes and costs you the
    // boundary — forever.
    func toDomain() throws -> User14 {
        let id = user_id.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { throw MappingError.emptyID }
        guard let raw = full_name?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            throw MappingError.missingName
        }
        guard let date = ISO8601DateFormatter().date(from: created_at) else { throw MappingError.badDate }
        return User14(id: id, name: raw, joinedEpoch: date.timeIntervalSince1970)
    }
}

public struct UserMapper {
    public init() {}
    public func mapAll(_ dtos: [UserDTO]) -> (users: [User14], failedIDs: [String]) {
        var users: [User14] = []
        var failed: [String] = []
        for dto in dtos {
            if let user = try? dto.toDomain() { users.append(user) } else { failed.append(dto.user_id) }
        }
        return (users, failed)
    }
}

// MARK: - E2 Networking

public enum HTTPMethod: String, Equatable { case get = "GET", post = "POST" }

public struct Endpoint: Equatable {
    public let path: String
    public let method: HTTPMethod
    public let query: [String: String]
    public init(path: String, method: HTTPMethod = .get, query: [String: String] = [:]) {
        self.path = path; self.method = method; self.query = query
    }
    public func url(base: String) -> String {
        let root = "\(base)/\(path)"
        guard !query.isEmpty else { return root }
        let pairs = query.keys.sorted().map { "\($0)=\(query[$0]!)" }
        return root + "?" + pairs.joined(separator: "&")
    }
}

public struct HTTPResponse: Equatable {
    public let status: Int
    public let body: String
    public init(status: Int, body: String) { self.status = status; self.body = body }
}

public enum TransportError: Error, Equatable { case offline, timedOut }

public enum APIError: Error, Equatable {
    case transport(TransportError)
    case http(status: Int)
    case decoding
}

public protocol HTTPTransport {
    func send(url: String, method: HTTPMethod) throws -> HTTPResponse
}

public struct APIClient {
    private let transport: any HTTPTransport
    private let baseURL: String
    public init(transport: any HTTPTransport, baseURL: String) {
        self.transport = transport; self.baseURL = baseURL
    }

    public func send<T>(_ endpoint: Endpoint, decode: (String) -> T?) throws -> T {
        let response: HTTPResponse
        do {
            response = try transport.send(url: endpoint.url(base: baseURL), method: endpoint.method)
        // THREE ERROR KINDS BECAUSE CALLERS DO THREE DIFFERENT THINGS:
        //  transport -> retry, or show "you are offline"
        //  http 401  -> refresh the token; 404 -> empty state
        //  decoding  -> a BUG; log it and alert engineering
        // Collapse them into one `networkError` and the UI cannot behave correctly.
        } catch let error as TransportError {
            throw APIError.transport(error)          // three distinct failure kinds, never conflated
        }
        guard (200..<300).contains(response.status) else { throw APIError.http(status: response.status) }
        guard let value = decode(response.body) else { throw APIError.decoding }
        return value
    }
}

public final class RetryingTransport: HTTPTransport {
    private let base: any HTTPTransport
    private let maxAttempts: Int
    public private(set) var attemptCount = 0

    public init(base: any HTTPTransport, maxAttempts: Int) {
        self.base = base; self.maxAttempts = max(1, maxAttempts)
    }

    public func send(url: String, method: HTTPMethod) throws -> HTTPResponse {
        var lastError: Error = TransportError.timedOut
        for _ in 0..<maxAttempts {
            attemptCount += 1
            do { return try base.send(url: url, method: method) }
            catch let error as TransportError { lastError = error; continue }   // only transport failures
            catch { throw error }
        }
        throw lastError
    }
}

public final class LoggingTransport: HTTPTransport {
    private let base: any HTTPTransport
    public private(set) var log: [String] = []
    public init(base: any HTTPTransport) { self.base = base }
    public func send(url: String, method: HTTPMethod) throws -> HTTPResponse {
        // Logged BEFORE the call. Log after and the entries you most need at 3am —
        // the attempts that failed — are exactly the ones missing.
        //
        // Both decorators conform to the same protocol as the thing they wrap, so
        // APIClient never learns they exist. Which concerns are active becomes a
        // startup CONFIGURATION rather than a code change in any feature.
        log.append("\(method.rawValue) \(url)")      // logged BEFORE the call, so failures appear too
        return try base.send(url: url, method: method)
    }
}

// MARK: - E3 Image loader

public protocol RemoteImageFetching: Sendable {
    func fetch(_ url: String) async throws -> String
}

public enum ImageError: Error, Equatable { case notFound }

public actor ImageLoader {
    private var memory: [String: String] = [:]
    private var inFlight: [String: Task<String, Error>] = [:]
    private let remote: any RemoteImageFetching
    public private(set) var memoryHits = 0

    public init(remote: any RemoteImageFetching) { self.remote = remote }

    public func image(for url: String) async throws -> String {
        if let hit = memory[url] { memoryHits += 1; return hit }
        if let existing = inFlight[url] { return try await existing.value }   // coalesce

        let remote = self.remote
        // THE ORDERING IS THE WHOLE EXERCISE.
        // `inFlight[url] = task` executes BEFORE any `await`, so it is atomic with
        // respect to the actor: every later caller sees the task and awaits it.
        // Move the assignment after the `await` and all 50 callers miss the check
        // and fire 50 requests — a bug that ships regularly, because it is
        // invisible in any sequential test.
        //
        // This is the table-view case: 60 cells asking for the same avatar.
        // One request, 60 awaiters. Same idiom deduplicates token refreshes and
        // double-submit taps.
        let task = Task<String, Error> { try await remote.fetch(url) }
        inFlight[url] = task                                                   // publish BEFORE suspending
        do {
            let value = try await task.value
            inFlight[url] = nil
            memory[url] = value
            return value
        // Two separate hazards handled in one line: caching a failure would blank
        // that avatar for the rest of the session, and leaving the in-flight entry
        // behind would poison the URL permanently — every future caller would
        // await a task that has already failed.
        } catch {
            inFlight[url] = nil                                                // failures are not cached
            throw error
        }
    }

    public var cachedURLs: [String] { memory.keys.sorted() }
}

// MARK: - E4 Container

public enum Scope: Equatable { case transient, singleton }

public final class Container {
    private var factories: [String: (scope: Scope, make: () -> Any)] = [:]
    private var singletons: [String: Any] = [:]
    public init() {}

    // SAY THE CAVEAT OUT LOUD: this is a Service Locator. At the composition root,
    // building object graphs, it is a convenience. Injected into domain types so
    // they call `resolve` themselves, it UNDOES dependency inversion — dependencies
    // become invisible, the compiler stops checking them, and a missing
    // registration becomes a runtime nil instead of a compile error.
    //
    // The rule: containers BUILD objects; objects RECEIVE dependencies through init.
    public func register<T>(_ type: T.Type, scope: Scope = .transient, make: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = (scope, { make() })
        singletons[key] = nil                       // re-registering invalidates a cached instance
    }

    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let entry = factories[key] else { return nil }
        if entry.scope == .singleton, let cached = singletons[key] as? T { return cached }
        guard let made = entry.make() as? T else { return nil }
        if entry.scope == .singleton { singletons[key] = made }
        return made
    }

    public var registeredCount: Int { factories.count }
}

// MARK: - E5 ViewModel

public struct ProfileUI: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public init(title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }
}

public protocol LoadProfileUseCase: Sendable {
    func execute(id: String) async throws -> User14
}

// ONE value with four cases, not three booleans. With `isLoading` / `data` /
// `errorMessage` you can represent "loading AND failed AND holding data" — and
// eventually you will ship it, with the spinner still visible behind the error.
// The enum makes that state unsayable.
//
// It also doubles as a checklist: enumerate the cases and you have enumerated
// what the screen must handle, including the empty state everyone forgets.
public enum ProfileState: Equatable, Sendable {
    case idle, loading, loaded(ProfileUI), failed(String)
}

public actor ProfileViewModel {
    public private(set) var state: ProfileState = .idle
    public private(set) var stateHistory: [ProfileState] = [.idle]
    private let useCase: any LoadProfileUseCase

    public init(useCase: any LoadProfileUseCase) { self.useCase = useCase }

    // The view model exposes `ProfileUI`, NOT `User14`. Presentation formatting —
    // locale, currency, phrasing — lives here, so the view stays a dumb renderer
    // and the formatting is unit-testable. That separation is what people mean by
    // "a real ViewModel".
    //
    // It is an actor here so tests run without a main-thread runtime. In an app it
    // would be `@MainActor final class ...: ObservableObject` with
    // `@Published private(set) var state` — same design, different isolation
    // annotation, and the tests barely change.
    public func load(id: String) async {
        transition(to: .loading)
        do {
            let user = try await useCase.execute(id: id)
            transition(to: .loaded(ProfileUI(title: user.name,
                                             subtitle: "Member since \(user.joinedEpoch)")))
        } catch {
            transition(to: .failed(String(describing: error)))
        }
    }

    public func retry(id: String) async { await load(id: id) }

    private func transition(to next: ProfileState) {
        state = next
        stateHistory.append(next)
    }
}
