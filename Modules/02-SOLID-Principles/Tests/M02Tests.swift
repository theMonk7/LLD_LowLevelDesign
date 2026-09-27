import XCTest
@testable import M02

// MARK: - Doubles

final class SpyStore: OrderStore, @unchecked Sendable {
    var shouldThrow = false
    private(set) var saved: [(Order, Decimal)] = []
    func save(_ order: Order, total: Decimal) throws {
        if shouldThrow { throw NSError(domain: "db", code: 1) }
        saved.append((order, total))
    }
}

final class SpyMailer: ReceiptMailer, @unchecked Sendable {
    private(set) var mailed: [String] = []
    func mailReceipt(for order: Order, total: Decimal) throws { mailed.append(order.id) }
}

struct FixedClock: Clock {
    let date: Date
    func now() -> Date { date }
}

struct DictMetrics: MetricsSource {
    let data: [String: [Double]]
    func values(for key: String) -> [Double] { data[key] ?? [] }
}

// MARK: - E1 SRP

final class E1SRPTests: XCTestCase {
    private let order = Order(id: "o1", lineTotals: [100, 100], customerEmail: "a@b.com")

    func test_calculatorAppliesTax() {
        XCTAssertEqual(OrderTotalCalculator(taxRate: 0.18).total(of: order), 236)
    }
    func test_calculatorWithZeroTax() {
        XCTAssertEqual(OrderTotalCalculator(taxRate: 0).total(of: order), 200)
    }
    func test_serviceSavesThenMails() throws {
        let store = SpyStore(), mailer = SpyMailer()
        let svc = OrderService(calculator: .init(taxRate: 0.18), store: store, mailer: mailer)
        let total = try svc.process(order)
        XCTAssertEqual(total, 236)
        XCTAssertEqual(store.saved.count, 1)
        XCTAssertEqual(store.saved.first?.1, 236)
        XCTAssertEqual(mailer.mailed, ["o1"])
    }
    func test_failedSaveAbortsBeforeMail() {
        let store = SpyStore(); store.shouldThrow = true
        let mailer = SpyMailer()
        let svc = OrderService(calculator: .init(taxRate: 0.18), store: store, mailer: mailer)
        XCTAssertThrowsError(try svc.process(order))
        XCTAssertTrue(mailer.mailed.isEmpty)
    }
}

// MARK: - E2 OCP

final class E2OCPTests: XCTestCase {
    func test_noDiscount() {
        XCTAssertEqual(PriceEngine().finalPrice(base: 1000, policies: [NoDiscount()]), 1000)
    }
    func test_percentage() {
        XCTAssertEqual(PriceEngine().finalPrice(base: 1000, policies: [PercentageDiscount(percent: 10)]), 900)
    }
    func test_flatNeverGoesNegative() {
        XCTAssertEqual(PriceEngine().finalPrice(base: 50, policies: [FlatDiscount(amount: 500)]), 0)
    }
    func test_policiesComposeInOrder() {
        let price = PriceEngine().finalPrice(
            base: 1000,
            policies: [PercentageDiscount(percent: 10), FlatDiscount(amount: 100)])
        XCTAssertEqual(price, 800)      // 1000 - 100 = 900, then 900 - 100 = 800
    }
    /// The real OCP test: a policy the engine has never heard of, defined here, must just work.
    func test_engineIsClosedForModification() {
        struct WeekendDoubleDiscount: DiscountPolicy {
            var name: String { "weekend" }
            func discount(on amount: Decimal) -> Decimal { amount / 2 }
        }
        XCTAssertEqual(PriceEngine().finalPrice(base: 400, policies: [WeekendDoubleDiscount()]), 200)
    }
    func test_auditTrail() {
        XCTAssertEqual(
            PriceEngine().auditTrail(policies: [NoDiscount(), PercentageDiscount(percent: 10), FlatDiscount(amount: 100)]),
            ["none", "percent-10", "flat-100"])
    }
}

// MARK: - E3 LSP

final class E3LSPTests: XCTestCase {
    func test_inMemoryReadWrite() throws {
        let s = InMemoryStore()
        s.write("v", key: "k")
        XCTAssertEqual(try s.read(key: "k"), "v")
        XCTAssertEqual(s.keys, ["k"])
    }
    func test_missingKeyThrows() {
        XCTAssertThrowsError(try InMemoryStore().read(key: "nope")) {
            XCTAssertEqual($0 as? StoreError, .missingKey)
        }
    }
    func test_frozenArchiveIsReadable() throws {
        let a = FrozenArchive(["b": "2", "a": "1"])
        XCTAssertEqual(try a.read(key: "a"), "1")
        XCTAssertEqual(a.keys, ["a", "b"])
    }
    /// Substitutability: both readable stores work in the same algorithm, no type checks needed.
    func test_copyFromEitherSource() throws {
        let dest1 = InMemoryStore()
        XCTAssertEqual(try copyAll(from: FrozenArchive(["a": "1", "b": "2"]), to: dest1), 2)
        XCTAssertEqual(dest1.keys, ["a", "b"])

        let source2 = InMemoryStore(["x": "9"])
        let dest2 = InMemoryStore()
        XCTAssertEqual(try copyAll(from: source2, to: dest2), 1)
        XCTAssertEqual(try dest2.read(key: "x"), "9")
    }
}

// MARK: - E4 ISP

final class E4ISPTests: XCTestCase {
    func test_basicPrinterPrints() {
        XCTAssertEqual(BasicPrinter().printDocument("hi"), "printed: hi")
    }
    func test_officeMachineDoesAllThree() {
        let m = OfficeMachine()
        XCTAssertEqual(m.printDocument("hi"), "printed: hi")
        XCTAssertEqual(m.scan(), "scanned page")
        XCTAssertEqual(m.fax("hi", to: "555"), "faxed hi to 555")
    }
    /// The ISP point: printAll accepts the narrow role, so a printer-only device qualifies.
    func test_printAllAcceptsAnyPrinting() {
        XCTAssertEqual(printAll(["a", "b"], on: BasicPrinter()), ["printed: a", "printed: b"])
        XCTAssertEqual(printAll(["a"], on: OfficeMachine()), ["printed: a"])
    }
    func test_emptyBatch() {
        XCTAssertEqual(printAll([], on: BasicPrinter()), [])
    }
}

// MARK: - E5 DIP

final class E5DIPTests: XCTestCase {
    func test_usesInjectedClock() {
        let t = Date(timeIntervalSince1970: 1_000)
        let r = ReportService(clock: FixedClock(date: t), source: DictMetrics(data: ["cpu": [1, 2, 3]]))
            .report(for: "cpu")
        XCTAssertEqual(r.generatedAt, t, "Must use the injected clock, never Date()")
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r.average, 2.0, accuracy: 0.0001)
    }
    func test_unknownKeyIsEmptyReport() {
        let r = ReportService(clock: FixedClock(date: Date(timeIntervalSince1970: 0)),
                              source: DictMetrics(data: [:])).report(for: "nope")
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.average, 0, accuracy: 0.0001)
        XCTAssertEqual(r.key, "nope")
    }
    func test_worksWithADifferentSource() {
        struct AlwaysTen: MetricsSource { func values(for key: String) -> [Double] { [10, 10] } }
        let r = ReportService(clock: FixedClock(date: Date()), source: AlwaysTen()).report(for: "x")
        XCTAssertEqual(r.average, 10, accuracy: 0.0001)
    }
}

// MARK: - E6 classification

final class E6ClassificationTests: XCTestCase {
    func test_mapping() {
        let expected: [Smell: Principle] = [
            .classDoesPersistenceAndBusinessRules: .srp,
            .switchOverTypeTagYouKeepExtending: .ocp,
            .overrideThrowsUnsupported: .lsp,
            .conformanceWithEmptyMethodBodies: .isp,
            .serviceConstructsItsOwnDatabase: .dip,
            .cannotUnitTestWithoutRealClock: .dip,
            .subclassWeakensAPostcondition: .lsp,
            .godClassNamedManager: .srp,
        ]
        for smell in Smell.allCases {
            XCTAssertEqual(principleViolated(by: smell), expected[smell], "wrong principle for \(smell.rawValue)")
        }
    }
}
