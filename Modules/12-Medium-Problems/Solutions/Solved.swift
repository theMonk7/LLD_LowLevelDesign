//  Module 12 — SOLVED problems, fully implemented.
//
//  HOW TO READ THIS FILE
//  These are the problems that actually get asked. Design yours first (25 minutes),
//  then read, then compare decisions.
//
//  Four recurring ideas carry most of the marks here — watch for them:
//    DERIVE, DON'T STORE      balances are a fold over the expense log, never a
//                             field, so editing history is trivially correct
//    COMMIT LAST              validate everything, then mutate (ATM, parking fee)
//    SNAPSHOT                 anything that history depends on is COPIED in, not
//                             referenced, or the past rewrites itself
//    HALF-OPEN INTERVALS      [1,3) and [3,5) do not overlap — one predicate that
//                             decides whether a hotel loses a night per room per day
//
//  Everything here compiles and is exercised by M12Demo.run().

import Foundation

// =====================================================================
// SOLVED 1 — Parking Lot
// =====================================================================

public enum VehicleSize: Int, Comparable, CaseIterable {
    case motorcycle = 0, car = 1, truck = 2
    public static func < (a: VehicleSize, b: VehicleSize) -> Bool { a.rawValue < b.rawValue }
}

public struct Vehicle12: Equatable {
    public let plate: String
    public let size: VehicleSize
    public init(plate: String, size: VehicleSize) { self.plate = plate; self.size = size }
}

public final class ParkingSpot {
    public let id: String
    public let size: VehicleSize
    public private(set) var occupant: Vehicle12?
    public init(id: String, size: VehicleSize) { self.id = id; self.size = size }
    public var isFree: Bool { occupant == nil }
    /// A vehicle fits a spot of its own size or larger.
    public func fits(_ v: Vehicle12) -> Bool { isFree && v.size <= size }
    fileprivate func occupy(_ v: Vehicle12) { occupant = v }
    fileprivate func vacate() { occupant = nil }
}

public struct ParkingTicket: Equatable {
    public let id: String
    public let plate: String
    public let spotID: String
    public let entry: Date
}

/// The stated variation axis: pricing changes, everything else doesn't.
public protocol ParkingPricing {
    var name: String { get }
    func fee(size: VehicleSize, hours: Int) -> Decimal
}

public struct HourlyParkingPricing: ParkingPricing {
    public let rates: [VehicleSize: Decimal]
    public init(rates: [VehicleSize: Decimal]) { self.rates = rates }
    public var name: String { "hourly" }
    public func fee(size: VehicleSize, hours: Int) -> Decimal {
        (rates[size] ?? 0) * Decimal(max(1, hours))     // minimum one hour
    }
}

public enum ParkingError: Error, Equatable { case full, unknownTicket, alreadyExited }

public final class ParkingLot {
    private var spots: [ParkingSpot]
    private var activeTickets: [String: ParkingTicket] = [:]
    private var pricing: any ParkingPricing
    private var nextTicket = 1

    public init(spots: [ParkingSpot], pricing: any ParkingPricing) {
        self.spots = spots
        self.pricing = pricing
    }

    public func setPricing(_ p: any ParkingPricing) { pricing = p }
    public var pricingName: String { pricing.name }

    public func availability(for size: VehicleSize) -> Int {
        spots.filter { $0.isFree && size <= $0.size }.count
    }

    /// Best-fit allocation: smallest spot that can hold the vehicle,
    /// so a motorcycle doesn't consume a truck bay.
    public func park(_ vehicle: Vehicle12, at entry: Date) throws -> ParkingTicket {
        guard let spot = spots.filter({ $0.fits(vehicle) }).min(by: { $0.size < $1.size }) else {
            throw ParkingError.full
        }
        spot.occupy(vehicle)
        let ticket = ParkingTicket(id: "T\(nextTicket)", plate: vehicle.plate, spotID: spot.id, entry: entry)
        nextTicket += 1
        activeTickets[ticket.id] = ticket
        return ticket
    }

    public func unpark(ticketID: String, at exit: Date) throws -> Decimal {
        guard let ticket = activeTickets[ticketID] else { throw ParkingError.unknownTicket }
        guard let spot = spots.first(where: { $0.id == ticket.spotID }), let vehicle = spot.occupant else {
            throw ParkingError.alreadyExited
        }
        let seconds = exit.timeIntervalSince(ticket.entry)
        let hours = Int(ceil(max(0, seconds) / 3600))
        let fee = pricing.fee(size: vehicle.size, hours: hours)
        spot.vacate()
        activeTickets[ticketID] = nil
        return fee
    }
}

// =====================================================================
// SOLVED 2 — ATM
// =====================================================================

public enum Note: Int, CaseIterable, Comparable, Hashable {
    case hundred = 100, fiveHundred = 500, twoThousand = 2000
    public static func < (a: Note, b: Note) -> Bool { a.rawValue < b.rawValue }
}

public enum ATMError: Error, Equatable {
    case cardNotRecognised, wrongPIN(attemptsLeft: Int), cardRetained
    case notAuthenticated, insufficientFunds, atmOutOfCash, cannotDispenseAmount
}

public protocol BankService {
    func balance(account: String) -> Decimal?
    func debit(account: String, amount: Decimal) -> Bool
}

public final class InMemoryBank: BankService {
    private var accounts: [String: Decimal]
    public init(accounts: [String: Decimal]) { self.accounts = accounts }
    public func balance(account: String) -> Decimal? { accounts[account] }
    public func debit(account: String, amount: Decimal) -> Bool {
        guard let b = accounts[account], b >= amount else { return false }
        accounts[account] = b - amount
        return true
    }
}

/// Session is the implied entity: the bracket around insert→eject.
public final class ATM {
    public enum State: Equatable { case idle, awaitingPIN, authenticated, cardRetained }
    public private(set) var state: State = .idle
    private var cash: [Note: Int]
    private let bank: any BankService
    private let pins: [String: String]
    private var currentCard: String?
    private var attempts = 0

    public init(cash: [Note: Int], bank: any BankService, pins: [String: String]) {
        self.cash = cash; self.bank = bank; self.pins = pins
    }

    public func insertCard(_ card: String) throws {
        guard pins[card] != nil else { throw ATMError.cardNotRecognised }
        currentCard = card
        attempts = 0
        state = .awaitingPIN
    }

    public func enterPIN(_ pin: String) throws {
        guard let card = currentCard, state == .awaitingPIN else { throw ATMError.notAuthenticated }
        if pins[card] == pin { state = .authenticated; return }
        attempts += 1
        if attempts >= 3 { state = .cardRetained; throw ATMError.cardRetained }
        throw ATMError.wrongPIN(attemptsLeft: 3 - attempts)
    }

    public func withdraw(_ amount: Decimal) throws -> [Note: Int] {
        guard state == .authenticated, let card = currentCard else { throw ATMError.notAuthenticated }
        guard let balance = bank.balance(account: card), balance >= amount else {
            throw ATMError.insufficientFunds
        }
        guard let plan = dispensePlan(for: amount) else { throw ATMError.cannotDispenseAmount }
        guard bank.debit(account: card, amount: amount) else { throw ATMError.insufficientFunds }
        for (note, count) in plan { cash[note]! -= count }     // commit only after the debit succeeds
        return plan
    }

    public func ejectCard() { currentCard = nil; attempts = 0; state = .idle }
    public func noteCount(_ note: Note) -> Int { cash[note] ?? 0 }

    /// Greedy, bounded by what's in the cassettes.
    private func dispensePlan(for amount: Decimal) -> [Note: Int]? {
        var remaining = NSDecimalNumber(decimal: amount).intValue
        guard remaining > 0 else { return nil }
        var plan: [Note: Int] = [:]
        for note in Note.allCases.sorted(by: >) {
            let wanted = remaining / note.rawValue
            let available = cash[note] ?? 0
            let used = min(wanted, available)
            if used > 0 { plan[note] = used; remaining -= used * note.rawValue }
        }
        return remaining == 0 ? plan : nil
    }
}

// =====================================================================
// SOLVED 3 — Splitwise
// =====================================================================

public enum SplitType: Equatable {
    case equal
    case exact([String: Decimal])      // userID -> amount
    case percentage([String: Decimal]) // userID -> percent
}

public struct Split: Equatable {
    public let userID: String
    public let amount: Decimal
}

public enum SplitError: Error, Equatable { case amountsDoNotSum, percentagesDoNotSum100, noParticipants }

public enum SplitCalculator {
    public static func splits(amount: Decimal, among users: [String], type: SplitType) throws -> [Split] {
        guard !users.isEmpty else { throw SplitError.noParticipants }
        switch type {
        case .equal:
            let each = amount / Decimal(users.count)
            return users.map { Split(userID: $0, amount: each) }
        case .exact(let map):
            let total = users.reduce(Decimal(0)) { $0 + (map[$1] ?? 0) }
            guard total == amount else { throw SplitError.amountsDoNotSum }
            return users.map { Split(userID: $0, amount: map[$0] ?? 0) }
        case .percentage(let map):
            let total = users.reduce(Decimal(0)) { $0 + (map[$1] ?? 0) }
            guard total == 100 else { throw SplitError.percentagesDoNotSum100 }
            return users.map { Split(userID: $0, amount: amount * (map[$0] ?? 0) / 100) }
        }
    }
}

public struct Expense: Equatable {
    public let id: String
    public let paidBy: String
    public let amount: Decimal
    public let splits: [Split]
}

/// Balances are DERIVED from the expense log, never stored — one source of truth.
public final class ExpenseGroup {
    public private(set) var expenses: [Expense] = []
    private var nextID = 1

    public init() {}

    @discardableResult
    public func addExpense(paidBy: String, amount: Decimal, among users: [String], type: SplitType) throws -> Expense {
        let splits = try SplitCalculator.splits(amount: amount, among: users, type: type)
        let expense = Expense(id: "E\(nextID)", paidBy: paidBy, amount: amount, splits: splits)
        nextID += 1
        expenses.append(expense)
        return expense
    }

    /// Net position per user: positive means they are owed money.
    public func balances() -> [String: Decimal] {
        var result: [String: Decimal] = [:]
        for e in expenses {
            result[e.paidBy, default: 0] += e.amount
            for s in e.splits { result[s.userID, default: 0] -= s.amount }
        }
        return result.filter { $0.value != 0 }
    }

    /// Greedy settlement: biggest creditor with biggest debtor, repeat.
    public func settlements() -> [(from: String, to: String, amount: Decimal)] {
        var creditors = balances().filter { $0.value > 0 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        var debtors = balances().filter { $0.value < 0 }.map { ($0.key, -$0.value) }.sorted { $0.1 > $1.1 }
        var result: [(from: String, to: String, amount: Decimal)] = []
        var i = 0, j = 0
        while i < debtors.count, j < creditors.count {
            let pay = min(debtors[i].1, creditors[j].1)
            result.append((from: debtors[i].0, to: creditors[j].0, amount: pay))
            debtors[i].1 -= pay
            creditors[j].1 -= pay
            if debtors[i].1 == 0 { i += 1 }
            if creditors[j].1 == 0 { j += 1 }
        }
        return result
    }
}

// =====================================================================
// SOLVED 4 — Rate Limiter (token bucket)
// =====================================================================

/// Token bucket beats fixed window: it smooths bursts instead of allowing 2× at a boundary.
public final class TokenBucketLimiter {
    private struct Bucket { var tokens: Double; var lastRefill: Double }
    private var buckets: [String: Bucket] = [:]
    private let capacity: Double
    private let refillPerSecond: Double
    private let now: () -> Double

    public init(capacity: Int, refillPerSecond: Double, now: @escaping () -> Double) {
        self.capacity = Double(capacity)
        self.refillPerSecond = refillPerSecond
        self.now = now
    }

    public func allow(_ clientID: String, cost: Double = 1) -> Bool {
        let t = now()
        var bucket = buckets[clientID] ?? Bucket(tokens: capacity, lastRefill: t)
        bucket.tokens = min(capacity, bucket.tokens + (t - bucket.lastRefill) * refillPerSecond)
        bucket.lastRefill = t
        guard bucket.tokens >= cost else { buckets[clientID] = bucket; return false }
        bucket.tokens -= cost
        buckets[clientID] = bucket
        return true
    }

    public func tokens(for clientID: String) -> Double {
        buckets[clientID]?.tokens ?? capacity
    }
}

// =====================================================================
// SOLVED 5 — Underground (metro) System
// =====================================================================

public enum UndergroundError: Error, Equatable { case alreadyCheckedIn, notCheckedIn }

public final class UndergroundSystem {
    private struct Trip { let start: String; let time: Double }
    private var inTransit: [String: Trip] = [:]                 // customerID -> trip
    private var totals: [String: (total: Double, count: Int)] = [:]   // "A->B" -> stats

    public init() {}

    public func checkIn(_ customerID: String, at station: String, time: Double) throws {
        guard inTransit[customerID] == nil else { throw UndergroundError.alreadyCheckedIn }
        inTransit[customerID] = Trip(start: station, time: time)
    }

    public func checkOut(_ customerID: String, at station: String, time: Double) throws {
        guard let trip = inTransit.removeValue(forKey: customerID) else { throw UndergroundError.notCheckedIn }
        let key = "\(trip.start)->\(station)"
        let current = totals[key] ?? (0, 0)
        totals[key] = (current.total + (time - trip.time), current.count + 1)
    }

    /// Running average, O(1) — storing every trip would be O(n) memory for no benefit.
    public func averageTime(from: String, to: String) -> Double? {
        guard let stats = totals["\(from)->\(to)"], stats.count > 0 else { return nil }
        return stats.total / Double(stats.count)
    }
}

// =====================================================================
// SOLVED 6 — Logging Framework
// =====================================================================

public enum LogLevel: Int, Comparable, CaseIterable {
    case debug = 0, info, warning, error
    public static func < (a: LogLevel, b: LogLevel) -> Bool { a.rawValue < b.rawValue }
    public var label: String { ["DEBUG", "INFO", "WARN", "ERROR"][rawValue] }
}

public struct LogRecord {
    public let level: LogLevel
    public let message: String
    public let timestamp: Double
}

public protocol LogSink {
    func write(_ record: LogRecord)
}

public final class MemorySink: LogSink {
    public private(set) var lines: [String] = []
    private let formatter: (LogRecord) -> String
    public init(formatter: @escaping (LogRecord) -> String = { "[\($0.level.label)] \($0.message)" }) {
        self.formatter = formatter
    }
    public func write(_ record: LogRecord) { lines.append(formatter(record)) }
}

/// Minimum level + fan-out to sinks. Sinks are the variation axis (console, file, network).
public final class Logger12 {
    public var minimumLevel: LogLevel
    private var sinks: [any LogSink]
    private let now: () -> Double

    public init(minimumLevel: LogLevel = .info, sinks: [any LogSink], now: @escaping () -> Double = { 0 }) {
        self.minimumLevel = minimumLevel
        self.sinks = sinks
        self.now = now
    }

    public func add(_ sink: any LogSink) { sinks.append(sink) }

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        guard level >= minimumLevel else { return }     // @autoclosure: message not built when filtered
        let record = LogRecord(level: level, message: message(), timestamp: now())
        sinks.forEach { $0.write(record) }
    }

    public func debug(_ m: @autoclosure () -> String) { log(.debug, m()) }
    public func info(_ m: @autoclosure () -> String) { log(.info, m()) }
    public func warning(_ m: @autoclosure () -> String) { log(.warning, m()) }
    public func error(_ m: @autoclosure () -> String) { log(.error, m()) }
}

// =====================================================================
// SOLVED 7 — Library Management
// =====================================================================

public struct Book: Equatable {
    public let isbn: String
    public let title: String
    public let author: String
}

public enum CopyState: Equatable { case available, onLoan(memberID: String, due: Double), lost }

public final class BookCopy {
    public let id: String
    public let isbn: String
    public private(set) var state: CopyState = .available
    public init(id: String, isbn: String) { self.id = id; self.isbn = isbn }
    fileprivate func set(_ s: CopyState) { state = s }
}

public enum LibraryError: Error, Equatable {
    case unknownCopy, copyUnavailable, limitReached, notOnLoan, copyIsLost
}

public final class Library {
    public let loanPeriod: Double
    public let maxLoans: Int
    private var books: [String: Book] = [:]
    private var copies: [String: BookCopy] = [:]

    public init(books: [Book], copies: [BookCopy], loanPeriod: Double = 14, maxLoans: Int = 3) {
        for b in books { self.books[b.isbn] = b }
        for c in copies { self.copies[c.id] = c }
        self.loanPeriod = loanPeriod
        self.maxLoans = maxLoans
    }

    public func loanCount(for memberID: String) -> Int {
        copies.values.filter {
            if case .onLoan(let m, _) = $0.state { return m == memberID }
            return false
        }.count
    }

    public func borrow(copyID: String, memberID: String, now: Double) throws {
        guard let copy = copies[copyID] else { throw LibraryError.unknownCopy }
        if case .lost = copy.state { throw LibraryError.copyIsLost }
        guard case .available = copy.state else { throw LibraryError.copyUnavailable }
        guard loanCount(for: memberID) < maxLoans else { throw LibraryError.limitReached }
        copy.set(.onLoan(memberID: memberID, due: now + loanPeriod))
    }

    public func returnCopy(copyID: String) throws {
        guard let copy = copies[copyID] else { throw LibraryError.unknownCopy }
        guard case .onLoan = copy.state else { throw LibraryError.notOnLoan }
        copy.set(.available)
    }

    public func markLost(copyID: String) throws {
        guard let copy = copies[copyID] else { throw LibraryError.unknownCopy }
        copy.set(.lost)
    }

    public func overdueCopies(for memberID: String, asOf now: Double) -> [String] {
        copies.values.compactMap { copy in
            guard case .onLoan(let m, let due) = copy.state, m == memberID, due < now else { return nil }
            return copy.id
        }.sorted()
    }

    public func search(author: String? = nil, titleContains: String? = nil) -> [Book] {
        books.values.filter { book in
            (author.map { book.author.lowercased() == $0.lowercased() } ?? true) &&
            (titleContains.map { book.title.lowercased().contains($0.lowercased()) } ?? true)
        }.sorted { $0.isbn < $1.isbn }
    }
}

// =====================================================================
// SOLVED 8 — Hotel Management (interval booking)
// =====================================================================

public struct DateRange: Equatable {
    public let start: Int      // day number, inclusive
    public let end: Int        // day number, exclusive (checkout day)
    public init(start: Int, end: Int) { self.start = start; self.end = end }
    public var nights: Int { max(0, end - start) }
    /// Half-open intervals: [1,3) and [3,5) do NOT overlap — the checkout/checkin day is shared.
    public func overlaps(_ other: DateRange) -> Bool { start < other.end && other.start < end }
}

public enum RoomType: String, CaseIterable, Equatable { case single, double, suite }

public struct Booking: Equatable {
    public let id: String
    public let roomID: String
    public let guestID: String
    public let range: DateRange
    public let total: Decimal
}

public enum HotelError: Error, Equatable { case noRoomAvailable, unknownBooking, invalidRange }

public final class Hotel {
    private let rooms: [String: RoomType]
    private let nightlyRate: [RoomType: Decimal]
    private var bookings: [String: Booking] = [:]
    private var nextID = 1

    public init(rooms: [String: RoomType], nightlyRate: [RoomType: Decimal]) {
        self.rooms = rooms
        self.nightlyRate = nightlyRate
    }

    public func availableRooms(type: RoomType, range: DateRange) -> [String] {
        rooms.filter { $0.value == type }
            .map(\.key)
            .filter { roomID in
                !bookings.values.contains { $0.roomID == roomID && $0.range.overlaps(range) }
            }
            .sorted()
    }

    public func book(guestID: String, type: RoomType, range: DateRange) throws -> Booking {
        guard range.nights > 0 else { throw HotelError.invalidRange }
        guard let roomID = availableRooms(type: type, range: range).first else {
            throw HotelError.noRoomAvailable
        }
        let total = (nightlyRate[type] ?? 0) * Decimal(range.nights)
        let booking = Booking(id: "B\(nextID)", roomID: roomID, guestID: guestID, range: range, total: total)
        nextID += 1
        bookings[booking.id] = booking
        return booking
    }

    public func cancel(bookingID: String) throws {
        guard bookings.removeValue(forKey: bookingID) != nil else { throw HotelError.unknownBooking }
    }

    public func occupancy(on day: Int) -> Int {
        bookings.values.filter { $0.range.start <= day && day < $0.range.end }.count
    }
}

// =====================================================================
// Demo
// =====================================================================

public enum M12Demo {
    public static func run() {
        // Parking lot
        let lot = ParkingLot(
            spots: [ParkingSpot(id: "M1", size: .motorcycle),
                    ParkingSpot(id: "C1", size: .car),
                    ParkingSpot(id: "T1", size: .truck)],
            pricing: HourlyParkingPricing(rates: [.motorcycle: 20, .car: 50, .truck: 100]))
        let t0 = Date(timeIntervalSince1970: 0)
        let ticket = try! lot.park(Vehicle12(plate: "KA01", size: .car), at: t0)
        print("Parking: spot", ticket.spotID, "free car spots now", lot.availability(for: .car))
        print("Parking fee 3h:", try! lot.unpark(ticketID: ticket.id, at: t0.addingTimeInterval(3 * 3600)))

        // ATM
        let atm = ATM(cash: [.twoThousand: 2, .fiveHundred: 4, .hundred: 10],
                      bank: InMemoryBank(accounts: ["card1": 10_000]),
                      pins: ["card1": "1234"])
        try! atm.insertCard("card1")
        try! atm.enterPIN("1234")
        print("ATM dispensed:", try! atm.withdraw(2600).map { "\($0.value)×\($0.key.rawValue)" }.sorted())
        atm.ejectCard()

        // Splitwise
        let group = ExpenseGroup()
        try! group.addExpense(paidBy: "amy", amount: 300, among: ["amy", "bob", "cat"], type: .equal)
        try! group.addExpense(paidBy: "bob", amount: 90, among: ["amy", "bob"], type: .equal)
        print("Splitwise balances:", group.balances().sorted { $0.key < $1.key })
        print("Splitwise settlements:", group.settlements())

        // Rate limiter
        var clock = 0.0
        let limiter = TokenBucketLimiter(capacity: 3, refillPerSecond: 1, now: { clock })
        print("RateLimiter:", (0..<5).map { _ in limiter.allow("u1") })
        clock += 2
        print("RateLimiter after 2s:", limiter.allow("u1"), limiter.allow("u1"), limiter.allow("u1"))

        // Underground
        let metro = UndergroundSystem()
        try! metro.checkIn("u1", at: "Indiranagar", time: 0)
        try! metro.checkOut("u1", at: "MGRoad", time: 12)
        try! metro.checkIn("u2", at: "Indiranagar", time: 5)
        try! metro.checkOut("u2", at: "MGRoad", time: 21)
        print("Metro avg:", metro.averageTime(from: "Indiranagar", to: "MGRoad") as Any)

        // Logging
        let sink = MemorySink()
        let logger = Logger12(minimumLevel: .warning, sinks: [sink])
        logger.debug("not emitted")
        logger.error("disk full")
        print("Logger:", sink.lines)

        // Library
        let library = Library(books: [Book(isbn: "1", title: "Clean Code", author: "Martin")],
                              copies: [BookCopy(id: "c1", isbn: "1"), BookCopy(id: "c2", isbn: "1")])
        try! library.borrow(copyID: "c1", memberID: "m1", now: 0)
        print("Library overdue at day 20:", library.overdueCopies(for: "m1", asOf: 20))

        // Hotel
        let hotel = Hotel(rooms: ["101": .single, "102": .single], nightlyRate: [.single: 2_000])
        let b1 = try! hotel.book(guestID: "g1", type: .single, range: DateRange(start: 1, end: 4))
        print("Hotel booking:", b1.roomID, b1.total, "available 2-3:",
              hotel.availableRooms(type: .single, range: DateRange(start: 2, end: 3)))
    }
}
