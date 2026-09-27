import XCTest
@testable import M01

// MARK: - Test doubles

final class SpyChannel: Channel, @unchecked Sendable {
    let id: String
    private(set) var received: [String] = []
    init(id: String) { self.id = id }
    func deliver(_ message: String) { received.append(message) }
}

struct StubFeed: PriceFeed {
    let prices: [String: Decimal]
    func price(for ticker: String) -> Decimal? { prices[ticker] }
}

final class SpyRepository: UserRepository, @unchecked Sendable {
    var existingEmails: Set<String> = []
    var shouldThrowOnSave = false
    private(set) var saved: [User] = []
    func save(_ user: User) throws {
        if shouldThrowOnSave { throw NSError(domain: "db", code: 1) }
        saved.append(user)
    }
    func exists(email: String) -> Bool { existingEmails.contains(email) }
}

final class SpyMailer: Mailer, @unchecked Sendable {
    private(set) var mailed: [User] = []
    func sendWelcome(to user: User) throws { mailed.append(user) }
}

// MARK: - E1

final class E1MoneyTests: XCTestCase {
    func test_rejectsNegativeAmount() {
        XCTAssertNil(Money(amount: -1, currency: "INR"))
    }
    func test_rejectsBadCurrencyCode() {
        XCTAssertNil(Money(amount: 10, currency: "inr"))
        XCTAssertNil(Money(amount: 10, currency: "RUPEE"))
    }
    func test_acceptsValidMoney() throws {
        let m = try XCTUnwrap(Money(amount: 10, currency: "INR"))
        XCTAssertEqual(m.amount, 10)
        XCTAssertEqual(m.currency, "INR")
    }
    func test_addsSameCurrency() throws {
        let a = try XCTUnwrap(Money(amount: 10, currency: "INR"))
        let b = try XCTUnwrap(Money(amount: 5, currency: "INR"))
        XCTAssertEqual(try Money.add(a, b), Money(amount: 15, currency: "INR"))
    }
    func test_throwsOnCurrencyMismatch() throws {
        let a = try XCTUnwrap(Money(amount: 10, currency: "INR"))
        let b = try XCTUnwrap(Money(amount: 5, currency: "USD"))
        XCTAssertThrowsError(try Money.add(a, b)) {
            XCTAssertEqual($0 as? Money.MoneyError, .currencyMismatch)
        }
    }
    func test_hasValueSemantics() throws {
        let a = try XCTUnwrap(Money(amount: 10, currency: "INR"))
        var b = a
        b = try XCTUnwrap(Money(amount: 99, currency: "INR"))
        XCTAssertEqual(a.amount, 10, "Money must be a value type; mutating the copy changed the original")
    }
}

// MARK: - E2

final class E2AccountTests: XCTestCase {
    func test_openingBalance() {
        XCTAssertEqual(BankAccount(opening: 100).balance, 100)
    }
    func test_deposit() throws {
        let a = BankAccount(opening: 100)
        try a.deposit(50)
        XCTAssertEqual(a.balance, 150)
    }
    func test_withdraw() throws {
        let a = BankAccount(opening: 100)
        try a.withdraw(40)
        XCTAssertEqual(a.balance, 60)
    }
    func test_rejectsNonPositive() {
        let a = BankAccount(opening: 100)
        XCTAssertThrowsError(try a.deposit(0)) { XCTAssertEqual($0 as? AccountError, .nonPositiveAmount) }
        XCTAssertThrowsError(try a.withdraw(-5)) { XCTAssertEqual($0 as? AccountError, .nonPositiveAmount) }
    }
    func test_neverGoesNegative() {
        let a = BankAccount(opening: 100)
        XCTAssertThrowsError(try a.withdraw(101)) { XCTAssertEqual($0 as? AccountError, .insufficientFunds) }
        XCTAssertEqual(a.balance, 100, "A failed withdrawal must not change the balance")
    }
    func test_historyRecordsSignedAmounts() throws {
        let a = BankAccount(opening: 100)
        try a.deposit(50)
        try a.withdraw(20)
        try? a.withdraw(10_000)                     // failed, must not be recorded
        XCTAssertEqual(a.history, [50, -20])
    }
}

// MARK: - E3

final class E3ShapeTests: XCTestCase {
    func test_areas() {
        XCTAssertEqual(Circle(radius: 2).area(), Double.pi * 4, accuracy: 0.0001)
        XCTAssertEqual(Rectangle(width: 3, height: 4).area(), 12, accuracy: 0.0001)
        XCTAssertEqual(Triangle(base: 6, height: 4).area(), 12, accuracy: 0.0001)
    }
    func test_names() {
        XCTAssertEqual(Circle(radius: 1).name, "Circle")
        XCTAssertEqual(Rectangle(width: 1, height: 1).name, "Rectangle")
        XCTAssertEqual(Triangle(base: 1, height: 1).name, "Triangle")
    }
    func test_polymorphicTotal() {
        let shapes: [any Shape] = [Circle(radius: 1), Rectangle(width: 2, height: 2), Triangle(base: 2, height: 2)]
        XCTAssertEqual(totalArea(shapes), Double.pi + 4 + 2, accuracy: 0.0001)
    }
    func test_emptyTotalIsZero() {
        XCTAssertEqual(totalArea([]), 0, accuracy: 0.0001)
    }
    func test_filterByArea() {
        let shapes: [any Shape] = [Circle(radius: 1), Rectangle(width: 10, height: 10), Triangle(base: 1, height: 1)]
        XCTAssertEqual(namesOfShapesLarger(than: 3, in: shapes), ["Circle", "Rectangle"])
    }
}

// MARK: - E4

final class E4CompositionTests: XCTestCase {
    func test_deliversToEveryChannelInOrder() {
        let a = SpyChannel(id: "a"), b = SpyChannel(id: "b")
        Notifier(channels: [a, b]).send("hi")
        XCTAssertEqual(a.received, ["hi"])
        XCTAssertEqual(b.received, ["hi"])
    }
    func test_noChannelsIsSafe() {
        Notifier(channels: []).send("hi")           // must not crash
    }
    func test_addingReturnsNewNotifierWithoutMutating() {
        let a = SpyChannel(id: "a"), b = SpyChannel(id: "b")
        let base = Notifier(channels: [a])
        let extended = base.adding(b)
        base.send("one")
        XCTAssertEqual(a.received, ["one"])
        XCTAssertEqual(b.received, [], "adding(_:) must not mutate the original Notifier")
        extended.send("two")
        XCTAssertEqual(a.received, ["one", "two"])
        XCTAssertEqual(b.received, ["two"])
    }
}

// MARK: - E5

final class E5SemanticsTests: XCTestCase {
    func test_structCopiesAreIndependent() {
        var p1 = Playlist(songs: ["a"])
        var p2 = p1
        p2.add("b")
        XCTAssertEqual(p1.songs, ["a"], "Playlist is a struct: the copy must be independent")
        XCTAssertEqual(p2.songs, ["a", "b"])
        p1.add("c")
        XCTAssertEqual(p2.songs, ["a", "b"])
    }
    func test_classReferencesAreShared() {
        let s1 = SharedPlaylist(songs: ["a"])
        let s2 = s1
        s2.add("b")
        XCTAssertEqual(s1.songs, ["a", "b"], "SharedPlaylist is a class: both names point at one instance")
        XCTAssertTrue(s1 === s2)
    }
    func test_defensiveCopyIsIndependent() {
        let s1 = SharedPlaylist(songs: ["a"])
        let s2 = s1.copy()
        s2.add("b")
        XCTAssertEqual(s1.songs, ["a"])
        XCTAssertEqual(s2.songs, ["a", "b"])
        XCTAssertFalse(s1 === s2)
    }
}

// MARK: - E6

final class E6ProtocolTests: XCTestCase {
    func test_defaultImplementationUsedWhenNotOverridden() {
        XCTAssertEqual(Bike().honk(), "beep")
    }
    func test_conformerOverridesDefault() {
        XCTAssertEqual(Truck().honk(), "HOOONK")
    }
    func test_overrideIsDynamicallyDispatchedThroughExistential() {
        let vehicles: [any Vehicle] = [Bike(), Truck()]
        XCTAssertEqual(vehicles.map { $0.honk() }, ["beep", "HOOONK"],
                       "honk() must be declared in the protocol body so the override wins through `any Vehicle`")
    }
    func test_sharedSummary() {
        XCTAssertEqual(Bike().summary, "Bike with 2 wheels")
        XCTAssertEqual(Truck().summary, "Truck with 6 wheels")
    }
}

// MARK: - E7

final class E7CouplingTests: XCTestCase {
    private let holdings = [Holding(ticker: "AAPL", quantity: 3),
                            Holding(ticker: "MSFT", quantity: 2),
                            Holding(ticker: "ZZZZ", quantity: 10)]

    func test_totalValueSkipsUnknownTickers() {
        let svc = PortfolioService(feed: StubFeed(prices: ["AAPL": 100, "MSFT": 50]))
        XCTAssertEqual(svc.totalValue(of: holdings), 400)
    }
    func test_unpricedTickers() {
        let svc = PortfolioService(feed: StubFeed(prices: ["AAPL": 100, "MSFT": 50]))
        XCTAssertEqual(svc.unpricedTickers(in: holdings), ["ZZZZ"])
    }
    func test_worksWithADifferentFeedImplementation() {
        struct FlatFeed: PriceFeed { func price(for t: String) -> Decimal? { 10 } }
        let svc = PortfolioService(feed: FlatFeed())
        XCTAssertEqual(svc.totalValue(of: holdings), 150)
    }
    func test_emptyPortfolio() {
        XCTAssertEqual(PortfolioService(feed: StubFeed(prices: [:])).totalValue(of: []), 0)
    }
}

// MARK: - E8

final class E8CohesionTests: XCTestCase {
    func test_happyPathSavesThenMails() throws {
        let repo = SpyRepository(), mailer = SpyMailer()
        let user = User(id: "1", email: "a@b.com")
        try UserService(repository: repo, mailer: mailer).register(user)
        XCTAssertEqual(repo.saved, [user])
        XCTAssertEqual(mailer.mailed, [user])
    }
    func test_rejectsInvalidEmailBeforeTouchingCollaborators() {
        let repo = SpyRepository(), mailer = SpyMailer()
        XCTAssertThrowsError(try UserService(repository: repo, mailer: mailer)
            .register(User(id: "1", email: "nope"))) {
            XCTAssertEqual($0 as? RegistrationError, .invalidEmail)
        }
        XCTAssertTrue(repo.saved.isEmpty)
        XCTAssertTrue(mailer.mailed.isEmpty)
    }
    func test_rejectsDuplicateEmail() {
        let repo = SpyRepository(); repo.existingEmails = ["a@b.com"]
        let mailer = SpyMailer()
        XCTAssertThrowsError(try UserService(repository: repo, mailer: mailer)
            .register(User(id: "1", email: "a@b.com"))) {
            XCTAssertEqual($0 as? RegistrationError, .duplicateEmail)
        }
        XCTAssertTrue(mailer.mailed.isEmpty)
    }
    func test_doesNotMailIfSaveFails() {
        let repo = SpyRepository(); repo.shouldThrowOnSave = true
        let mailer = SpyMailer()
        XCTAssertThrowsError(try UserService(repository: repo, mailer: mailer)
            .register(User(id: "1", email: "a@b.com")))
        XCTAssertTrue(mailer.mailed.isEmpty, "A failed save must abort before the welcome mail")
    }
}
