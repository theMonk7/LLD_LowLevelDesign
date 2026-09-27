//  ExercisesSolution.swift — Module 01 reference solutions.
//
//  HOW TO READ THIS FILE
//  Do not read it as code to copy. Read each `// WHY` block first, then the few
//  lines under it. The code is short everywhere; the reasoning is the content.
//  Every comment here answers one of three questions:
//    - why is the rule in THIS type rather than in the caller?
//    - why is this a struct / a class / a protocol?
//    - what breaks if you write the obvious alternative?
//
//  NOT part of the M01 target (the package compiles Code/ only), so nothing here
//  can leak into your own answers.

import Foundation

// MARK: - E1

public struct Money: Equatable {
    public let amount: Decimal
    public let currency: String

    // WHY a failable init rather than a `validate()` method?
    // Because `validate()` can be forgotten. A failable initialiser makes
    // "an invalid Money value does not exist" true at runtime, everywhere,
    // forever. The type carries proof; callers don't have to be careful.
    public init?(amount: Decimal, currency: String) {
        guard amount >= 0 else { return nil }
        guard currency.count == 3,
              currency.allSatisfy({ $0.isUppercase && $0.isLetter }) else { return nil }
        self.amount = amount
        self.currency = currency
    }

    public enum MoneyError: Error, Equatable { case currencyMismatch }

    public static func add(_ lhs: Money, _ rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else { throw MoneyError.currencyMismatch }
        // The force-unwrap is safe BY CONSTRUCTION, not by luck: both amounts are
        // already non-negative and the currency already passed validation, so the
        // initialiser cannot fail here. Say this out loud in an interview rather
        // than adding a meaningless `guard let` that pretends to handle a case
        // that cannot occur.
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)!
    }
}

// MARK: - E2

public enum AccountError: Error, Equatable {
    case nonPositiveAmount
    case insufficientFunds
}

public final class BankAccount {
    public private(set) var balance: Decimal
    public private(set) var history: [Decimal] = []

    public init(opening: Decimal) { self.balance = opening }

    public func deposit(_ amount: Decimal) throws {
        guard amount > 0 else { throw AccountError.nonPositiveAmount }
        balance += amount
        history.append(amount)
    }

    // WHY validate-then-mutate?
    // Every `throw` happens BEFORE any assignment, so a rejected withdrawal leaves
    // the object byte-identical to how it started. No rollback logic is needed,
    // because nothing was applied. Reverse the order and you need compensation —
    // which is where real bugs live. This ordering habit scales all the way up to
    // the multi-field commits in Modules 10 and 12.
    public func withdraw(_ amount: Decimal) throws {
        guard amount > 0 else { throw AccountError.nonPositiveAmount }
        guard amount <= balance else { throw AccountError.insufficientFunds }
        balance -= amount
        history.append(-amount)
    }
}

// MARK: - E3

public protocol Shape {
    func area() -> Double
    var name: String { get }
}

public struct Circle: Shape {
    public let radius: Double
    public init(radius: Double) { self.radius = radius }
    public func area() -> Double { .pi * radius * radius }
    public var name: String { "Circle" }
}

public struct Rectangle: Shape {
    public let width: Double, height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public func area() -> Double { width * height }
    public var name: String { "Rectangle" }
}

public struct Triangle: Shape {
    public let base: Double, height: Double
    public init(base: Double, height: Double) { self.base = base; self.height = height }
    public func area() -> Double { 0.5 * base * height }
    public var name: String { "Triangle" }
}

// WHY `[any Shape]` and not a generic `[S: Shape]`?
// A generic parameter gives a HOMOGENEOUS collection — all circles, or all
// rectangles. The whole point here is a mixed bag, which needs an existential:
// each element is boxed and dispatched dynamically. Slightly slower, and the
// only thing that models the requirement.
//
// Notice what is absent: no `if shape is Circle`. That absence is polymorphism
// doing its job — adding Hexagon is one new file and zero edits here.
public func totalArea(_ shapes: [any Shape]) -> Double {
    shapes.reduce(0) { $0 + $1.area() }
}

public func namesOfShapesLarger(than threshold: Double, in shapes: [any Shape]) -> [String] {
    shapes.filter { $0.area() > threshold }.map(\.name)
}

// MARK: - E4

public protocol Channel {
    var id: String { get }
    func deliver(_ message: String)
}

public struct Notifier {
    private let channels: [any Channel]
    public init(channels: [any Channel]) { self.channels = channels }
    public func send(_ message: String) { channels.forEach { $0.deliver(message) } }
    // WHY return a new Notifier instead of a `mutating func add`?
    // Both are defensible. Returning a value keeps the type safe to share across
    // threads and supports chaining; mutating is cheaper for large collections.
    // The point is that this is a TRADE-OFF you state, not a default you inherit.
    public func adding(_ channel: any Channel) -> Notifier { Notifier(channels: channels + [channel]) }
}

// MARK: - E5

// WHY does `add` need `mutating` here but not on the class below?
// A value type's method cannot change `self` unless it says so — the compiler is
// forcing you to notice that mutating a value affects only THIS copy. On the
// class, the reference is constant but the instance's storage is not, so
// `let s = SharedPlaylist(); s.add("x")` compiles. That asymmetry is the exact
// thing that makes `for spot in spots { spot.occupy() }` silently do nothing
// when `spots` holds structs.
public struct Playlist: Equatable {
    public private(set) var songs: [String]
    public init(songs: [String] = []) { self.songs = songs }
    public mutating func add(_ song: String) { songs.append(song) }
}

public final class SharedPlaylist {
    public private(set) var songs: [String]
    public init(songs: [String] = []) { self.songs = songs }
    public func add(_ song: String) { songs.append(song) }
    public func copy() -> SharedPlaylist { SharedPlaylist(songs: songs) }
}

// MARK: - E6

public protocol Vehicle {
    var name: String { get }
    var wheels: Int { get }
    func honk() -> String
}

public extension Vehicle {
    // `honk()` is DECLARED in the protocol above, so conformers land in the
    // witness table and `Truck`'s override wins even through `any Vehicle`.
    // `summary` is extension-only, so it is statically dispatched and cannot be
    // overridden — which is correct here, because it is derived from `name` and
    // `wheels` and nobody should be changing it.
    //
    // Delete `func honk() -> String` from the protocol body and the array test
    // silently prints ["beep", "beep"]. No warning. That is the single most
    // surprising thing about Swift protocols.
    func honk() -> String { "beep" }
    var summary: String { "\(name) with \(wheels) wheels" }
}

public struct Bike: Vehicle {
    public init() {}
    public var name: String { "Bike" }
    public var wheels: Int { 2 }
}

public struct Truck: Vehicle {
    public init() {}
    public var name: String { "Truck" }
    public var wheels: Int { 6 }
    public func honk() -> String { "HOOONK" }
}

// MARK: - E7

public protocol PriceFeed {
    func price(for ticker: String) -> Decimal?
}

public struct Holding {
    public let ticker: String
    public let quantity: Int
    public init(ticker: String, quantity: Int) { self.ticker = ticker; self.quantity = quantity }
}

public struct PortfolioService {
    private let feed: any PriceFeed
    public init(feed: any PriceFeed) { self.feed = feed }

    // WHY skip unknown tickers instead of throwing?
    // Because the SPEC said so — and that is the real lesson. "Unknown ticker"
    // is a product decision (skip / throw / treat as zero / return partial with
    // warnings), not a coding decision. In an interview, ask.
    public func totalValue(of holdings: [Holding]) -> Decimal {
        holdings.reduce(0) { running, holding in
            guard let unit = feed.price(for: holding.ticker) else { return running }
            return running + unit * Decimal(holding.quantity)
        }
    }

    public func unpricedTickers(in holdings: [Holding]) -> [String] {
        holdings.filter { feed.price(for: $0.ticker) == nil }.map(\.ticker)
    }
}

// MARK: - E8

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

public struct UserService {
    private let repository: any UserRepository
    private let mailer: any Mailer

    public init(repository: any UserRepository, mailer: any Mailer) {
        self.repository = repository
        self.mailer = mailer
    }

    // Four lines, four responsibilities — and this type owns NONE of them.
    // It validates and sequences; persistence lives behind UserRepository and
    // messaging behind Mailer. Its one reason to change is "the registration
    // workflow changed", which is exactly what high cohesion means.
    //
    // Note `try`, not `try?`. `try?` would swallow a database failure and then
    // cheerfully send a welcome email for a user who was never saved. Silent
    // failure is a design bug, not a style preference.
    public func register(_ user: User) throws {
        guard user.email.contains("@") else { throw RegistrationError.invalidEmail }
        guard !repository.exists(email: user.email) else { throw RegistrationError.duplicateEmail }
        try repository.save(user)
        try mailer.sendWelcome(to: user)
    }
}
