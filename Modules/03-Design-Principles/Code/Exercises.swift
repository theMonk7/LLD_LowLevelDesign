//  Module 03 — Design principle exercises.
//
//  BEFORE YOU TYPE: this module is about HOW MUCH structure, so for each exercise
//  ask the restraint questions too:
//    E1  is this the SAME knowledge in two places, or two things that merely look
//        alike today?
//    E2  what is the simplest thing that works — and what is the "enterprise"
//        version I am deliberately not building?
//    E3  which of these forwarding methods actually cross a boundary that will
//        change?
//    E4  am I about to read a property, decide, and write it back? Move the
//        decision to the type that owns the data.
//    E5  what varies, and what stays the same? Separate exactly those two.
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 (DRY) — one authoritative representation of a rule

public struct Username: Equatable {
    public let value: String
    /// Valid: 3...20 characters, letters or digits only, must start with a letter.
    /// Invalid input returns nil. This initialiser is the ONLY place the rule may live.
    public init?(_ raw: String) { fatalError("TODO E1a") }
}

public struct SignupForm {
    public init() {}
    /// Uses Username — must not re-implement any part of the rule.
    public func validate(username raw: String) -> Bool { fatalError("TODO E1b") }
}

public struct AdminImporter {
    public init() {}
    /// Returns only the valid usernames, in input order. Must not re-implement the rule.
    public func importUsers(_ raws: [String]) -> [Username] { fatalError("TODO E1c") }
}

// MARK: - E2 (KISS) — the simplest thing that works
//  There is no framework to build here. Solve it directly; the commentary explains why
//  the "enterprise" version in SOLUTIONS.md is worse.

public enum TemperatureScale: String, CaseIterable { case celsius, fahrenheit, kelvin }

/// Converts between scales. Expected to stay a closed set of three.
public func convert(_ value: Double, from: TemperatureScale, to: TemperatureScale) -> Double {
    fatalError("TODO E2")
}

// MARK: - E3 (Law of Demeter) — stop the train wreck
//  Each type must answer only for what it owns. No caller may write `order.customer.address.city.name`.

public struct City {
    public let name: String
    public init(name: String) { self.name = name }
    public var displayName: String { fatalError("TODO E3a") }
}

public struct Address {
    public let line1: String
    public let city: City
    public init(line1: String, city: City) { self.line1 = line1; self.city = city }
    public var cityName: String { fatalError("TODO E3b") }
}

public struct Customer {
    public let name: String
    public let address: Address
    public init(name: String, address: Address) { self.name = name; self.address = address }
    public var cityName: String { fatalError("TODO E3c") }
}

public struct Shipment {
    public let customer: Customer
    public init(customer: Customer) { self.customer = customer }
    /// Must reach no further than `customer`.
    public var destinationCity: String { fatalError("TODO E3d") }
    /// "<customer name> → <city>"
    public var label: String { fatalError("TODO E3e") }
}

// MARK: - E4 (Tell, Don't Ask + Information Expert) — put behaviour where the data is

public struct CartItem: Equatable {
    public let sku: String
    public let unitPrice: Decimal
    public let quantity: Int
    public init(sku: String, unitPrice: Decimal, quantity: Int) {
        self.sku = sku; self.unitPrice = unitPrice; self.quantity = quantity
    }
    /// unitPrice * quantity — the item is the information expert for its own subtotal.
    public var subtotal: Decimal { fatalError("TODO E4a") }
}

public enum CartError: Error, Equatable { case emptyCart, itemNotFound }

public struct Cart {
    public private(set) var items: [CartItem]
    public init(items: [CartItem] = []) { self.items = items }

    /// Sum of item subtotals.
    public var total: Decimal { fatalError("TODO E4b") }

    /// Adds the item; if the sku already exists, merges by summing quantities
    /// (the merged item keeps the FIRST unit price).
    public mutating func add(_ item: CartItem) { fatalError("TODO E4c") }

    /// Removes the sku. Throws .itemNotFound if absent.
    public mutating func remove(sku: String) throws { fatalError("TODO E4d") }

    /// Tell, don't ask: the cart decides, the caller does not inspect `total` first.
    /// Free shipping when total >= threshold; otherwise `fee`. Throws .emptyCart when empty.
    public func shippingCost(freeOver threshold: Decimal, otherwise fee: Decimal) throws -> Decimal {
        fatalError("TODO E4e")
    }
}

// MARK: - E5 (Encapsulate what varies) — isolate the changing rule

public protocol PasswordRule {
    var describe: String { get }
    func isSatisfied(by password: String) -> Bool
}

public struct MinLengthRule: PasswordRule {
    public let min: Int
    public init(min: Int) { self.min = min }
    public var describe: String { fatalError("TODO E5a") }          // "min-<n>"
    public func isSatisfied(by password: String) -> Bool { fatalError("TODO E5a") }
}

public struct ContainsDigitRule: PasswordRule {
    public init() {}
    public var describe: String { fatalError("TODO E5b") }          // "digit"
    public func isSatisfied(by password: String) -> Bool { fatalError("TODO E5b") }
}

public struct NotInDenylistRule: PasswordRule {
    public let denylist: Set<String>
    public init(denylist: Set<String>) { self.denylist = denylist }
    public var describe: String { fatalError("TODO E5c") }          // "denylist"
    /// Case-insensitive comparison.
    public func isSatisfied(by password: String) -> Bool { fatalError("TODO E5c") }
}

public struct PasswordPolicy {
    private let rules: [any PasswordRule]
    public init(rules: [any PasswordRule]) { fatalError("TODO E5d") }
    /// Descriptions of every rule the password FAILS, in rule order. Empty means valid.
    public func failures(for password: String) -> [String] { fatalError("TODO E5e") }
    public func isValid(_ password: String) -> Bool { fatalError("TODO E5f") }
}

// MARK: - E6 — principle classification (knowledge check)

public enum DesignPrinciple: String, Equatable, CaseIterable {
    case dry, kiss, yagni, demeter, tellDontAsk, informationExpert, pureFabrication, hollywood
}

public enum Situation: String, Equatable, CaseIterable {
    case sameValidationRuleCopiedIntoThreeScreens
    case protocolWithOneConformerAndNoTestDouble
    case configFlagsForFeaturesNobodyRequested
    case callerWritesOrderCustomerAddressCityName
    case callerReadsBalanceBranchesThenWritesItBack
    case serviceComputesCartTotalFromCartItems
    case needAnOrderRepositoryWhichIsNoDomainNoun
    case frameworkCallsYourViewDidLoad
}

public func principle(for situation: Situation) -> DesignPrinciple { fatalError("TODO E6") }
