//  Module 02 — SOLID exercises.
//
//  BEFORE YOU TYPE: for each exercise, name the PRESSURE before the principle.
//    E1  who would ask for each of these behaviours to change? (different people
//        = different types)
//    E2  can the grader add a policy I have never seen? If my engine needs a
//        switch, it is not closed for modification.
//    E3  is any type about to pretend it can do something it cannot?
//    E4  what does each CALLER actually use? That shapes the protocol, not what
//        the implementer happens to offer.
//    E5  could I test this without a real clock or a real data source?
//
//  Replace every fatalError("TODO"). Signatures are fixed; the grader compiles
//  against them.

import Foundation

// MARK: - E1 (SRP) — split the God class
//  `LegacyOrderProcessor` below is the "before". Don't edit it; build the "after".

public struct Order: Equatable {
    public let id: String
    public let lineTotals: [Decimal]
    public let customerEmail: String
    public init(id: String, lineTotals: [Decimal], customerEmail: String) {
        self.id = id; self.lineTotals = lineTotals; self.customerEmail = customerEmail
    }
}

/// ❌ Four actors, one type. Reference only.
public final class LegacyOrderProcessor {
    public init() {}
    public func process(_ order: Order) -> String {
        let subtotal = order.lineTotals.reduce(0, +)
        let tax = subtotal * Decimal(0.18)
        let total = subtotal + tax
        // persistence + email + receipt rendering all inlined here…
        return "saved \(order.id) total \(total) mailed \(order.customerEmail)"
    }
}

/// ✅ Your job: one responsibility each.
public struct OrderTotalCalculator {
    public let taxRate: Decimal
    public init(taxRate: Decimal) { fatalError("TODO E1a") }
    /// subtotal + subtotal * taxRate
    public func total(of order: Order) -> Decimal { fatalError("TODO E1b") }
}

public protocol OrderStore {
    func save(_ order: Order, total: Decimal) throws
}

public protocol ReceiptMailer {
    func mailReceipt(for order: Order, total: Decimal) throws
}

public struct OrderService {
    private let calculator: OrderTotalCalculator
    private let store: any OrderStore
    private let mailer: any ReceiptMailer

    public init(calculator: OrderTotalCalculator, store: any OrderStore, mailer: any ReceiptMailer) {
        fatalError("TODO E1c")
    }

    /// Compute total → save → mail. Returns the total.
    /// If saving throws, the mail must NOT be sent and the error must propagate.
    @discardableResult
    public func process(_ order: Order) throws -> Decimal { fatalError("TODO E1d") }
}

// MARK: - E2 (OCP) — extension without modification

public protocol DiscountPolicy {
    var name: String { get }
    /// Amount to subtract from `amount` (never negative, never more than `amount`).
    func discount(on amount: Decimal) -> Decimal
}

public struct NoDiscount: DiscountPolicy {
    public init() {}
    public var name: String { fatalError("TODO E2a") }        // "none"
    public func discount(on amount: Decimal) -> Decimal { fatalError("TODO E2a") }
}

public struct PercentageDiscount: DiscountPolicy {
    public let percent: Decimal      // 10 means 10%
    public init(percent: Decimal) { self.percent = percent }
    public var name: String { fatalError("TODO E2b") }        // "percent-10" for 10
    public func discount(on amount: Decimal) -> Decimal { fatalError("TODO E2b") }
}

public struct FlatDiscount: DiscountPolicy {
    public let amount: Decimal
    public init(amount: Decimal) { self.amount = amount }
    public var name: String { fatalError("TODO E2c") }        // "flat-100" for 100
    /// Never discount more than the price itself.
    public func discount(on amount: Decimal) -> Decimal { fatalError("TODO E2c") }
}

public struct PriceEngine {
    public init() {}
    /// Applies every policy in order, each one to the running amount.
    /// Result is never negative. Must contain NO switch/if over policy types.
    public func finalPrice(base: Decimal, policies: [any DiscountPolicy]) -> Decimal {
        fatalError("TODO E2d")
    }
    /// Names of the applied policies, in order.
    public func auditTrail(policies: [any DiscountPolicy]) -> [String] { fatalError("TODO E2e") }
}

// MARK: - E3 (LSP) — repair the hierarchy
//  A read-only store must not pretend to be writable and throw at runtime.

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
    public func read(key: String) throws -> String { fatalError("TODO E3a") }
    public var keys: [String] { fatalError("TODO E3a") }      // sorted
    public func write(_ value: String, key: String) { fatalError("TODO E3a") }
}

/// Conforms ONLY to ReadableStore — it never needs a throwing `write` stub.
public struct FrozenArchive: ReadableStore {
    private let storage: [String: String]
    public init(_ initial: [String: String]) { self.storage = initial }
    public func read(key: String) throws -> String { fatalError("TODO E3b") }
    public var keys: [String] { fatalError("TODO E3b") }      // sorted
}

/// Copies every key from any readable source into any writable destination.
/// Returns the number of keys copied.
@discardableResult
public func copyAll(from source: any ReadableStore, to destination: any WritableStore) throws -> Int {
    fatalError("TODO E3c")
}

// MARK: - E4 (ISP) — split the fat protocol

public protocol Printing { func printDocument(_ text: String) -> String }
public protocol Scanning { func scan() -> String }
public protocol Faxing   { func fax(_ text: String, to number: String) -> String }

/// Only prints. Must not carry scan/fax stubs.
public struct BasicPrinter: Printing {
    public init() {}
    public func printDocument(_ text: String) -> String { fatalError("TODO E4a") }  // "printed: <text>"
}

public struct OfficeMachine: Printing, Scanning, Faxing {
    public init() {}
    public func printDocument(_ text: String) -> String { fatalError("TODO E4b") }  // "printed: <text>"
    public func scan() -> String { fatalError("TODO E4b") }                          // "scanned page"
    public func fax(_ text: String, to number: String) -> String { fatalError("TODO E4b") } // "faxed <text> to <number>"
}

/// Depends on the narrowest protocol it needs.
public func printAll(_ documents: [String], on device: any Printing) -> [String] {
    fatalError("TODO E4c")
}

// MARK: - E5 (DIP) — invert the dependencies

public protocol Clock {
    func now() -> Date
}

public protocol MetricsSource {
    /// Values recorded for a metric key; empty if unknown.
    func values(for key: String) -> [Double]
}

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
    /// Must never call Date() or construct a concrete source.
    public init(clock: any Clock, source: any MetricsSource) { fatalError("TODO E5a") }

    /// average is 0 when there are no values.
    public func report(for key: String) -> MetricsReport { fatalError("TODO E5b") }
}

// MARK: - E6 — smell classification (knowledge check)

public enum Principle: String, Equatable, CaseIterable {
    case srp, ocp, lsp, isp, dip
}

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

/// Map each smell to the principle it most directly violates.
public func principleViolated(by smell: Smell) -> Principle { fatalError("TODO E6") }
