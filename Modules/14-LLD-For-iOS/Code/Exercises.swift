//  Module 14 — iOS architecture exercises.
//
//  No UIKit anywhere, and that is the point: everything here is the part of an app
//  that must be testable without a simulator.
//
//  BEFORE YOU TYPE, for each exercise:
//    E1  what stops at this boundary — optionality, vocabulary, failure shape?
//    E2  do three different failures reach the caller as three different values?
//        (transport / http status / decoding — callers do different things)
//    E3  sixty cells ask for the same image at the same instant. What guarantees
//        ONE fetch? And where exactly must that bookkeeping happen relative to the
//        first `await`?
//    E4  this is a service locator. Where is it acceptable, and where does it
//        undo dependency inversion?
//    E5  can this screen represent an impossible state? (loading AND failed AND
//        holding data). If yes, use one value with cases instead of flags.
//
//  Replace every fatalError("TODO").

import Foundation

// =====================================================================
// E1 — DTO → Domain mapping (Adapter at the data boundary)
// =====================================================================

public struct UserDTO: Equatable, Sendable {
    public let user_id: String
    public let full_name: String?
    public let created_at: String          // ISO-8601, e.g. "2024-03-01T10:00:00Z"
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
    /// Rules, in this order: empty/blank id -> .emptyID; nil or blank name -> .missingName;
    /// unparseable date -> .badDate. Use ISO8601DateFormatter.
    func toDomain() throws -> User14 { fatalError("TODO E1a") }
}

public struct UserMapper {
    public init() {}
    /// Maps what it can; returns the successes in order plus the ids that failed.
    public func mapAll(_ dtos: [UserDTO]) -> (users: [User14], failedIDs: [String]) {
        fatalError("TODO E1b")
    }
}

// =====================================================================
// E2 — Networking layer: typed endpoints, transport seam, error taxonomy
// =====================================================================

public enum HTTPMethod: String, Equatable { case get = "GET", post = "POST" }

public struct Endpoint: Equatable {
    public let path: String
    public let method: HTTPMethod
    public let query: [String: String]
    public init(path: String, method: HTTPMethod = .get, query: [String: String] = [:]) {
        self.path = path; self.method = method; self.query = query
    }
    /// "<base>/<path>?<k=v sorted by key, & separated>" — no "?" when there is no query.
    public func url(base: String) -> String { fatalError("TODO E2a") }
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

/// The test seam. Real apps put URLSession behind this.
public protocol HTTPTransport {
    func send(url: String, method: HTTPMethod) throws -> HTTPResponse
}

public struct APIClient {
    private let transport: any HTTPTransport
    private let baseURL: String
    public init(transport: any HTTPTransport, baseURL: String) { fatalError("TODO E2b") }

    /// 1. build the url  2. send  3. non-2xx -> .http(status)
    /// 4. decode with `decode`; a nil result -> .decoding
    /// A TransportError from the transport must surface as APIError.transport.
    public func send<T>(_ endpoint: Endpoint, decode: (String) -> T?) throws -> T {
        fatalError("TODO E2c")
    }
}

/// Decorator: retries only `.transport` failures, up to `maxAttempts` TOTAL attempts.
public final class RetryingTransport: HTTPTransport {
    private let base: any HTTPTransport
    private let maxAttempts: Int
    public private(set) var attemptCount = 0
    public init(base: any HTTPTransport, maxAttempts: Int) { fatalError("TODO E2d") }
    public func send(url: String, method: HTTPMethod) throws -> HTTPResponse { fatalError("TODO E2d") }
}

/// Decorator: records "<METHOD> <url>" for every attempt, including failures.
public final class LoggingTransport: HTTPTransport {
    private let base: any HTTPTransport
    public private(set) var log: [String] = []
    public init(base: any HTTPTransport) { fatalError("TODO E2e") }
    public func send(url: String, method: HTTPMethod) throws -> HTTPResponse { fatalError("TODO E2e") }
}

// =====================================================================
// E3 — Image loader: layered lookup + request coalescing
// =====================================================================

public protocol RemoteImageFetching: Sendable {
    func fetch(_ url: String) async throws -> String        // "image data"
}

public enum ImageError: Error, Equatable { case notFound }

public actor ImageLoader {
    private var memory: [String: String] = [:]
    private var inFlight: [String: Task<String, Error>] = [:]
    private let remote: any RemoteImageFetching
    public private(set) var memoryHits = 0

    public init(remote: any RemoteImageFetching) { fatalError("TODO E3a") }

    /// 1. memory hit -> return it and count the hit
    /// 2. a request already in flight for this url -> await THAT task (no second fetch)
    /// 3. otherwise fetch, store in memory, and return
    /// A failed fetch must NOT be cached, and must clear the in-flight entry.
    public func image(for url: String) async throws -> String { fatalError("TODO E3b") }

    public var cachedURLs: [String] { fatalError("TODO E3c") }      // sorted
}

// =====================================================================
// E4 — Dependency container (composition root, with scopes)
// =====================================================================

public enum Scope: Equatable { case transient, singleton }

public final class Container {
    private var factories: [String: (scope: Scope, make: () -> Any)] = [:]
    private var singletons: [String: Any] = [:]
    public init() {}

    public func register<T>(_ type: T.Type, scope: Scope = .transient, make: @escaping () -> T) {
        fatalError("TODO E4a")
    }

    /// nil when the type was never registered. `.transient` builds every time;
    /// `.singleton` builds once and returns the same instance afterwards.
    public func resolve<T>(_ type: T.Type) -> T? { fatalError("TODO E4b") }

    public var registeredCount: Int { fatalError("TODO E4c") }
}

// =====================================================================
// E5 — ViewModel as a state machine (no UIKit, fully testable)
// =====================================================================

public struct ProfileUI: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public init(title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }
}

public protocol LoadProfileUseCase: Sendable {
    func execute(id: String) async throws -> User14
}

public enum ProfileState: Equatable, Sendable {
    case idle
    case loading
    case loaded(ProfileUI)
    case failed(String)
}

public actor ProfileViewModel {
    public private(set) var state: ProfileState = .idle
    public private(set) var stateHistory: [ProfileState] = [.idle]
    private let useCase: any LoadProfileUseCase

    public init(useCase: any LoadProfileUseCase) { fatalError("TODO E5a") }

    /// .loading, then .loaded(title: user.name, subtitle: "Member since <joinedEpoch>")
    /// or .failed("<error description>") — use String(describing: error).
    /// Every state change must be appended to stateHistory.
    public func load(id: String) async { fatalError("TODO E5b") }

    /// Reloading after a failure must go through .loading again.
    public func retry(id: String) async { fatalError("TODO E5c") }
}
