import XCTest
@testable import M14

final class StubTransport: HTTPTransport, @unchecked Sendable {
    var responses: [Result<HTTPResponse, TransportError>] = []
    private(set) var calls: [String] = []
    func send(url: String, method: HTTPMethod) throws -> HTTPResponse {
        calls.append("\(method.rawValue) \(url)")
        guard !responses.isEmpty else { return HTTPResponse(status: 200, body: "ok") }
        switch responses.removeFirst() {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

actor CountingFetcher: RemoteImageFetching {
    private(set) var calls: [String] = []
    private var delayNanos: UInt64 = 0
    private var failingURLs: Set<String> = []

    func setDelay(_ nanos: UInt64) { delayNanos = nanos }
    func setFailing(_ urls: Set<String>) { failingURLs = urls }

    func fetch(_ url: String) async throws -> String {
        calls.append(url)
        let delay = delayNanos
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        if failingURLs.contains(url) { throw ImageError.notFound }
        return "data:\(url)"
    }
}

final class E1MappingTests: XCTestCase {
    func test_validMapping() throws {
        let dto = UserDTO(user_id: "u1", full_name: "Asha", created_at: "2024-03-01T10:00:00Z")
        let user = try dto.toDomain()
        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.name, "Asha")
        XCTAssertEqual(user.joinedEpoch, 1_709_287_200, accuracy: 1)
    }
    func test_missingName() {
        XCTAssertThrowsError(try UserDTO(user_id: "u1", full_name: nil, created_at: "2024-03-01T10:00:00Z").toDomain()) {
            XCTAssertEqual($0 as? MappingError, .missingName)
        }
        XCTAssertThrowsError(try UserDTO(user_id: "u1", full_name: "  ", created_at: "2024-03-01T10:00:00Z").toDomain()) {
            XCTAssertEqual($0 as? MappingError, .missingName)
        }
    }
    func test_badDate() {
        XCTAssertThrowsError(try UserDTO(user_id: "u1", full_name: "A", created_at: "yesterday").toDomain()) {
            XCTAssertEqual($0 as? MappingError, .badDate)
        }
    }
    func test_emptyIDCheckedFirst() {
        XCTAssertThrowsError(try UserDTO(user_id: " ", full_name: nil, created_at: "nope").toDomain()) {
            XCTAssertEqual($0 as? MappingError, .emptyID, "id is validated before name and date")
        }
    }
    func test_mapAllPartitionsSuccessesAndFailures() {
        let result = UserMapper().mapAll([
            UserDTO(user_id: "u1", full_name: "Asha", created_at: "2024-03-01T10:00:00Z"),
            UserDTO(user_id: "u2", full_name: nil, created_at: "2024-03-01T10:00:00Z"),
            UserDTO(user_id: "u3", full_name: "Bo", created_at: "2024-03-02T10:00:00Z"),
        ])
        XCTAssertEqual(result.users.map(\.id), ["u1", "u3"])
        XCTAssertEqual(result.failedIDs, ["u2"])
    }
}

final class E2NetworkingTests: XCTestCase {
    func test_urlBuilding() {
        XCTAssertEqual(Endpoint(path: "users").url(base: "https://api.x"), "https://api.x/users")
        XCTAssertEqual(
            Endpoint(path: "users", query: ["page": "2", "limit": "10"]).url(base: "https://api.x"),
            "https://api.x/users?limit=10&page=2")
    }
    func test_successfulDecode() throws {
        let t = StubTransport()
        t.responses = [.success(HTTPResponse(status: 200, body: "42"))]
        let client = APIClient(transport: t, baseURL: "https://api.x")
        let value: Int = try client.send(Endpoint(path: "n")) { Int($0) }
        XCTAssertEqual(value, 42)
        XCTAssertEqual(t.calls, ["GET https://api.x/n"])
    }
    func test_httpErrorIsDistinctFromDecoding() {
        let t = StubTransport()
        t.responses = [.success(HTTPResponse(status: 404, body: "nope"))]
        let client = APIClient(transport: t, baseURL: "https://api.x")
        XCTAssertThrowsError(try client.send(Endpoint(path: "n")) { Int($0) }) {
            XCTAssertEqual($0 as? APIError, .http(status: 404))
        }
    }
    func test_decodingFailure() {
        let t = StubTransport()
        t.responses = [.success(HTTPResponse(status: 200, body: "not-a-number"))]
        let client = APIClient(transport: t, baseURL: "https://api.x")
        XCTAssertThrowsError(try client.send(Endpoint(path: "n")) { Int($0) }) {
            XCTAssertEqual($0 as? APIError, .decoding)
        }
    }
    func test_transportErrorSurfacesAsTransport() {
        let t = StubTransport()
        t.responses = [.failure(.offline)]
        let client = APIClient(transport: t, baseURL: "https://api.x")
        XCTAssertThrowsError(try client.send(Endpoint(path: "n")) { Int($0) }) {
            XCTAssertEqual($0 as? APIError, .transport(.offline))
        }
    }
    func test_retryDecoratorRetriesTransportFailures() throws {
        let t = StubTransport()
        t.responses = [.failure(.timedOut), .failure(.timedOut), .success(HTTPResponse(status: 200, body: "7"))]
        let retrying = RetryingTransport(base: t, maxAttempts: 3)
        let client = APIClient(transport: retrying, baseURL: "https://api.x")
        let value: Int = try client.send(Endpoint(path: "n")) { Int($0) }
        XCTAssertEqual(value, 7)
        XCTAssertEqual(retrying.attemptCount, 3)
    }
    func test_retryGivesUp() {
        let t = StubTransport()
        t.responses = [.failure(.offline), .failure(.offline), .failure(.offline)]
        let retrying = RetryingTransport(base: t, maxAttempts: 2)
        XCTAssertThrowsError(try retrying.send(url: "u", method: .get)) {
            XCTAssertEqual($0 as? TransportError, .offline)
        }
        XCTAssertEqual(retrying.attemptCount, 2)
    }
    func test_decoratorsCompose() throws {
        let t = StubTransport()
        t.responses = [.failure(.timedOut), .success(HTTPResponse(status: 200, body: "1"))]
        let logging = LoggingTransport(base: t)
        let retrying = RetryingTransport(base: logging, maxAttempts: 3)
        _ = try retrying.send(url: "https://api.x/n", method: .get)
        XCTAssertEqual(logging.log, ["GET https://api.x/n", "GET https://api.x/n"],
                       "the logger sits inside retry, so it records every attempt")
    }
}

final class E3ImageLoaderTests: XCTestCase {
    func test_fetchesOnceThenServesFromMemory() async throws {
        let fetcher = CountingFetcher()
        let loader = ImageLoader(remote: fetcher)
        let a = try await loader.image(for: "u1")
        let b = try await loader.image(for: "u1")
        XCTAssertEqual(a, "data:u1")
        XCTAssertEqual(b, "data:u1")
        let calls = await fetcher.calls
        XCTAssertEqual(calls, ["u1"])
        let hits = await loader.memoryHits
        XCTAssertEqual(hits, 1)
    }
    func test_coalescesConcurrentRequests() async throws {
        let fetcher = CountingFetcher()
        await fetcher.setDelay(20_000_000)
        let loader = ImageLoader(remote: fetcher)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 { group.addTask { _ = try? await loader.image(for: "same") } }
        }
        let calls = await fetcher.calls
        XCTAssertEqual(calls.count, 1, "50 concurrent requests for one url must fetch once")
    }
    func test_failuresAreNotCached() async {
        let fetcher = CountingFetcher()
        await fetcher.setFailing(["bad"])
        let loader = ImageLoader(remote: fetcher)
        _ = try? await loader.image(for: "bad")
        _ = try? await loader.image(for: "bad")
        let calls = await fetcher.calls
        XCTAssertEqual(calls, ["bad", "bad"])
        let cached = await loader.cachedURLs
        XCTAssertEqual(cached, [])
    }
    func test_distinctURLs() async throws {
        let fetcher = CountingFetcher()
        let loader = ImageLoader(remote: fetcher)
        _ = try await loader.image(for: "a")
        _ = try await loader.image(for: "b")
        let cached = await loader.cachedURLs
        XCTAssertEqual(cached, ["a", "b"])
    }
}

final class E4ContainerTests: XCTestCase {
    private final class Counter14 { static nonisolated(unsafe) var built = 0; init() { Counter14.built += 1 } }

    func test_transientBuildsEveryTime() {
        Counter14.built = 0
        let c = Container()
        c.register(Counter14.self, scope: .transient) { Counter14() }
        _ = c.resolve(Counter14.self)
        _ = c.resolve(Counter14.self)
        XCTAssertEqual(Counter14.built, 2)
    }
    func test_singletonBuildsOnce() {
        Counter14.built = 0
        let c = Container()
        c.register(Counter14.self, scope: .singleton) { Counter14() }
        let a = c.resolve(Counter14.self)
        let b = c.resolve(Counter14.self)
        XCTAssertEqual(Counter14.built, 1)
        XCTAssertTrue(a === b)
    }
    func test_unregisteredResolvesToNil() {
        XCTAssertNil(Container().resolve(String.self))
    }
    func test_registrationsAreKeyedByType() {
        let c = Container()
        c.register(String.self) { "hello" }
        c.register(Int.self) { 42 }
        XCTAssertEqual(c.resolve(String.self), "hello")
        XCTAssertEqual(c.resolve(Int.self), 42)
        XCTAssertEqual(c.registeredCount, 2)
    }
    func test_reregisteringReplaces() {
        let c = Container()
        c.register(String.self) { "a" }
        c.register(String.self) { "b" }
        XCTAssertEqual(c.resolve(String.self), "b")
        XCTAssertEqual(c.registeredCount, 1)
    }
}

final class E5ViewModelTests: XCTestCase {
    private struct OKUseCase: LoadProfileUseCase {
        func execute(id: String) async throws -> User14 {
            User14(id: id, name: "Asha", joinedEpoch: 1_700_000_000)
        }
    }
    private struct FailingUseCase: LoadProfileUseCase {
        func execute(id: String) async throws -> User14 { throw MappingError.missingName }
    }

    func test_happyPathStates() async {
        let vm = ProfileViewModel(useCase: OKUseCase())
        await vm.load(id: "u1")
        let history = await vm.stateHistory
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0], .idle)
        XCTAssertEqual(history[1], .loading)
        XCTAssertEqual(history[2], .loaded(ProfileUI(title: "Asha", subtitle: "Member since 1700000000.0")))
    }
    func test_failurePath() async {
        let vm = ProfileViewModel(useCase: FailingUseCase())
        await vm.load(id: "u1")
        let state = await vm.state
        XCTAssertEqual(state, .failed("missingName"))
    }
    func test_retryGoesThroughLoadingAgain() async {
        let vm = ProfileViewModel(useCase: FailingUseCase())
        await vm.load(id: "u1")
        await vm.retry(id: "u1")
        let history = await vm.stateHistory
        XCTAssertEqual(history, [.idle, .loading, .failed("missingName"), .loading, .failed("missingName")])
    }
}
