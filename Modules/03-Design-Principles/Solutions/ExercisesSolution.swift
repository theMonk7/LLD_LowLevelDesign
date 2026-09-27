//  Module 03 reference solutions.
//
//  HOW TO READ THIS FILE
//  This module is about JUDGMENT, so the comments mostly answer "why is this
//  amount of structure right?" — including two places where the answer is
//  "less than you expected". Watch for the two deliberate refusals to abstract.
//
//  Not part of the M03 target.

import Foundation

// MARK: - E1

// WHY a TYPE rather than a shared `isValidUsername(_:)` function?
// Both remove the duplication. Only one of them removes the possibility of
// forgetting: a shared function can be skipped, but a `Username` value CANNOT
// EXIST unless the rule passed. The type carries proof, and every function that
// takes a `Username` gets that proof for free.
//
// This is DRY applied through the type system rather than through code reuse —
// the strongest form available.
public struct Username: Equatable {
    public let value: String
    public init?(_ raw: String) {
        guard (3...20).contains(raw.count),
              raw.allSatisfy({ $0.isLetter || $0.isNumber }),
              raw.first?.isLetter == true
        else { return nil }
        self.value = raw
    }
}

public struct SignupForm {
    public init() {}
    public func validate(username raw: String) -> Bool { Username(raw) != nil }
}

public struct AdminImporter {
    public init() {}
    public func importUsers(_ raws: [String]) -> [Username] { raws.compactMap(Username.init) }
}

// MARK: - E2

public enum TemperatureScale: String, CaseIterable { case celsius, fahrenheit, kelvin }

// WHY a switch, when Module 02 spent a page attacking switches?
// Because OCP is about sets that GROW. There have been three temperature scales
// since 1848. The set is closed, so the exhaustive switch is a feature: add a
// scale and the compiler names both places to edit.
//
// Also note the shape — normalise through one pivot scale, so each new scale
// costs TWO cases instead of 2N pairwise conversions. Nine cases become six lines.
// The "enterprise" version (a converter protocol plus a registry) is not wrong,
// it is unpaid-for.
public func convert(_ value: Double, from: TemperatureScale, to: TemperatureScale) -> Double {
    // Normalise to celsius, then out. Two small steps beat nine pairwise cases.
    let celsius: Double
    switch from {
    case .celsius:    celsius = value
    case .fahrenheit: celsius = (value - 32) * 5 / 9
    case .kelvin:     celsius = value - 273.15
    }
    switch to {
    case .celsius:    return celsius
    case .fahrenheit: return celsius * 9 / 5 + 32
    case .kelvin:     return celsius + 273.15
    }
}

// MARK: - E3

public struct City {
    public let name: String
    public init(name: String) { self.name = name }
    public var displayName: String { name }
}

public struct Address {
    public let line1: String
    public let city: City
    public init(line1: String, city: City) { self.line1 = line1; self.city = city }
    public var cityName: String { city.displayName }
}

public struct Customer {
    public let name: String
    public let address: Address
    public init(name: String, address: Address) { self.name = name; self.address = address }
    public var cityName: String { address.cityName }
}

// Four one-line accessors exist so that `Shipment` depends on `Customer` only.
// Rename City.name and exactly one file changes.
//
// Be honest about the cost: you wrote four methods to avoid one expression.
// Applied everywhere this is "Demeter bloat". Apply it where the chain crosses a
// boundary you expect to change — and always where you would otherwise MUTATE
// through it, because `order.customer.wallet.balance -= x` bypasses every
// invariant Wallet has.
public struct Shipment {
    public let customer: Customer
    public init(customer: Customer) { self.customer = customer }
    public var destinationCity: String { customer.cityName }
    public var label: String { "\(customer.name) → \(destinationCity)" }
}

// MARK: - E4

public struct CartItem: Equatable {
    public let sku: String
    public let unitPrice: Decimal
    public let quantity: Int
    public init(sku: String, unitPrice: Decimal, quantity: Int) {
        self.sku = sku; self.unitPrice = unitPrice; self.quantity = quantity
    }
    public var subtotal: Decimal { unitPrice * Decimal(quantity) }
}

public enum CartError: Error, Equatable { case emptyCart, itemNotFound }

public struct Cart {
    public private(set) var items: [CartItem]
    public init(items: [CartItem] = []) { self.items = items }

    public var total: Decimal { items.reduce(0) { $0 + $1.subtotal } }

    public mutating func add(_ item: CartItem) {
        if let i = items.firstIndex(where: { $0.sku == item.sku }) {
            let existing = items[i]
            items[i] = CartItem(sku: existing.sku,
                                unitPrice: existing.unitPrice,
                                quantity: existing.quantity + item.quantity)
        } else {
            items.append(item)
        }
    }

    public mutating func remove(sku: String) throws {
        guard let i = items.firstIndex(where: { $0.sku == sku }) else { throw CartError.itemNotFound }
        items.remove(at: i)
    }

    // TELL, don't ask. The caller does not read `total`, compare it, and decide —
    // because then that rule would be copied into every caller and one copy would
    // be wrong. The cart holds the data, so the cart makes the decision.
    //
    // Once `subtotal` and `total` live on the types that own the data
    // (Information Expert), the anemic "CartCalculatorService" has nothing left
    // to do. That is the correct outcome, not a missing class.
    public func shippingCost(freeOver threshold: Decimal, otherwise fee: Decimal) throws -> Decimal {
        guard !items.isEmpty else { throw CartError.emptyCart }
        return total >= threshold ? 0 : fee
    }
}

// MARK: - E5

public protocol PasswordRule {
    var describe: String { get }
    func isSatisfied(by password: String) -> Bool
}

public struct MinLengthRule: PasswordRule {
    public let min: Int
    public init(min: Int) { self.min = min }
    public var describe: String { "min-\(min)" }
    public func isSatisfied(by password: String) -> Bool { password.count >= min }
}

public struct ContainsDigitRule: PasswordRule {
    public init() {}
    public var describe: String { "digit" }
    public func isSatisfied(by password: String) -> Bool { password.contains(where: \.isNumber) }
}

public struct NotInDenylistRule: PasswordRule {
    public let denylist: Set<String>
    public init(denylist: Set<String>) { self.denylist = denylist }
    public var describe: String { "denylist" }
    public func isSatisfied(by password: String) -> Bool {
        !denylist.contains { $0.lowercased() == password.lowercased() }
    }
}

public struct PasswordPolicy {
    private let rules: [any PasswordRule]
    public init(rules: [any PasswordRule]) { self.rules = rules }
    // WHAT VARIES: the rules. WHAT IS STABLE: "run them all, collect the failures".
    // Separating those two is the whole design, and it is why the grader can define
    // a brand-new rule inside a test and have it work.
    //
    // Returning WHICH rules failed rather than a Bool costs nothing and gives the
    // UI real feedback. An error-free boolean is usually a lossy API — design for
    // the caller's actual need.
    public func failures(for password: String) -> [String] {
        rules.filter { !$0.isSatisfied(by: password) }.map(\.describe)
    }
    public func isValid(_ password: String) -> Bool { failures(for: password).isEmpty }
}

// MARK: - E6

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

public func principle(for situation: Situation) -> DesignPrinciple {
    switch situation {
    case .sameValidationRuleCopiedIntoThreeScreens:   .dry
    case .protocolWithOneConformerAndNoTestDouble:    .kiss
    case .configFlagsForFeaturesNobodyRequested:      .yagni
    case .callerWritesOrderCustomerAddressCityName:   .demeter
    case .callerReadsBalanceBranchesThenWritesItBack: .tellDontAsk
    case .serviceComputesCartTotalFromCartItems:      .informationExpert
    case .needAnOrderRepositoryWhichIsNoDomainNoun:   .pureFabrication
    case .frameworkCallsYourViewDidLoad:              .hollywood
    }
}
