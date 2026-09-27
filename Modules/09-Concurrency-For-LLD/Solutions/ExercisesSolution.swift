//  Module 09 reference solutions.
//
//  HOW TO READ THIS FILE
//  Every comment here answers one question: WHERE COULD ANOTHER THREAD SLIP IN?
//  Read each method and mentally insert "...and now another task runs" between
//  every pair of lines. The comments mark the places where that insertion would
//  have broken something, and what the code does about it.
//
//  The exercise to study hardest is the idempotent payment service: its naive
//  version passes every sequential test and fails in production.
//
//  Not part of the M09 target.

import Foundation

// MARK: - E1

public actor SafeCounter {
    private var count = 0
    public init() {}
    public func increment() { count += 1 }
    public func add(_ n: Int) { count += n }
    public var value: Int { count }
}

// MARK: - E2

public final class LockedCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()
    public init() {}
    public func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
    public var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

// MARK: - E3

public actor SeatBooking {
    private var booked: Set<String> = []
    public init() {}
    // TWO wins in one line. `Set.insert` IS the atomic test-and-set — it returns
    // whether the insert happened — so there is no window between checking and
    // acting. And because this method contains no `await`, the actor runs it to
    // completion before admitting another caller.
    //
    // Worth being precise about: inside an actor with no suspension point, even
    // the naive `guard !contains { } ; insert` version would be safe. The danger
    // is not two statements — it is two statements WITH A SUSPENSION BETWEEN THEM,
    // or two statements outside any serialising context.
    public func book(_ seat: String) -> Bool { booked.insert(seat).inserted }
    public func isBooked(_ seat: String) -> Bool { booked.contains(seat) }
    public var bookedCount: Int { booked.count }
}

// MARK: - E4

public enum BookingError: Error, Equatable { case seatTaken, paymentFailed }

public actor SeatReservation {
    public enum SeatState: Equatable { case free, reserved, sold }
    private var states: [String: SeatState] = [:]

    public init(seats: [String]) {
        for s in seats { states[s] = .free }
    }

    // THE MOST IMPORTANT METHOD IN THIS MODULE.
    // It is synchronous on purpose. An `await` anywhere inside would release the
    // actor, let a second booker pass the same guard, and hand one seat to two
    // people — the actor-reentrancy bug, which looks correct in every sequential
    // test ever written.
    public func reserve(_ seat: String) -> Bool {          // NO await inside: atomic
        guard states[seat] == .free else { return false }
        states[seat] = .reserved
        return true
    }
    public func confirm(_ seat: String) -> Bool {
        guard states[seat] == .reserved else { return false }
        states[seat] = .sold
        return true
    }
    public func release(_ seat: String) {
        guard states[seat] == .reserved else { return }     // never frees a sold seat
        states[seat] = .free
    }
    public func state(of seat: String) -> SeatState { states[seat] ?? .free }
    public var soldCount: Int { states.values.filter { $0 == .sold }.count }
}

public struct BookingFlow {
    private let reservation: SeatReservation
    private let charge: @Sendable (Decimal) async -> Bool
    public init(reservation: SeatReservation, charge: @escaping @Sendable (Decimal) async -> Bool) {
        self.reservation = reservation
        self.charge = charge
    }
    public func book(_ seat: String, amount: Decimal) async throws {
        guard await reservation.reserve(seat) else { throw BookingError.seatTaken }
        // Holding a lock across a network call serialises EVERY booking in the
        // system behind one slow gateway. This is the most common concurrency
        // design error in booking systems, and the fix is structural, not clever:
        // reserve fast, charge slow, settle fast.
        let paid = await charge(amount)                      // slow work OUTSIDE the critical section
        if paid {
            _ = await reservation.confirm(seat)
        } else {
            // Compensation is part of the ALGORITHM, not cleanup. Forget it and
            // seats leak permanently — sales quietly drop and nobody knows why.
            // Still missing here, and worth saying aloud: a TTL. If the client
            // crashes between reserve and confirm, the seat is stuck in .reserved
            // forever. Real systems attach an expiry and sweep.
            await reservation.release(seat)
            throw BookingError.paymentFailed
        }
    }
}

// MARK: - E5

public actor FixedWindowRateLimiter {
    private let limit: Int
    private let windowSeconds: Double
    private var windowStart: Double
    private var used = 0
    private let now: @Sendable () -> Double

    public init(limit: Int, windowSeconds: Double, now: @escaping @Sendable () -> Double) {
        self.limit = limit
        self.windowSeconds = windowSeconds
        self.now = now
        self.windowStart = now()
    }

    // Roll, check, consume — ONE actor method, no suspension, so 2,000 concurrent
    // callers cannot overshoot the limit. Split this into `canAllow()` and
    // `consume()` and the test fails immediately: that split IS the check-then-act
    // bug.
    //
    // The clock is injected, so tests advance a fake clock instead of sleeping.
    // A rate-limiter test that calls Task.sleep is a test that fails on CI at 3am.
    //
    // Known flaw of the fixed window, worth naming: a client can send `limit`
    // requests at the end of one window and `limit` more at the start of the next.
    // Sliding window or token bucket fixes it, at the cost of more state.
    public func allow() -> Bool {
        rollIfNeeded()
        guard used < limit else { return false }
        used += 1                                            // test AND consume, one step
        return true
    }

    public var remaining: Int {
        max(0, limit - used)
    }

    private func rollIfNeeded() {
        let t = now()
        if t - windowStart >= windowSeconds {
            windowStart = t
            used = 0
        }
    }
}

// MARK: - E6

public actor IdempotentPaymentService {
    private var processed: [String: String] = [:]
    private var inFlight: [String: Task<String, Never>] = [:]
    private var inFlightCount = 0
    private let charge: @Sendable (Decimal) async -> String

    public init(charge: @escaping @Sendable (Decimal) async -> String) { self.charge = charge }

    public func pay(amount: Decimal, idempotencyKey: String) async -> String {
        if let done = processed[idempotencyKey] { return done }         // already settled
        if let running = inFlight[idempotencyKey] { return await running.value }  // coalesce retries

        // THE TRAP THIS EXERCISE EXISTS FOR.
        // The naive version — check `processed`, await the charge, store the result
        // — is correct sequentially and WRONG under concurrency: at the `await` the
        // actor suspends, the other 199 callers enter, all find `processed` empty,
        // and all charge. Idempotency implemented with a reentrancy bug is worse
        // than none, because it looks correct in every test that is not concurrent.
        //
        // The fix is to publish the IN-FLIGHT TASK under the key BEFORE suspending,
        // so later callers find it and await the same result. One charge, 200
        // identical answers. The same "task coalescing" idiom deduplicates
        // concurrent image downloads and token refreshes (Module 14).
        let charge = self.charge
        let task = Task { await charge(amount) }
        inFlight[idempotencyKey] = task
        let txn = await task.value                                      // suspension is safe:
        processed[idempotencyKey] = txn                                 // later callers found the task
        inFlight[idempotencyKey] = nil
        return txn
    }

    public var distinctPayments: Int { processed.count }
}

// MARK: - E7

public struct VersionedItem: Equatable {
    public var quantity: Int
    public var version: Int
    public init(quantity: Int, version: Int) { self.quantity = quantity; self.version = version }
}

public enum InventoryError: Error, Equatable { case outOfStock, conflict }

public actor OptimisticInventory {
    private var items: [String: VersionedItem] = [:]
    public private(set) var conflictCount = 0

    public init(items: [String: VersionedItem]) { self.items = items }

    public func read(_ sku: String) -> VersionedItem? { items[sku] }

    public func compareAndSet(_ sku: String, expectedVersion: Int, newQuantity: Int) -> Bool {
        // Compare-and-swap in one atomic step: a writer holding a stale snapshot
        // loses and retries, so no update is silently lost and no lock is held
        // across the read-compute-write cycle.
        //
        // When to prefer this: conflicts rare (a catalogue of a million SKUs).
        // When not: a hot row like the last seat of a sold-out show, where every
        // attempt collides and the retries themselves become the load.
        guard let current = items[sku], current.version == expectedVersion else {
            conflictCount += 1
            return false
        }
        items[sku] = VersionedItem(quantity: newQuantity, version: current.version + 1)
        return true
    }

    public func decrement(_ sku: String, maxAttempts: Int = 3) throws -> Int {
        for _ in 0..<max(1, maxAttempts) {
            guard let snapshot = items[sku] else { throw InventoryError.outOfStock }
            guard snapshot.quantity > 0 else { throw InventoryError.outOfStock }
            if compareAndSet(sku, expectedVersion: snapshot.version, newQuantity: snapshot.quantity - 1) {
                return snapshot.quantity - 1
            }
        }
        throw InventoryError.conflict
    }
}

// MARK: - E8

public final class ConcurrentCache: @unchecked Sendable {
    private var storage: [String: Int] = [:]
    private let queue = DispatchQueue(label: "m09.cache", attributes: .concurrent)
    public init() {}
    public func get(_ key: String) -> Int? { queue.sync { storage[key] } }
    // Concurrent reads run in parallel; a barrier write waits for in-flight reads
    // and excludes everything until it finishes. Right for read-heavy caches.
    //
    // The classic bug is `async(flags: .barrier)` for the write plus a `sync`
    // read: a read issued right after a write may run BEFORE it. `sync` here gives
    // read-after-write consistency. Async barriers are fine when you do not need
    // that — know which you are choosing.
    public func set(_ key: String, _ value: Int) { queue.sync(flags: .barrier) { storage[key] = value } }
    public var count: Int { queue.sync { storage.count } }
}

// MARK: - E9

public enum ConcurrencyHazard: String, Equatable, CaseIterable {
    case race, checkThenAct, deadlock, actorReentrancy, lostUpdate, nonIdempotentRetry
}

public enum HazardScenario: String, Equatable, CaseIterable {
    case twoThreadsBothRunCountPlusEquals1
    case guardNotBookedThenInsertInSeparateSteps
    case threadAHoldsSeatsWantsPaymentsThreadBTheReverse
    case awaitingAPaymentInTheMiddleOfAnActorMethod
    case readModifyWriteWithAStaleSnapshotOverwritingANewerOne
    case theClientRetriesAChargeAfterATimeout
}

public func hazard(in scenario: HazardScenario) -> ConcurrencyHazard {
    switch scenario {
    case .twoThreadsBothRunCountPlusEquals1:                       .race
    case .guardNotBookedThenInsertInSeparateSteps:                 .checkThenAct
    case .threadAHoldsSeatsWantsPaymentsThreadBTheReverse:         .deadlock
    case .awaitingAPaymentInTheMiddleOfAnActorMethod:              .actorReentrancy
    case .readModifyWriteWithAStaleSnapshotOverwritingANewerOne:   .lostUpdate
    case .theClientRetriesAChargeAfterATimeout:                    .nonIdempotentRetry
    }
}
