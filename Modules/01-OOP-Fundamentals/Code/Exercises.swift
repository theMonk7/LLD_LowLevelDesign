//  Exercises.swift — Module 01
//
//  BEFORE YOU TYPE ANYTHING, for each exercise ask:
//    1. Is this a VALUE or an ENTITY?  (two with identical fields: same thing, or
//       two different things?)  That answers struct vs class.
//    2. What does this type PROMISE?   That is the invariant, and it tells you
//       what must be private and where validation goes.
//    3. If a caller could set this field directly, what nonsense could they make?
//    4. Which rule am I about to put in the caller that belongs in the type?
//
//  Fill in every `fatalError("TODO")`. Do not change the public signatures: the
//  grader in ../Tests compiles against them.  Run:  swift test --filter M01

import Foundation

// MARK: - E1. Value type with invariants  (Encapsulation + value semantics)

public struct Money: Equatable {
    public let amount: Decimal
    public let currency: String

    /// Returns nil if `amount` is negative or `currency` is not a 3-letter uppercase code.
    public init?(amount: Decimal, currency: String) {
        fatalError("TODO E1a")
    }

    public enum MoneyError: Error, Equatable { case currencyMismatch }

    /// Adds two Money values. Throws `MoneyError.currencyMismatch` for different currencies.
    public static func add(_ lhs: Money, _ rhs: Money) throws -> Money {
        fatalError("TODO E1b")
    }
}

// MARK: - E2. Encapsulation with enforced invariants

public enum AccountError: Error, Equatable {
    case nonPositiveAmount
    case insufficientFunds
}

public final class BankAccount {
    /// Readable from outside, writable only from inside.
    public private(set) var balance: Decimal
    /// Every successful deposit/withdrawal is appended: +amount for deposit, -amount for withdrawal.
    public private(set) var history: [Decimal] = []

    public init(opening: Decimal) {
        fatalError("TODO E2a")
    }

    public func deposit(_ amount: Decimal) throws {
        fatalError("TODO E2b")
    }

    /// Must never allow the balance to go negative.
    public func withdraw(_ amount: Decimal) throws {
        fatalError("TODO E2c")
    }
}

// MARK: - E3. Abstraction + polymorphism

public protocol Shape {
    func area() -> Double
    /// Human-readable name, e.g. "Circle".
    var name: String { get }
}

public struct Circle: Shape {
    public let radius: Double
    public init(radius: Double) { self.radius = radius }
    public func area() -> Double { fatalError("TODO E3a") }
    public var name: String { fatalError("TODO E3a") }
}

public struct Rectangle: Shape {
    public let width: Double, height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public func area() -> Double { fatalError("TODO E3b") }
    public var name: String { fatalError("TODO E3b") }
}

public struct Triangle: Shape {
    public let base: Double, height: Double
    public init(base: Double, height: Double) { self.base = base; self.height = height }
    public func area() -> Double { fatalError("TODO E3c") }
    public var name: String { fatalError("TODO E3c") }
}

/// Sum of all areas. Must work on a heterogeneous array — do not use generics.
public func totalArea(_ shapes: [any Shape]) -> Double {
    fatalError("TODO E3d")
}

/// Names of shapes whose area is strictly greater than `threshold`, in input order.
public func namesOfShapesLarger(than threshold: Double, in shapes: [any Shape]) -> [String] {
    fatalError("TODO E3e")
}

// MARK: - E4. Composition over inheritance

public protocol Channel {
    var id: String { get }
    func deliver(_ message: String)
}

public struct Notifier {
    private let channels: [any Channel]
    public init(channels: [any Channel]) {
        fatalError("TODO E4a")
    }
    /// Delivers `message` to every channel, in the order they were supplied.
    public func send(_ message: String) {
        fatalError("TODO E4b")
    }
    /// A new Notifier with `channel` appended. Must not mutate the receiver.
    public func adding(_ channel: any Channel) -> Notifier {
        fatalError("TODO E4c")
    }
}

// MARK: - E5. Value vs reference semantics

/// A value type: copies must be fully independent.
public struct Playlist: Equatable {
    public private(set) var songs: [String]
    public init(songs: [String] = []) { self.songs = songs }
    public mutating func add(_ song: String) { fatalError("TODO E5a") }
}

/// A reference type: two variables pointing at one instance must see each other's changes.
public final class SharedPlaylist {
    public private(set) var songs: [String]
    public init(songs: [String] = []) { self.songs = songs }
    public func add(_ song: String) { fatalError("TODO E5b") }
    /// Returns a NEW instance with the same contents (defensive copy).
    public func copy() -> SharedPlaylist { fatalError("TODO E5c") }
}

// MARK: - E6. Protocol + extension as Swift's "abstract class"

public protocol Vehicle {
    var name: String { get }
    var wheels: Int { get }
    /// Declared here (not only in the extension) so conformers can override it dynamically.
    func honk() -> String
}

public extension Vehicle {
    /// Default implementation shared by all vehicles unless overridden.
    func honk() -> String { "beep" }
    /// e.g. "Bike with 2 wheels"
    var summary: String { fatalError("TODO E6a") }
}

public struct Bike: Vehicle {
    public init() {}
    public var name: String { fatalError("TODO E6b") }   // "Bike"
    public var wheels: Int { fatalError("TODO E6b") }    // 2
}

public struct Truck: Vehicle {
    public init() {}
    public var name: String { fatalError("TODO E6c") }   // "Truck"
    public var wheels: Int { fatalError("TODO E6c") }    // 6
    /// Trucks override the default horn with "HOOONK".
    public func honk() -> String { fatalError("TODO E6c") }
}

// MARK: - E7. Low coupling via dependency injection

public protocol PriceFeed {
    /// Price per unit for a ticker, or nil if unknown.
    func price(for ticker: String) -> Decimal?
}

public struct Holding {
    public let ticker: String
    public let quantity: Int
    public init(ticker: String, quantity: Int) { self.ticker = ticker; self.quantity = quantity }
}

public struct PortfolioService {
    private let feed: any PriceFeed
    /// Must depend on the abstraction, never construct a concrete feed inside.
    public init(feed: any PriceFeed) { fatalError("TODO E7a") }

    /// Total value of holdings. Holdings with an unknown ticker are skipped.
    public func totalValue(of holdings: [Holding]) -> Decimal { fatalError("TODO E7b") }

    /// Tickers the feed could not price, in input order.
    public func unpricedTickers(in holdings: [Holding]) -> [String] { fatalError("TODO E7c") }
}

// MARK: - E8. High cohesion: split the God class

public struct User: Equatable {
    public let id: String
    public let email: String
    public init(id: String, email: String) { self.id = id; self.email = email }
}

public protocol UserRepository {
    func save(_ user: User) throws
    func exists(email: String) -> Bool
}

public protocol Mailer {
    func sendWelcome(to user: User) throws
}

public enum RegistrationError: Error, Equatable {
    case invalidEmail
    case duplicateEmail
}

/// Orchestration only: validate → check duplicate → save → mail.
/// Must own NO persistence and NO mail logic itself.
public struct UserService {
    private let repository: any UserRepository
    private let mailer: any Mailer

    public init(repository: any UserRepository, mailer: any Mailer) {
        fatalError("TODO E8a")
    }

    /// Rules, in this exact order:
    ///  1. email must contain "@"      → RegistrationError.invalidEmail
    ///  2. repository.exists(email:)   → RegistrationError.duplicateEmail
    ///  3. repository.save(user)       (if it throws, the mail must NOT be sent)
    ///  4. mailer.sendWelcome(to:)
    public func register(_ user: User) throws {
        fatalError("TODO E8b")
    }
}
