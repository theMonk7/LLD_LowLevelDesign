import XCTest
@testable import M06

final class FakeRepo: UserRepository6, @unchecked Sendable {
    var results: [String: Result<String, RepoError>] = [:]
    private(set) var calls: [String] = []
    var transientFailuresBeforeSuccess = 0
    func name(forID id: String) throws -> String {
        calls.append(id)
        if transientFailuresBeforeSuccess > 0 { transientFailuresBeforeSuccess -= 1; throw RepoError.transient }
        switch results[id] {
        case .success(let n): return n
        case .failure(let e): throw e
        case nil: throw RepoError.notFound
        }
    }
}

final class E1AdapterTests: XCTestCase {
    func test_translatesUnitsAndReturnsTransactionID() throws {
        let adapter = LegacyPayAdapter(sdk: LegacyPayGateway())
        XCTAssertEqual(try adapter.pay(amountInPaise: 12_550, orderID: "o1"), "TXN-o1-INR")
    }
    func test_declineBecomesATypedError() {
        let adapter = LegacyPayAdapter(sdk: LegacyPayGateway(alwaysDeclineOver: 100))
        XCTAssertThrowsError(try adapter.pay(amountInPaise: 50_000, orderID: "o2")) {
            XCTAssertEqual($0 as? PaymentError, .declined)
        }
    }
    func test_amountJustUnderTheDeclineThresholdSucceeds() throws {
        let adapter = LegacyPayAdapter(sdk: LegacyPayGateway(alwaysDeclineOver: 100))
        XCTAssertEqual(try adapter.pay(amountInPaise: 9_900, orderID: "o3"), "TXN-o3-INR")
    }
}

final class E2BridgeTests: XCTestCase {
    func test_sameShapeDifferentRenderers() {
        XCTAssertEqual(Circle6(radius: 2, renderer: SVGRenderer()).draw(), "<circle r='2.0'/>")
        XCTAssertEqual(Circle6(radius: 2, renderer: ASCIIRenderer()).draw(), "O(2.0)")
    }
    func test_sameRendererDifferentShapes() {
        XCTAssertEqual(Square6(side: 3, renderer: SVGRenderer()).draw(), "<rect w='3.0'/>")
        XCTAssertEqual(Square6(side: 3, renderer: ASCIIRenderer()).draw(), "[3.0]")
    }
    /// M + N, not M × N: a new renderer works with every existing shape.
    func test_newRendererNeedsNoNewShapeTypes() {
        struct JSONRenderer: Renderer {
            func renderCircle(radius: Double) -> String { "{\"circle\":\(radius)}" }
            func renderSquare(side: Double) -> String { "{\"square\":\(side)}" }
        }
        XCTAssertEqual(Circle6(radius: 1, renderer: JSONRenderer()).draw(), "{\"circle\":1.0}")
        XCTAssertEqual(Square6(side: 1, renderer: JSONRenderer()).draw(), "{\"square\":1.0}")
    }
}

final class E3CompositeTests: XCTestCase {
    private var tree: any FileSystemItem {
        FolderItem(name: "src", children: [
            FileItem(name: "main.swift", bytes: 120),
            FolderItem(name: "models", children: [
                FileItem(name: "User.swift", bytes: 300),
                FileItem(name: "Order.swift", bytes: 80),
            ]),
        ])
    }
    func test_leafSize() { XCTAssertEqual(FileItem(name: "a", bytes: 5).size(), 5) }
    func test_recursiveSize() { XCTAssertEqual(tree.size(), 500) }
    func test_emptyFolder() { XCTAssertEqual(FolderItem(name: "empty", children: []).size(), 0) }
    func test_pathsDepthFirstParentsFirst() {
        XCTAssertEqual(tree.paths(prefix: ""),
                       ["/src", "/src/main.swift", "/src/models",
                        "/src/models/User.swift", "/src/models/Order.swift"])
    }
    /// The whole point: a caller handles one item and a whole tree identically.
    func test_uniformTreatment() {
        let items: [any FileSystemItem] = [FileItem(name: "x", bytes: 10), tree]
        XCTAssertEqual(items.reduce(0) { $0 + $1.size() }, 510)
    }
}

final class E4DecoratorTests: XCTestCase {
    func test_base() {
        XCTAssertEqual(Espresso().cost(), 120)
        XCTAssertEqual(Espresso().describe, "espresso")
    }
    func test_stacking() {
        let drink = Caramel(Milk(Espresso()))
        XCTAssertEqual(drink.describe, "espresso + milk + caramel")
        XCTAssertEqual(drink.cost(), 175)
    }
    func test_sameDecoratorTwice() {
        XCTAssertEqual(Milk(Milk(Espresso())).cost(), 160)
    }
    func test_orderMattersWithTax() {
        // tax applied last: (120 + 20) * 1.1 = 154
        XCTAssertEqual(Tax(Milk(Espresso()), rate: 0.1).cost(), 154)
        // milk added after tax: 120 * 1.1 + 20 = 152
        XCTAssertEqual(Milk(Tax(Espresso(), rate: 0.1)).cost(), 152)
    }
}

final class E5CrossCuttingDecoratorTests: XCTestCase {
    func test_cachingPreventsASecondCall() throws {
        let fake = FakeRepo(); fake.results = ["1": .success("Asha")]
        let caching = CachingRepository(base: fake)
        XCTAssertEqual(try caching.name(forID: "1"), "Asha")
        XCTAssertEqual(try caching.name(forID: "1"), "Asha")
        XCTAssertEqual(fake.calls, ["1"], "second lookup must be served from cache")
        XCTAssertEqual(caching.cachedIDs, ["1"])
    }
    func test_cachingDoesNotCacheFailures() {
        let fake = FakeRepo()
        let caching = CachingRepository(base: fake)
        XCTAssertThrowsError(try caching.name(forID: "9"))
        XCTAssertThrowsError(try caching.name(forID: "9"))
        XCTAssertEqual(fake.calls, ["9", "9"])
        XCTAssertEqual(caching.cachedIDs, [])
    }
    func test_loggingRecordsEvenFailedCalls() {
        let fake = FakeRepo(); fake.results = ["1": .success("Asha")]
        let logging = LoggingRepository(base: fake)
        _ = try? logging.name(forID: "1")
        _ = try? logging.name(forID: "missing")
        XCTAssertEqual(logging.log, ["get:1", "get:missing"])
    }
    func test_retryOnTransientOnly() throws {
        let fake = FakeRepo(); fake.results = ["1": .success("Asha")]
        fake.transientFailuresBeforeSuccess = 2
        let retrying = RetryingRepository(base: fake, maxAttempts: 3)
        XCTAssertEqual(try retrying.name(forID: "1"), "Asha")
        XCTAssertEqual(fake.calls.count, 3)
    }
    func test_retryGivesUpAfterMaxAttempts() {
        let fake = FakeRepo(); fake.results = ["1": .success("Asha")]
        fake.transientFailuresBeforeSuccess = 5
        let retrying = RetryingRepository(base: fake, maxAttempts: 3)
        XCTAssertThrowsError(try retrying.name(forID: "1")) { XCTAssertEqual($0 as? RepoError, .transient) }
        XCTAssertEqual(fake.calls.count, 3)
    }
    func test_nonTransientErrorIsNotRetried() {
        let fake = FakeRepo(); fake.results = ["1": .failure(.notFound)]
        let retrying = RetryingRepository(base: fake, maxAttempts: 3)
        XCTAssertThrowsError(try retrying.name(forID: "1")) { XCTAssertEqual($0 as? RepoError, .notFound) }
        XCTAssertEqual(fake.calls.count, 1)
    }
    /// Composition order changes behaviour: caching outside retry means one cached success ends all retries.
    func test_stackedDecorators() throws {
        let fake = FakeRepo(); fake.results = ["1": .success("Asha")]
        fake.transientFailuresBeforeSuccess = 1
        let stack = CachingRepository(base: RetryingRepository(base: LoggingRepository(base: fake), maxAttempts: 3))
        XCTAssertEqual(try stack.name(forID: "1"), "Asha")
        XCTAssertEqual(try stack.name(forID: "1"), "Asha")
        XCTAssertEqual(fake.calls.count, 2, "1 transient failure + 1 success; the repeat is cached")
    }
}

final class E6FacadeTests: XCTestCase {
    func test_oneCallRunsTheWholePipeline() {
        XCTAssertEqual(MediaConverter().convert(file: "clip", to: "mp4"), "2frames.mp4+clip#audio")
    }
}

final class E7FlyweightTests: XCTestCase {
    func test_sameNameReturnsSameInstance() {
        let f = PieceTypeFactory()
        let a = f.type("knight", rules: "L")
        let b = f.type("knight", rules: "L")
        XCTAssertTrue(a === b)
        XCTAssertEqual(f.distinctTypeCount, 1)
    }
    func test_thirtyTwoPiecesShareSixTypes() {
        let f = PieceTypeFactory()
        let names = ["pawn", "rook", "knight", "bishop", "queen", "king"]
        var board: [Piece6] = []
        for i in 0..<32 {
            let n = names[i % names.count]
            board.append(Piece6(type: f.type(n, rules: n), square: "sq\(i)", isWhite: i < 16))
        }
        XCTAssertEqual(board.count, 32)
        XCTAssertEqual(f.distinctTypeCount, 6)
        XCTAssertTrue(board[0].type === board[6].type)
    }
}

final class E8ProxyTests: XCTestCase {
    func test_protectionProxyAllowsAdmin() throws {
        XCTAssertEqual(try SecureDocument(base: RealDocument(text: "secret"), role: .admin).contents(), "secret")
    }
    func test_protectionProxyDeniesViewer() {
        XCTAssertThrowsError(try SecureDocument(base: RealDocument(text: "secret"), role: .viewer).contents()) {
            XCTAssertEqual($0 as? AccessError, .forbidden)
        }
    }
    func test_virtualProxyDefersCreation() throws {
        let lazyDoc = LazyDocument { RealDocument(text: "heavy") }
        XCTAssertFalse(lazyDoc.isLoaded)
        XCTAssertEqual(lazyDoc.makeCallCount, 0)
        XCTAssertEqual(try lazyDoc.contents(), "heavy")
        XCTAssertTrue(lazyDoc.isLoaded)
        XCTAssertEqual(try lazyDoc.contents(), "heavy")
        XCTAssertEqual(lazyDoc.makeCallCount, 1, "the real document is built exactly once")
    }
}

final class E9IdentificationTests: XCTestCase {
    func test_mapping() {
        let expected: [StructuralScenario: StructuralPattern] = [
            .wrapAThirdPartySDKWhoseMethodNamesDiffer: .adapter,
            .addCachingWithoutChangingTheRepository: .decorator,
            .treatAFolderAndAFileIdentically: .composite,
            .oneSimpleCallOverFourSubsystemSteps: .facade,
            .denyReadsUnlessTheUserIsAnAdmin: .proxy,
            .shapesTimesRenderersWouldBeMTimesNClasses: .bridge,
            .millionsOfParticlesSharingOneTexture: .flyweight,
        ]
        for s in StructuralScenario.allCases {
            XCTAssertEqual(pattern(for: s), expected[s], "wrong pattern for \(s.rawValue)")
        }
    }
}
