//  Module 10 — Framework exercises.
//
//  E1 and E2 are recall drills for step E of DESIGN.
//  E3 is a full timed design: SET A 60-MINUTE TIMER and work D -> E -> S -> I -> G
//  -> N on paper before writing a line of Swift.
//
//  While designing E3, the questions that matter:
//    - what is finite here, and what are the states of one unit of it?
//    - which of these failures should be checked FIRST? (guard order is a product
//      decision)
//    - this operation touches three pieces of state — how do I make it
//      all-or-nothing?
//    - what did the requirements paragraph deliberately leave out, and why is that
//      the right boundary?
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 Noun triage
//  Given the agreed requirement paragraph for a parking lot, decide what each noun is.

public enum NounVerdict: String, Equatable, CaseIterable {
    case entity          // a modelled type with identity or meaningful data
    case valueObject     // data compared by contents, no identity
    case actor           // a person/system outside the model
    case attribute       // a field on something else, not a type
    case notModelled     // "the system", "the app" — noise
    case strategy        // a varying rule, belongs behind a protocol
}

public enum ParkingNoun: String, Equatable, CaseIterable {
    case parkingLot, floor, parkingSpot, vehicle, ticket, admin, duration, pricing, system, licensePlate, money
}

public func verdict(for noun: ParkingNoun) -> NounVerdict { fatalError("TODO E1") }

// MARK: - E2 Implied entities
//  Which entity does each requirement fragment imply — the one NOT named in the prompt?

public enum ImpliedEntity: String, Equatable, CaseIterable {
    case loan, assignment, payment, reservation, orderLineWithPriceSnapshot, rating, session, auditEntry
}

public enum RequirementFragment: String, Equatable, CaseIterable {
    case aMemberBorrowsACopyForFourteenDays
    case aDeliveryPartnerIsGivenAnOrderToDeliver
    case theUserPaysAndTheChargeMayFailAndBeRetried
    case seatsAreHeldForFiveMinutesWhileTheUserPays
    case aCartBecomesAnOrderAndLaterMenuPricesChange
    case aUserScoresTheRestaurantAfterDelivery
    case aCardIsInsertedAndAPinEnteredUntilTheCardIsEjected
    case everyAdminPriceChangeMustBeTraceable
}

public func impliedEntity(for fragment: RequirementFragment) -> ImpliedEntity { fatalError("TODO E2") }

// MARK: - E3 Timed design: a drink vending machine with coins and change
//
//  Agreed requirements (this is the paragraph you would have produced in step D):
//  "A machine holds drinks, each with a code, a name and a price in whole rupees.
//   Customers insert coins (1, 2, 5, 10), select a drink by code, and receive the
//   drink plus change. Change is made from the coin bank, which includes the coins
//   just inserted. If exact change cannot be made, the purchase is refused and the
//   customer's money is left inserted so they can refund or pick something else.
//   Customers may refund at any time. Operators restock drinks and coins.
//   Out of scope: card payments, multiple currencies, persistence, UI."

public enum Coin: Int, CaseIterable, Comparable, Hashable {
    case one = 1, two = 2, five = 5, ten = 10
    public static func < (a: Coin, b: Coin) -> Bool { a.rawValue < b.rawValue }
}

public struct Drink: Equatable {
    public let code: String
    public let name: String
    public let price: Int
    public init(code: String, name: String, price: Int) {
        self.code = code; self.name = name; self.price = price
    }
}

public struct Dispense: Equatable {
    public let drink: Drink
    /// Coins returned, largest denomination first.
    public let change: [Coin]
    public init(drink: Drink, change: [Coin]) { self.drink = drink; self.change = change }
}

public enum MachineError: Error, Equatable {
    case unknownDrink
    case soldOut
    case insufficientFunds(needed: Int)
    case cannotMakeChange
}

public final class DrinkMachine {
    private var drinks: [String: Drink] = [:]
    private var stock: [String: Int] = [:]
    private var bank: [Coin: Int] = [:]
    private var inserted: [Coin] = []

    public init(drinks: [Drink], stock: [String: Int], bank: [Coin: Int]) { fatalError("TODO E3a") }

    // --- queries
    public var insertedTotal: Int { fatalError("TODO E3b") }
    public func stockCount(of code: String) -> Int { fatalError("TODO E3b") }
    public func bankCount(of coin: Coin) -> Int { fatalError("TODO E3b") }

    // --- customer operations
    public func insert(_ coin: Coin) { fatalError("TODO E3c") }

    /// Returns the inserted coins (largest first) and clears them. The bank is untouched.
    public func refund() -> [Coin] { fatalError("TODO E3d") }

    /// Rules, in this order:
    ///  1. unknown code                     -> .unknownDrink              (nothing changes)
    ///  2. stock == 0                       -> .soldOut                   (nothing changes)
    ///  3. insertedTotal < price            -> .insufficientFunds(needed: price - insertedTotal)
    ///  4. change cannot be made exactly    -> .cannotMakeChange          (money stays inserted)
    ///  5. otherwise: bank absorbs the inserted coins, change is removed from the bank,
    ///     stock decrements, inserted is cleared, and the change is returned largest-first.
    ///
    /// Change is made greedily from the largest denomination down, using the bank
    /// *after* it has absorbed the inserted coins.
    public func select(_ code: String) throws -> Dispense { fatalError("TODO E3e") }

    // --- operator operations
    public func restock(_ code: String, count: Int) { fatalError("TODO E3f") }
    public func loadCoins(_ coin: Coin, count: Int) { fatalError("TODO E3f") }
    /// Operator empties the bank; returns what was taken. Inserted coins are not touched.
    public func collectCash() -> [Coin: Int] { fatalError("TODO E3f") }
}
