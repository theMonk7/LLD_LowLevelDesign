//  Module 02 reference solutions.
//
//  HOW TO READ THIS FILE
//  Each `// WHY` block names the PRESSURE the code is relieving, not the letter of
//  the principle. If you can restate the pressure in your own words, the letter is
//  a label you no longer need to memorise.
//
//  Not part of the M02 target.

import Foundation

// MARK: - E1

public struct Order: Equatable {
    public let id: String
    public let lineTotals: [Decimal]
    public let customerEmail: String
    public init(id: String, lineTotals: [Decimal], customerEmail: String) {
        self.id = id; self.lineTotals = lineTotals; self.customerEmail = customerEmail
    }
}

public struct OrderTotalCalculator {
    public let taxRate: Decimal
    public init(taxRate: Decimal) { self.taxRate = taxRate }
    public func total(of order: Order) -> Decimal {
        let subtotal = order.lineTotals.reduce(0, +)
        return subtotal + subtotal * taxRate
    }
}

public protocol OrderStore { func save(_ order: Order, total: Decimal) throws }
public protocol ReceiptMailer { func mailReceipt(for order: Order, total: Decimal) throws }

// WHY is this type allowed to exist at all, if SRP says "one responsibility"?
// Because ORCHESTRATION is a responsibility. Its one reason to change is
// "the registration/checkout workflow changed" — a real actor, the product team.
// What it must NOT contain is tax rules (finance), SQL (infrastructure) or
// email copy (marketing). Those are three other actors, and they are elsewhere.
//
// Notice the payoff: `process` is four lines. Orchestration code becomes boring
// once the knowledge has moved to where it belongs, and boring code is correct.
public struct OrderService {
    private let calculator: OrderTotalCalculator
    private let store: any OrderStore
    private let mailer: any ReceiptMailer

    public init(calculator: OrderTotalCalculator, store: any OrderStore, mailer: any ReceiptMailer) {
        self.calculator = calculator; self.store = store; self.mailer = mailer
    }

    @discardableResult
    public func process(_ order: Order) throws -> Decimal {
        let total = calculator.total(of: order)
        try store.save(order, total: total)
        try mailer.mailReceipt(for: order, total: total)
        return total
    }
}

// MARK: - E2

public protocol DiscountPolicy {
    var name: String { get }
    func discount(on amount: Decimal) -> Decimal
}

public struct NoDiscount: DiscountPolicy {
    public init() {}
    public var name: String { "none" }
    public func discount(on amount: Decimal) -> Decimal { 0 }
}

public struct PercentageDiscount: DiscountPolicy {
    public let percent: Decimal
    public init(percent: Decimal) { self.percent = percent }
    public var name: String { "percent-\(percent)" }
    public func discount(on amount: Decimal) -> Decimal { amount * percent / 100 }
}

public struct FlatDiscount: DiscountPolicy {
    public let amount: Decimal
    public init(amount: Decimal) { self.amount = amount }
    public var name: String { "flat-\(amount)" }
    public func discount(on price: Decimal) -> Decimal { min(amount, price) }
}

public struct PriceEngine {
    public init() {}
    // WHY no switch, no `if policy is PercentageDiscount`?
    // Because the grader defines a policy type this engine has never seen and
    // expects it to work. That is what "closed for modification" means, tested.
    //
    // Two decisions worth defending out loud:
    //  1. We fold over the RUNNING amount, so order matters. A different business
    //     might want every discount computed on the base. That is a product
    //     question — ask it.
    //  2. We clamp at 0 inside the fold, not only at the end, so every
    //     intermediate value is legal too.
    public func finalPrice(base: Decimal, policies: [any DiscountPolicy]) -> Decimal {
        let result = policies.reduce(base) { running, policy in
            max(0, running - policy.discount(on: running))
        }
        return max(0, result)
    }
    public func auditTrail(policies: [any DiscountPolicy]) -> [String] { policies.map(\.name) }
}

// MARK: - E3

public enum StoreError: Error, Equatable { case missingKey }

public protocol ReadableStore {
    func read(key: String) throws -> String
    var keys: [String] { get }
}
public protocol WritableStore: ReadableStore {
    func write(_ value: String, key: String)
}

public final class InMemoryStore: WritableStore {
    private var storage: [String: String]
    public init(_ initial: [String: String] = [:]) { self.storage = initial }
    public func read(key: String) throws -> String {
        guard let v = storage[key] else { throw StoreError.missingKey }
        return v
    }
    public var keys: [String] { storage.keys.sorted() }
    public func write(_ value: String, key: String) { storage[key] = value }
}

// WHY is this the LSP fix, when the obvious fix is a `write` that throws?
// Because a throwing `write` forces every caller to know which implementation it
// got — which destroys the point of having an abstraction. Here the type system
// says "this cannot write", so `copyAll` can demand a WritableStore destination
// and the compiler guarantees it. The runtime "unsupported" branch does not
// exist to be tested, because it cannot be constructed.
//
// Note also that WritableStore only ADDS capability to ReadableStore. Protocol
// hierarchies are safe when subtypes widen the contract; trouble starts the
// moment one narrows it.
public struct FrozenArchive: ReadableStore {
    private let storage: [String: String]
    public init(_ initial: [String: String]) { self.storage = initial }
    public func read(key: String) throws -> String {
        guard let v = storage[key] else { throw StoreError.missingKey }
        return v
    }
    public var keys: [String] { storage.keys.sorted() }
}

@discardableResult
public func copyAll(from source: any ReadableStore, to destination: any WritableStore) throws -> Int {
    for key in source.keys { destination.write(try source.read(key: key), key: key) }
    return source.keys.count
}

// MARK: - E4

public protocol Printing { func printDocument(_ text: String) -> String }
public protocol Scanning { func scan() -> String }
public protocol Faxing   { func fax(_ text: String, to number: String) -> String }

public struct BasicPrinter: Printing {
    public init() {}
    public func printDocument(_ text: String) -> String { "printed: \(text)" }
}

public struct OfficeMachine: Printing, Scanning, Faxing {
    public init() {}
    public func printDocument(_ text: String) -> String { "printed: \(text)" }
    public func scan() -> String { "scanned page" }
    public func fax(_ text: String, to number: String) -> String { "faxed \(text) to \(number)" }
}

// The signature IS the lesson: depend on the narrowest role that does the job.
// This works with a cheap printer and with a full office machine, because it asks
// for neither — it asks for `Printing`. Had `Printing` also demanded scan() and
// fax(), BasicPrinter would need two meaningless stubs, and every empty method
// body is the compiler telling you the protocol is too wide.
public func printAll(_ documents: [String], on device: any Printing) -> [String] {
    documents.map { device.printDocument($0) }
}

// MARK: - E5

public protocol Clock { func now() -> Date }
public protocol MetricsSource { func values(for key: String) -> [Double] }

public struct MetricsReport: Equatable {
    public let key: String
    public let count: Int
    public let average: Double
    public let generatedAt: Date
    public init(key: String, count: Int, average: Double, generatedAt: Date) {
        self.key = key; self.count = count; self.average = average; self.generatedAt = generatedAt
    }
}

public struct ReportService {
    private let clock: any Clock
    private let source: any MetricsSource
    // Two dependencies, both inverted, both arriving through init. The grader's
    // FixedClock is the proof: time became a VALUE instead of an ambient global,
    // so a report's timestamp is now testable.
    //
    // `Clock` is the protocol most codebases are missing. Anything that reaches
    // for the current time, a random number, a UUID or a shared URLSession deep
    // inside domain logic is untestable for exactly the same reason.
    public init(clock: any Clock, source: any MetricsSource) { self.clock = clock; self.source = source }

    public func report(for key: String) -> MetricsReport {
        let values = source.values(for: key)
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return MetricsReport(key: key, count: values.count, average: average, generatedAt: clock.now())
    }
}

// MARK: - E6

public enum Principle: String, Equatable, CaseIterable { case srp, ocp, lsp, isp, dip }

public enum Smell: String, Equatable, CaseIterable {
    case classDoesPersistenceAndBusinessRules
    case switchOverTypeTagYouKeepExtending
    case overrideThrowsUnsupported
    case conformanceWithEmptyMethodBodies
    case serviceConstructsItsOwnDatabase
    case cannotUnitTestWithoutRealClock
    case subclassWeakensAPostcondition
    case godClassNamedManager
}

public func principleViolated(by smell: Smell) -> Principle {
    switch smell {
    case .classDoesPersistenceAndBusinessRules: .srp
    case .switchOverTypeTagYouKeepExtending:    .ocp
    case .overrideThrowsUnsupported:            .lsp
    case .conformanceWithEmptyMethodBodies:     .isp
    case .serviceConstructsItsOwnDatabase:      .dip
    case .cannotUnitTestWithoutRealClock:       .dip
    case .subclassWeakensAPostcondition:        .lsp
    case .godClassNamedManager:                 .srp
    }
}
