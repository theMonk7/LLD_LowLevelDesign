import XCTest
@testable import M10

final class E1NounTests: XCTestCase {
    func test_verdicts() {
        let expected: [ParkingNoun: NounVerdict] = [
            .parkingLot: .entity,
            .floor: .entity,
            .parkingSpot: .entity,
            .vehicle: .entity,
            .ticket: .entity,
            .admin: .actor,
            .duration: .attribute,
            .pricing: .strategy,
            .system: .notModelled,
            .licensePlate: .valueObject,
            .money: .valueObject,
        ]
        for n in ParkingNoun.allCases {
            XCTAssertEqual(verdict(for: n), expected[n], "wrong verdict for \(n.rawValue)")
        }
    }
}

final class E2ImpliedEntityTests: XCTestCase {
    func test_mapping() {
        let expected: [RequirementFragment: ImpliedEntity] = [
            .aMemberBorrowsACopyForFourteenDays: .loan,
            .aDeliveryPartnerIsGivenAnOrderToDeliver: .assignment,
            .theUserPaysAndTheChargeMayFailAndBeRetried: .payment,
            .seatsAreHeldForFiveMinutesWhileTheUserPays: .reservation,
            .aCartBecomesAnOrderAndLaterMenuPricesChange: .orderLineWithPriceSnapshot,
            .aUserScoresTheRestaurantAfterDelivery: .rating,
            .aCardIsInsertedAndAPinEnteredUntilTheCardIsEjected: .session,
            .everyAdminPriceChangeMustBeTraceable: .auditEntry,
        ]
        for f in RequirementFragment.allCases {
            XCTAssertEqual(impliedEntity(for: f), expected[f], "wrong implied entity for \(f.rawValue)")
        }
    }
}

final class E3MachineTests: XCTestCase {
    private func machine(bank: [Coin: Int] = [.one: 5, .two: 5, .five: 5, .ten: 5]) -> DrinkMachine {
        DrinkMachine(
            drinks: [Drink(code: "A1", name: "Cola", price: 25),
                     Drink(code: "A2", name: "Water", price: 10),
                     Drink(code: "A3", name: "Juice", price: 3)],
            stock: ["A1": 2, "A2": 1, "A3": 1],
            bank: bank)
    }

    func test_insertAccumulates() {
        let m = machine()
        m.insert(.ten); m.insert(.five); m.insert(.one)
        XCTAssertEqual(m.insertedTotal, 16)
    }

    func test_refundReturnsCoinsLargestFirstAndClears() {
        let m = machine()
        m.insert(.one); m.insert(.ten); m.insert(.two)
        XCTAssertEqual(m.refund(), [.ten, .two, .one])
        XCTAssertEqual(m.insertedTotal, 0)
        XCTAssertEqual(m.bankCount(of: .ten), 5, "a refund must not touch the bank")
    }

    func test_unknownDrink() {
        let m = machine()
        m.insert(.ten)
        XCTAssertThrowsError(try m.select("ZZ")) { XCTAssertEqual($0 as? MachineError, .unknownDrink) }
        XCTAssertEqual(m.insertedTotal, 10, "a failed selection must not consume money")
    }

    func test_soldOut() {
        let m = machine()
        m.insert(.ten)
        _ = try? m.select("A2")                       // last Water
        m.insert(.ten)
        XCTAssertThrowsError(try m.select("A2")) { XCTAssertEqual($0 as? MachineError, .soldOut) }
    }

    func test_insufficientFundsReportsTheShortfall() {
        let m = machine()
        m.insert(.ten)
        XCTAssertThrowsError(try m.select("A1")) {
            XCTAssertEqual($0 as? MachineError, .insufficientFunds(needed: 15))
        }
        XCTAssertEqual(m.insertedTotal, 10)
    }

    func test_exactMoneyNoChange() throws {
        let m = machine()
        m.insert(.ten)
        let d = try m.select("A2")
        XCTAssertEqual(d.drink.name, "Water")
        XCTAssertEqual(d.change, [])
        XCTAssertEqual(m.insertedTotal, 0)
        XCTAssertEqual(m.stockCount(of: "A2"), 0)
        XCTAssertEqual(m.bankCount(of: .ten), 6, "the inserted coin joins the bank")
    }

    func test_changeIsGreedyLargestFirst() throws {
        let m = machine()
        m.insert(.ten); m.insert(.ten); m.insert(.ten)     // 30 for a 25 drink -> 5 change
        let d = try m.select("A1")
        XCTAssertEqual(d.change, [.five])
        XCTAssertEqual(m.bankCount(of: .five), 4)
        XCTAssertEqual(m.bankCount(of: .ten), 8)
        XCTAssertEqual(m.insertedTotal, 0)
    }

    func test_changeUsesSmallerCoinsWhenLargerAreExhausted() throws {
        let m = machine(bank: [.one: 4, .two: 0, .five: 0, .ten: 0])
        m.insert(.five)                                     // 5 for a 3 drink -> 2 change
        let d = try m.select("A3")
        XCTAssertEqual(d.change, [.one, .one])
        XCTAssertEqual(m.bankCount(of: .one), 2)
        XCTAssertEqual(m.bankCount(of: .five), 1)
    }

    func test_cannotMakeChangeLeavesEverythingUntouched() {
        let m = machine(bank: [.one: 0, .two: 0, .five: 0, .ten: 0])
        m.insert(.five)                                     // needs 2 back, bank has only the 5
        XCTAssertThrowsError(try m.select("A3")) { XCTAssertEqual($0 as? MachineError, .cannotMakeChange) }
        XCTAssertEqual(m.insertedTotal, 5, "money stays inserted so the customer can refund")
        XCTAssertEqual(m.stockCount(of: "A3"), 1, "stock must not be consumed")
        XCTAssertEqual(m.bankCount(of: .five), 0, "the bank must not absorb the coin on failure")
    }

    func test_restockAndLoadCoins() throws {
        let m = machine()
        m.insert(.ten); _ = try m.select("A2")
        XCTAssertEqual(m.stockCount(of: "A2"), 0)
        m.restock("A2", count: 3)
        XCTAssertEqual(m.stockCount(of: "A2"), 3)
        m.loadCoins(.one, count: 10)
        XCTAssertEqual(m.bankCount(of: .one), 15)
    }

    func test_collectCashEmptiesTheBankOnly() {
        let m = machine()
        m.insert(.ten)
        let taken = m.collectCash()
        XCTAssertEqual(taken[.ten], 5)
        XCTAssertEqual(m.bankCount(of: .ten), 0)
        XCTAssertEqual(m.insertedTotal, 10, "inserted coins are the customer's, not the operator's")
    }

    func test_fullSessionSequence() throws {
        let m = machine(bank: [.one: 2, .two: 1, .five: 1, .ten: 0])
        m.insert(.ten); m.insert(.ten); m.insert(.ten)
        let cola = try m.select("A1")                       // 30 - 25 = 5
        XCTAssertEqual(cola.change, [.five])
        m.insert(.five)
        XCTAssertThrowsError(try m.select("A1")) {
            XCTAssertEqual($0 as? MachineError, .insufficientFunds(needed: 20))
        }
        XCTAssertEqual(m.refund(), [.five])
        XCTAssertEqual(m.insertedTotal, 0)
        XCTAssertEqual(m.stockCount(of: "A1"), 1)
    }
}
