import XCTest
@testable import M09

final class E1CounterTests: XCTestCase {
    func test_tenThousandConcurrentIncrements() async {
        let c = SafeCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10_000 { group.addTask { await c.increment() } }
        }
        let v = await c.value
        XCTAssertEqual(v, 10_000, "lost updates — increment is not atomic")
    }
    func test_concurrentAdds() async {
        let c = SafeCounter()
        await withTaskGroup(of: Void.self) { group in
            for i in 1...1_000 { group.addTask { await c.add(i) } }
        }
        let v = await c.value
        XCTAssertEqual(v, 500_500)
    }
}

final class E2LockTests: XCTestCase {
    func test_concurrentIncrementsUnderALock() {
        let c = LockedCounter()
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in c.increment() }
        XCTAssertEqual(c.value, 10_000)
    }
}

final class E3SeatBookingTests: XCTestCase {
    func test_onlyOneWinnerPerSeat() async {
        let booking = SeatBooking()
        let wins = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<500 { group.addTask { await booking.book("A1") } }
            var total = 0
            for await won in group where won { total += 1 }
            return total
        }
        XCTAssertEqual(wins, 1, "exactly one caller may claim a seat")
        let count = await booking.bookedCount
        XCTAssertEqual(count, 1)
    }
    func test_manySeatsInParallel() async {
        let booking = SeatBooking()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask { _ = await booking.book("S\(i % 50)") }
                group.addTask { _ = await booking.book("S\(i % 50)") }
            }
        }
        let count = await booking.bookedCount
        XCTAssertEqual(count, 50)
    }
}

final class E4ReservationTests: XCTestCase {
    func test_reserveIsAtomic() async {
        let r = SeatReservation(seats: ["A1"])
        let wins = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<300 { group.addTask { await r.reserve("A1") } }
            var t = 0
            for await w in group where w { t += 1 }
            return t
        }
        XCTAssertEqual(wins, 1)
    }
    func test_successfulFlowSellsTheSeat() async throws {
        let r = SeatReservation(seats: ["A1"])
        let flow = BookingFlow(reservation: r, charge: { _ in true })
        try await flow.book("A1", amount: 500)
        let s = await r.state(of: "A1")
        XCTAssertEqual(s, .sold)
        let sold = await r.soldCount
        XCTAssertEqual(sold, 1)
    }
    func test_failedPaymentReleasesTheSeat() async {
        let r = SeatReservation(seats: ["A1"])
        let flow = BookingFlow(reservation: r, charge: { _ in false })
        do {
            try await flow.book("A1", amount: 500)
            XCTFail("expected paymentFailed")
        } catch {
            XCTAssertEqual(error as? BookingError, .paymentFailed)
        }
        let s = await r.state(of: "A1")
        XCTAssertEqual(s, .free, "a failed payment must release the reservation")
    }
    func test_secondBookerGetsSeatTaken() async {
        let r = SeatReservation(seats: ["A1"])
        let slow = BookingFlow(reservation: r, charge: { _ in
            try? await Task.sleep(nanoseconds: 20_000_000)
            return true
        })
        let first = Task { try? await slow.book("A1", amount: 500) }
        try? await Task.sleep(nanoseconds: 3_000_000)
        do {
            try await slow.book("A1", amount: 500)
            XCTFail("expected seatTaken")
        } catch {
            XCTAssertEqual(error as? BookingError, .seatTaken,
                           "the seat must be locked while the first payment is in flight")
        }
        _ = await first.value
    }
    func test_releaseNeverFreesASoldSeat() async {
        let r = SeatReservation(seats: ["A1"])
        _ = await r.reserve("A1")
        _ = await r.confirm("A1")
        await r.release("A1")
        let s = await r.state(of: "A1")
        XCTAssertEqual(s, .sold)
    }
}

final class E5RateLimiterTests: XCTestCase {
    private final class FakeClock: @unchecked Sendable {
        private var t: Double = 0
        private let lock = NSLock()
        var now: Double { lock.lock(); defer { lock.unlock() }; return t }
        func advance(_ d: Double) { lock.lock(); t += d; lock.unlock() }
    }

    func test_allowsUpToTheLimit() async {
        let clock = FakeClock()
        let rl = FixedWindowRateLimiter(limit: 3, windowSeconds: 1, now: { clock.now })
        var results: [Bool] = []
        for _ in 0..<5 { results.append(await rl.allow()) }
        XCTAssertEqual(results, [true, true, true, false, false])
    }
    func test_windowRollover() async {
        let clock = FakeClock()
        let rl = FixedWindowRateLimiter(limit: 2, windowSeconds: 1, now: { clock.now })
        _ = await rl.allow(); _ = await rl.allow()
        var blocked = await rl.allow()
        XCTAssertFalse(blocked)
        clock.advance(1.0)
        blocked = await rl.allow()
        XCTAssertTrue(blocked, "a new window must reset the budget")
        let left = await rl.remaining
        XCTAssertEqual(left, 1)
    }
    func test_neverOvershootsUnderConcurrency() async {
        let clock = FakeClock()
        let rl = FixedWindowRateLimiter(limit: 100, windowSeconds: 1_000, now: { clock.now })
        let allowed = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<2_000 { group.addTask { await rl.allow() } }
            var t = 0
            for await a in group where a { t += 1 }
            return t
        }
        XCTAssertEqual(allowed, 100, "test-and-consume must be atomic")
    }
}

final class E6IdempotencyTests: XCTestCase {
    func test_repeatedKeyChargesOnce() async {
        let counter = LockedCounter()
        let svc = IdempotentPaymentService(charge: { _ in
            counter.increment()
            return "txn-\(counter.value)"
        })
        let a = await svc.pay(amount: 100, idempotencyKey: "k1")
        let b = await svc.pay(amount: 100, idempotencyKey: "k1")
        XCTAssertEqual(a, b)
        XCTAssertEqual(counter.value, 1, "the gateway must be charged exactly once")
    }
    func test_differentKeysChargeSeparately() async {
        let counter = LockedCounter()
        let svc = IdempotentPaymentService(charge: { _ in counter.increment(); return "txn-\(counter.value)" })
        _ = await svc.pay(amount: 100, idempotencyKey: "k1")
        _ = await svc.pay(amount: 100, idempotencyKey: "k2")
        XCTAssertEqual(counter.value, 2)
        let distinct = await svc.distinctPayments
        XCTAssertEqual(distinct, 2)
    }
    func test_concurrentRetriesOfTheSameKey() async {
        let counter = LockedCounter()
        let svc = IdempotentPaymentService(charge: { _ in counter.increment(); return "txn" })
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<200 { group.addTask { await svc.pay(amount: 1, idempotencyKey: "same") } }
            for await _ in group {}
        }
        let distinct = await svc.distinctPayments
        XCTAssertEqual(distinct, 1)
    }
}

final class E7OptimisticTests: XCTestCase {
    func test_compareAndSetSucceedsOnMatchingVersion() async {
        let inv = OptimisticInventory(items: ["a": VersionedItem(quantity: 5, version: 1)])
        let ok = await inv.compareAndSet("a", expectedVersion: 1, newQuantity: 4)
        XCTAssertTrue(ok)
        let item = await inv.read("a")
        XCTAssertEqual(item, VersionedItem(quantity: 4, version: 2))
    }
    func test_compareAndSetFailsOnStaleVersion() async {
        let inv = OptimisticInventory(items: ["a": VersionedItem(quantity: 5, version: 3)])
        let ok = await inv.compareAndSet("a", expectedVersion: 1, newQuantity: 4)
        XCTAssertFalse(ok)
        let conflicts = await inv.conflictCount
        XCTAssertEqual(conflicts, 1)
    }
    func test_decrementToZeroThenOutOfStock() async throws {
        let inv = OptimisticInventory(items: ["a": VersionedItem(quantity: 2, version: 1)])
        _ = try await inv.decrement("a")
        let left = try await inv.decrement("a")
        XCTAssertEqual(left, 0)
        do {
            _ = try await inv.decrement("a")
            XCTFail("expected outOfStock")
        } catch {
            XCTAssertEqual(error as? InventoryError, .outOfStock)
        }
    }
    func test_concurrentDecrementsNeverOversell() async {
        let inv = OptimisticInventory(items: ["a": VersionedItem(quantity: 50, version: 1)])
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<200 {
                group.addTask { ((try? await inv.decrement("a", maxAttempts: 50)) != nil) }
            }
            var t = 0
            for await s in group where s { t += 1 }
            return t
        }
        let item = await inv.read("a")
        XCTAssertEqual(item?.quantity, 0)
        XCTAssertEqual(successes, 50, "exactly the available quantity may succeed")
    }
}

final class E8CacheTests: XCTestCase {
    func test_readWrite() {
        let c = ConcurrentCache()
        c.set("a", 1)
        XCTAssertEqual(c.get("a"), 1)
        XCTAssertNil(c.get("zz"))
    }
    func test_concurrentWritesAllLand() {
        let c = ConcurrentCache()
        DispatchQueue.concurrentPerform(iterations: 500) { i in c.set("k\(i)", i) }
        XCTAssertEqual(c.count, 500)
        XCTAssertEqual(c.get("k499"), 499)
    }
    func test_mixedReadsAndWrites() {
        let c = ConcurrentCache()
        DispatchQueue.concurrentPerform(iterations: 1_000) { i in
            if i % 2 == 0 { c.set("k\(i)", i) } else { _ = c.get("k\(i - 1)") }
        }
        XCTAssertEqual(c.count, 500)
    }
}

final class E9HazardTests: XCTestCase {
    func test_mapping() {
        let expected: [HazardScenario: ConcurrencyHazard] = [
            .twoThreadsBothRunCountPlusEquals1: .race,
            .guardNotBookedThenInsertInSeparateSteps: .checkThenAct,
            .threadAHoldsSeatsWantsPaymentsThreadBTheReverse: .deadlock,
            .awaitingAPaymentInTheMiddleOfAnActorMethod: .actorReentrancy,
            .readModifyWriteWithAStaleSnapshotOverwritingANewerOne: .lostUpdate,
            .theClientRetriesAChargeAfterATimeout: .nonIdempotentRetry,
        ]
        for s in HazardScenario.allCases {
            XCTAssertEqual(hazard(in: s), expected[s], "wrong hazard for \(s.rawValue)")
        }
    }
}
