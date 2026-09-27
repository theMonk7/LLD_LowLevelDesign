import XCTest
@testable import M03

final class E1DRYTests: XCTestCase {
    func test_validUsernames() {
        XCTAssertNotNil(Username("abc"))
        XCTAssertNotNil(Username("a1b2c3"))
        XCTAssertNotNil(Username(String(repeating: "a", count: 20)))
    }
    func test_invalidUsernames() {
        XCTAssertNil(Username("ab"))                                    // too short
        XCTAssertNil(Username(String(repeating: "a", count: 21)))       // too long
        XCTAssertNil(Username("1abc"))                                  // must start with a letter
        XCTAssertNil(Username("ab_c"))                                  // non-alphanumeric
        XCTAssertNil(Username(""))
    }
    func test_formUsesTheSameRule() {
        XCTAssertTrue(SignupForm().validate(username: "valid1"))
        XCTAssertFalse(SignupForm().validate(username: "no"))
        XCTAssertFalse(SignupForm().validate(username: "1nope"))
    }
    func test_importerUsesTheSameRule() {
        let kept = AdminImporter().importUsers(["ok1", "no", "alsoFine", "9bad"])
        XCTAssertEqual(kept.map(\.value), ["ok1", "alsoFine"])
    }
}

final class E2KISSTests: XCTestCase {
    func test_identity() {
        XCTAssertEqual(convert(25, from: .celsius, to: .celsius), 25, accuracy: 0.001)
    }
    func test_celsiusToFahrenheit() {
        XCTAssertEqual(convert(100, from: .celsius, to: .fahrenheit), 212, accuracy: 0.001)
        XCTAssertEqual(convert(-40, from: .celsius, to: .fahrenheit), -40, accuracy: 0.001)
    }
    func test_fahrenheitToCelsius() {
        XCTAssertEqual(convert(32, from: .fahrenheit, to: .celsius), 0, accuracy: 0.001)
    }
    func test_kelvin() {
        XCTAssertEqual(convert(0, from: .celsius, to: .kelvin), 273.15, accuracy: 0.001)
        XCTAssertEqual(convert(273.15, from: .kelvin, to: .celsius), 0, accuracy: 0.001)
        XCTAssertEqual(convert(212, from: .fahrenheit, to: .kelvin), 373.15, accuracy: 0.01)
    }
    func test_roundTripAllPairs() {
        for a in TemperatureScale.allCases {
            for b in TemperatureScale.allCases {
                let there = convert(37, from: a, to: b)
                XCTAssertEqual(convert(there, from: b, to: a), 37, accuracy: 0.001)
            }
        }
    }
}

final class E3DemeterTests: XCTestCase {
    private let shipment = Shipment(customer: Customer(
        name: "Asha", address: Address(line1: "12 Main", city: City(name: "Bengaluru"))))

    func test_eachLevelForwards() {
        XCTAssertEqual(City(name: "Pune").displayName, "Pune")
        XCTAssertEqual(Address(line1: "x", city: City(name: "Pune")).cityName, "Pune")
        XCTAssertEqual(Customer(name: "A", address: Address(line1: "x", city: City(name: "Pune"))).cityName, "Pune")
    }
    func test_shipmentAsksOnlyItsCustomer() {
        XCTAssertEqual(shipment.destinationCity, "Bengaluru")
    }
    func test_label() {
        XCTAssertEqual(shipment.label, "Asha → Bengaluru")
    }
}

final class E4TellDontAskTests: XCTestCase {
    func test_itemSubtotal() {
        XCTAssertEqual(CartItem(sku: "a", unitPrice: 25, quantity: 4).subtotal, 100)
    }
    func test_cartTotal() {
        let cart = Cart(items: [CartItem(sku: "a", unitPrice: 25, quantity: 4),
                                CartItem(sku: "b", unitPrice: 10, quantity: 2)])
        XCTAssertEqual(cart.total, 120)
    }
    func test_emptyCartTotalIsZero() {
        XCTAssertEqual(Cart().total, 0)
    }
    func test_addMergesBySku() {
        var cart = Cart(items: [CartItem(sku: "a", unitPrice: 25, quantity: 1)])
        cart.add(CartItem(sku: "a", unitPrice: 99, quantity: 2))
        XCTAssertEqual(cart.items.count, 1)
        XCTAssertEqual(cart.items[0].quantity, 3)
        XCTAssertEqual(cart.items[0].unitPrice, 25, "merge keeps the first unit price")
    }
    func test_addNewSkuAppends() {
        var cart = Cart(items: [CartItem(sku: "a", unitPrice: 25, quantity: 1)])
        cart.add(CartItem(sku: "b", unitPrice: 5, quantity: 1))
        XCTAssertEqual(cart.items.map(\.sku), ["a", "b"])
    }
    func test_removeMissingThrows() {
        var cart = Cart(items: [CartItem(sku: "a", unitPrice: 25, quantity: 1)])
        XCTAssertThrowsError(try cart.remove(sku: "zz")) { XCTAssertEqual($0 as? CartError, .itemNotFound) }
        XCTAssertEqual(cart.items.count, 1)
    }
    func test_remove() throws {
        var cart = Cart(items: [CartItem(sku: "a", unitPrice: 25, quantity: 1),
                                CartItem(sku: "b", unitPrice: 5, quantity: 1)])
        try cart.remove(sku: "a")
        XCTAssertEqual(cart.items.map(\.sku), ["b"])
    }
    func test_shippingDecidedByTheCart() throws {
        let big = Cart(items: [CartItem(sku: "a", unitPrice: 500, quantity: 2)])
        XCTAssertEqual(try big.shippingCost(freeOver: 500, otherwise: 60), 0)
        let small = Cart(items: [CartItem(sku: "a", unitPrice: 50, quantity: 1)])
        XCTAssertEqual(try small.shippingCost(freeOver: 500, otherwise: 60), 60)
    }
    func test_shippingOnEmptyCartThrows() {
        XCTAssertThrowsError(try Cart().shippingCost(freeOver: 1, otherwise: 1)) {
            XCTAssertEqual($0 as? CartError, .emptyCart)
        }
    }
}

final class E5VariationTests: XCTestCase {
    private var policy: PasswordPolicy {
        PasswordPolicy(rules: [MinLengthRule(min: 8), ContainsDigitRule(),
                               NotInDenylistRule(denylist: ["password1", "letmein1"])])
    }
    func test_individualRules() {
        XCTAssertTrue(MinLengthRule(min: 3).isSatisfied(by: "abc"))
        XCTAssertFalse(MinLengthRule(min: 4).isSatisfied(by: "abc"))
        XCTAssertTrue(ContainsDigitRule().isSatisfied(by: "a1"))
        XCTAssertFalse(ContainsDigitRule().isSatisfied(by: "ab"))
        XCTAssertFalse(NotInDenylistRule(denylist: ["abc"]).isSatisfied(by: "ABC"))
        XCTAssertTrue(NotInDenylistRule(denylist: ["abc"]).isSatisfied(by: "abd"))
    }
    func test_descriptions() {
        XCTAssertEqual(MinLengthRule(min: 8).describe, "min-8")
        XCTAssertEqual(ContainsDigitRule().describe, "digit")
        XCTAssertEqual(NotInDenylistRule(denylist: []).describe, "denylist")
    }
    func test_validPassword() {
        XCTAssertTrue(policy.isValid("correct9horse"))
        XCTAssertEqual(policy.failures(for: "correct9horse"), [])
    }
    func test_failuresInRuleOrder() {
        XCTAssertEqual(policy.failures(for: "short"), ["min-8", "digit"])
    }
    func test_denylistFailure() {
        XCTAssertEqual(policy.failures(for: "PASSWORD1"), ["denylist"])
    }
    /// A rule invented by the caller must work without touching PasswordPolicy.
    func test_policyIsOpenForNewRules() {
        struct NoSpaces: PasswordRule {
            var describe: String { "no-spaces" }
            func isSatisfied(by password: String) -> Bool { !password.contains(" ") }
        }
        let p = PasswordPolicy(rules: [NoSpaces()])
        XCTAssertEqual(p.failures(for: "a b"), ["no-spaces"])
        XCTAssertTrue(p.isValid("ab"))
    }
}

final class E6PrincipleTests: XCTestCase {
    func test_mapping() {
        let expected: [Situation: DesignPrinciple] = [
            .sameValidationRuleCopiedIntoThreeScreens: .dry,
            .protocolWithOneConformerAndNoTestDouble: .kiss,
            .configFlagsForFeaturesNobodyRequested: .yagni,
            .callerWritesOrderCustomerAddressCityName: .demeter,
            .callerReadsBalanceBranchesThenWritesItBack: .tellDontAsk,
            .serviceComputesCartTotalFromCartItems: .informationExpert,
            .needAnOrderRepositoryWhichIsNoDomainNoun: .pureFabrication,
            .frameworkCallsYourViewDidLoad: .hollywood,
        ]
        for s in Situation.allCases {
            XCTAssertEqual(principle(for: s), expected[s], "wrong principle for \(s.rawValue)")
        }
    }
}
