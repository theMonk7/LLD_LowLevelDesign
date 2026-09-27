//  Module 10 reference solutions.
//
//  HOW TO READ THIS FILE
//  This is a full design produced by the DESIGN framework, so read it as a trace
//  of that process:
//    D  the requirements paragraph in Exercises.swift IS the output of step D
//    E  entities: Drink (value), Coin (value), DrinkMachine (entity). No Manager.
//    S  one invariant: bank + stock + inserted stay consistent after EVERY call
//    I  the public API reads exactly like the use-case list
//    G  edge cases: empty bank, exact money, sold out, unknown code, atomicity
//    N  values first, then the machine, then the failure ordering
//
//  The comments mark the two decisions that carry the most marks: guard ORDER,
//  and commit-at-the-end atomicity.
//
//  Not part of the M10 target.

import Foundation

// MARK: - E1

public enum NounVerdict: String, Equatable, CaseIterable {
    case entity, valueObject, actor, attribute, notModelled, strategy
}

public enum ParkingNoun: String, Equatable, CaseIterable {
    case parkingLot, floor, parkingSpot, vehicle, ticket, admin, duration, pricing, system, licensePlate, money
}

public func verdict(for noun: ParkingNoun) -> NounVerdict {
    switch noun {
    case .parkingLot:   .entity
    case .floor:        .entity
    case .parkingSpot:  .entity
    case .vehicle:      .entity
    case .ticket:       .entity
    case .admin:        .actor
    case .duration:     .attribute        // derived from entry/exit timestamps
    case .pricing:      .strategy         // varies; belongs behind a protocol
    case .system:       .notModelled
    case .licensePlate: .valueObject
    case .money:        .valueObject
    }
}

// MARK: - E2

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

public func impliedEntity(for fragment: RequirementFragment) -> ImpliedEntity {
    switch fragment {
    case .aMemberBorrowsACopyForFourteenDays:            .loan
    case .aDeliveryPartnerIsGivenAnOrderToDeliver:       .assignment
    case .theUserPaysAndTheChargeMayFailAndBeRetried:    .payment
    case .seatsAreHeldForFiveMinutesWhileTheUserPays:    .reservation
    case .aCartBecomesAnOrderAndLaterMenuPricesChange:   .orderLineWithPriceSnapshot
    case .aUserScoresTheRestaurantAfterDelivery:         .rating
    case .aCardIsInsertedAndAPinEnteredUntilTheCardIsEjected: .session
    case .everyAdminPriceChangeMustBeTraceable:          .auditEntry
    }
}

// MARK: - E3

public enum Coin: Int, CaseIterable, Comparable, Hashable {
    case one = 1, two = 2, five = 5, ten = 10
    public static func < (a: Coin, b: Coin) -> Bool { a.rawValue < b.rawValue }
}

public struct Drink: Equatable {
    public let code: String
    public let name: String
    public let price: Int
    public init(code: String, name: String, price: Int) { self.code = code; self.name = name; self.price = price }
}

public struct Dispense: Equatable {
    public let drink: Drink
    public let change: [Coin]
    public init(drink: Drink, change: [Coin]) { self.drink = drink; self.change = change }
}

public enum MachineError: Error, Equatable {
    case unknownDrink, soldOut, insufficientFunds(needed: Int), cannotMakeChange
}

public final class DrinkMachine {
    private var drinks: [String: Drink] = [:]
    private var stock: [String: Int] = [:]
    private var bank: [Coin: Int] = [:]
    private var inserted: [Coin] = []

    public init(drinks: [Drink], stock: [String: Int], bank: [Coin: Int]) {
        for d in drinks { self.drinks[d.code] = d }
        self.stock = stock
        self.bank = bank
    }

    // queries
    public var insertedTotal: Int { inserted.reduce(0) { $0 + $1.rawValue } }
    public func stockCount(of code: String) -> Int { stock[code] ?? 0 }
    public func bankCount(of coin: Coin) -> Int { bank[coin] ?? 0 }

    // customer
    public func insert(_ coin: Coin) { inserted.append(coin) }

    public func refund() -> [Coin] {
        let returned = inserted.sorted(by: >)
        inserted.removeAll()
        return returned
    }

    // READ THE GUARD ORDER FIRST. Cheapest and most informative check first:
    // unknown -> sold out -> insufficient funds -> cannot make change. Reorder it
    // and you tell a customer "insufficient funds" for a drink that is sold out —
    // technically true, practically useless.
    //
    // Guard ORDERING is a product decision, which is exactly the kind of thing to
    // ask about in a real round rather than assume.
    //
    // `.insufficientFunds(needed:)` carries the shortfall rather than a bare flag:
    // the machine knows the number, so the caller should not recompute it.
    public func select(_ code: String) throws -> Dispense {
        guard let drink = drinks[code] else { throw MachineError.unknownDrink }
        guard stockCount(of: code) > 0 else { throw MachineError.soldOut }
        let paid = insertedTotal
        guard paid >= drink.price else {
            throw MachineError.insufficientFunds(needed: drink.price - paid)
        }

        // THE PART MOST CANDIDATES MISS: atomicity across several fields.
        //
        // The obvious implementation absorbs the inserted coins into `bank` first,
        // then discovers it cannot make change — and now the customer's money is
        // gone. Computing on a COPY and committing only after every rule passes is
        // validate-then-mutate (Module 01) applied to a multi-field update: a poor
        // engineer's transaction, and exactly what the failing test checks.
        //
        // Use this shape whenever one operation touches several pieces of state.
        var provisional = bank
        for coin in inserted { provisional[coin, default: 0] += 1 }

        guard let change = Self.makeChange(amount: paid - drink.price, from: provisional) else {
            throw MachineError.cannotMakeChange
        }
        for coin in change { provisional[coin, default: 0] -= 1 }

        // Commit, only now that every rule has passed.
        bank = provisional
        stock[code] = stockCount(of: code) - 1
        inserted.removeAll()
        return Dispense(drink: drink, change: change)
    }

    // operator
    public func restock(_ code: String, count: Int) { stock[code] = stockCount(of: code) + count }
    public func loadCoins(_ coin: Coin, count: Int) { bank[coin, default: 0] += count }
    public func collectCash() -> [Coin: Int] {
        let taken = bank
        bank = [:]
        return taken
    }

    /// Greedy, largest denomination first. Returns nil when exact change is impossible.
    // Greedy, BOUNDED BY WHAT IS ACTUALLY IN THE BANK, returning nil rather than a
    // wrong answer. For {1,2,5,10} greedy is optimal; for arbitrary denominations
    // it is not, and with a limited bank it can fail where dynamic programming
    // would succeed.
    //
    // Say that out loud. Recognising greedy as a CHOSEN trade-off rather than a
    // universal truth is the senior signal — and for real coin systems greedy is
    // correct and O(denominations), so DP would be unjustified complexity.
    private static func makeChange(amount: Int, from available: [Coin: Int]) -> [Coin]? {
        guard amount > 0 else { return [] }
        var remaining = amount
        var result: [Coin] = []
        for coin in Coin.allCases.sorted(by: >) {
            var count = available[coin] ?? 0
            while count > 0, coin.rawValue <= remaining {
                result.append(coin)
                remaining -= coin.rawValue
                count -= 1
            }
        }
        return remaining == 0 ? result : nil
    }
}
