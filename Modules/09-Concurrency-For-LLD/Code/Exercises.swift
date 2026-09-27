//  Module 09 — Concurrency exercises.
//
//  BEFORE YOU TYPE: read each method and mentally insert "...AND NOW ANOTHER TASK
//  RUNS" between every pair of lines. Then ask:
//    - did I CHECK something and then ACT on what I checked? Close the gap.
//    - is there an `await` in the middle of a decision? Everything I learned
//      before it is now stale.
//    - is slow work (a payment, a network call) happening inside the region that
//      is supposed to protect state? Move it out.
//    - if a client crashes halfway through, what releases the resource?
//    - what happens if this request arrives TWICE?
//
//  These tests run REAL concurrent load — thousands of overlapping tasks — so a
//  missing guard does not merely look wrong, it fails.
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 A counter that survives concurrent increments (actor)

public actor SafeCounter {
    private var count = 0
    public init() {}
    public func increment() { fatalError("TODO E1a") }
    public func add(_ n: Int) { fatalError("TODO E1a") }
    public var value: Int { fatalError("TODO E1a") }
}

// MARK: - E2 The same thing with a lock, for a synchronous API

public final class LockedCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()
    public init() {}
    /// Must use `defer` so an early exit can never leave the lock held.
    public func increment() { fatalError("TODO E2a") }
    public var value: Int { fatalError("TODO E2a") }
}

// MARK: - E3 Seat booking — the check-then-act problem
//  `book` must be atomic: exactly one caller may ever win a given seat.

public actor SeatBooking {
    private var booked: Set<String> = []
    public init() {}
    /// Returns true only for the caller that actually claimed the seat.
    public func book(_ seat: String) -> Bool { fatalError("TODO E3a") }
    public func isBooked(_ seat: String) -> Bool { fatalError("TODO E3a") }
    public var bookedCount: Int { fatalError("TODO E3a") }
}

// MARK: - E4 Reserve → pay → confirm/release (actor reentrancy done right)
//  The payment step is async, so it must happen OUTSIDE the critical section.

public enum BookingError: Error, Equatable { case seatTaken, paymentFailed }

public actor SeatReservation {
    public enum SeatState: Equatable { case free, reserved, sold }
    private var states: [String: SeatState] = [:]
    public init(seats: [String]) { fatalError("TODO E4a") }   // all seats start .free

    /// Synchronous and atomic: no `await` inside. free -> reserved, returns true.
    public func reserve(_ seat: String) -> Bool { fatalError("TODO E4b") }
    /// reserved -> sold. Returns false if the seat wasn't reserved.
    public func confirm(_ seat: String) -> Bool { fatalError("TODO E4c") }
    /// reserved -> free (used when payment fails). Never frees a sold seat.
    public func release(_ seat: String) { fatalError("TODO E4d") }
    public func state(of seat: String) -> SeatState { fatalError("TODO E4e") }
    public var soldCount: Int { fatalError("TODO E4e") }
}

public struct BookingFlow {
    private let reservation: SeatReservation
    private let charge: @Sendable (Decimal) async -> Bool
    public init(reservation: SeatReservation, charge: @escaping @Sendable (Decimal) async -> Bool) {
        self.reservation = reservation
        self.charge = charge
    }
    /// 1. reserve (atomic)  2. charge (slow, outside the actor)
    /// 3. confirm on success / release on failure, then throw .paymentFailed.
    public func book(_ seat: String, amount: Decimal) async throws {
        fatalError("TODO E4f")
    }
}

// MARK: - E5 Rate limiter — atomic test-and-consume (fixed window)

public actor FixedWindowRateLimiter {
    private let limit: Int
    private let windowSeconds: Double
    private var windowStart: Double
    private var used = 0
    /// Injected clock so tests are deterministic — no sleeping.
    private let now: @Sendable () -> Double

    public init(limit: Int, windowSeconds: Double, now: @escaping @Sendable () -> Double) {
        fatalError("TODO E5a")
    }

    /// Consumes one token if available. Rolls the window over when
    /// now() - windowStart >= windowSeconds. Test and consume must be one step.
    public func allow() -> Bool { fatalError("TODO E5b") }
    public var remaining: Int { fatalError("TODO E5c") }
}

// MARK: - E6 Idempotent payments

public actor IdempotentPaymentService {
    private var processed: [String: String] = [:]          // key -> transaction id
    private var inFlightCount = 0
    private let charge: @Sendable (Decimal) async -> String
    public init(charge: @escaping @Sendable (Decimal) async -> String) { fatalError("TODO E6a") }

    /// Returns the SAME transaction id for a repeated idempotency key,
    /// and must not call `charge` twice for the same key.
    ///
    /// ⚠️ Hint — this is the actor-reentrancy exercise. `charge` is async, so the
    /// actor suspends during it and 200 concurrent callers with the same key will
    /// ALL miss a naive `processed[key]` check. You need to record the in-flight
    /// work (a `Task`) under the key so later callers await the same one.
    public func pay(amount: Decimal, idempotencyKey: String) async -> String {
        fatalError("TODO E6b")
    }
    public var distinctPayments: Int { fatalError("TODO E6c") }
}

// MARK: - E7 Optimistic locking with a version number

public struct VersionedItem: Equatable {
    public var quantity: Int
    public var version: Int
    public init(quantity: Int, version: Int) { self.quantity = quantity; self.version = version }
}

public enum InventoryError: Error, Equatable { case outOfStock, conflict }

public actor OptimisticInventory {
    private var items: [String: VersionedItem] = [:]
    public private(set) var conflictCount = 0
    public init(items: [String: VersionedItem]) { fatalError("TODO E7a") }

    public func read(_ sku: String) -> VersionedItem? { fatalError("TODO E7b") }

    /// Writes only when the stored version still equals `expectedVersion`.
    /// On mismatch: increments conflictCount and returns false.
    public func compareAndSet(_ sku: String, expectedVersion: Int, newQuantity: Int) -> Bool {
        fatalError("TODO E7c")
    }

    /// Read → check stock → compareAndSet, retrying up to `maxAttempts`.
    /// Throws .outOfStock when quantity is 0, .conflict when attempts run out.
    public func decrement(_ sku: String, maxAttempts: Int = 3) throws -> Int {
        fatalError("TODO E7d")
    }
}

// MARK: - E8 Reader-writer cache (many readers, exclusive writers)

public final class ConcurrentCache: @unchecked Sendable {
    private var storage: [String: Int] = [:]
    private let queue = DispatchQueue(label: "m09.cache", attributes: .concurrent)
    public init() {}
    /// Concurrent read.
    public func get(_ key: String) -> Int? { fatalError("TODO E8a") }
    /// Exclusive write (barrier).
    public func set(_ key: String, _ value: Int) { fatalError("TODO E8b") }
    public var count: Int { fatalError("TODO E8c") }
}

// MARK: - E9 — hazard identification (knowledge check)

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

public func hazard(in scenario: HazardScenario) -> ConcurrencyHazard { fatalError("TODO E9") }
