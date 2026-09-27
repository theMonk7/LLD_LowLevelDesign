//  Module 13 — SOLVED problems.
//
//  HOW TO READ THIS FILE
//  At this size, notice what is NOT here as much as what is: castling, capacity
//  limits, persistence, notifications. Each omission was a decision, and in an
//  interview each would be said out loud. A coherent 40% beats an incoherent 80%.
//
//  The shapes to extract, because they repeat across every hard problem:
//    POLICY vs MECHANISM   how a car moves is separate from which car is chosen
//    TWO-LAYER VALIDATION  "can the piece move there?" then "does it expose my
//                          king?" — one rule set, reused for three questions
//    THREE-STATE RESOURCES free / held-by-someone-until / taken. Two states cannot
//                          express "someone is in the middle of taking it"
//    LAZY EXPIRY           a hold is checked against the clock when READ, so
//                          correctness does not depend on a sweeper running
//    TRANSITION TABLES     the whole lifecycle readable in one place
//
//  Everything here compiles and is exercised by M13Demo.run().

import Foundation

// =====================================================================
// SOLVED 1 — Elevator System
// =====================================================================

public enum Direction: Equatable { case up, down, idle }

public struct ElevatorRequest: Equatable {
    public let floor: Int
    public let direction: Direction      // .idle for an inside-the-car request
    public init(floor: Int, direction: Direction) { self.floor = floor; self.direction = direction }
}

public enum DoorState: Equatable { case open, closed }

public final class Elevator {
    public let id: String
    public private(set) var currentFloor: Int
    public private(set) var direction: Direction = .idle
    public private(set) var door: DoorState = .closed
    /// Floors this car must still visit.
    public private(set) var stops: Set<Int> = []

    public init(id: String, currentFloor: Int = 0) { self.id = id; self.currentFloor = currentFloor }

    public func addStop(_ floor: Int) {
        guard floor != currentFloor || door == .closed else { return }
        stops.insert(floor)
        updateDirection()
    }

    /// One simulation tick: move a floor, or open the doors if this is a stop.
    @discardableResult
    public func step() -> String {
        if door == .open { door = .closed; return "\(id) doors closed at \(currentFloor)" }
        if stops.contains(currentFloor) {
            stops.remove(currentFloor)
            door = .open
            updateDirection()
            return "\(id) doors open at \(currentFloor)"
        }
        guard direction != .idle else { return "\(id) idle at \(currentFloor)" }
        currentFloor += (direction == .up ? 1 : -1)
        if stops.contains(currentFloor) {
            stops.remove(currentFloor)
            door = .open
            updateDirection()
            return "\(id) doors open at \(currentFloor)"
        }
        updateDirection()
        return "\(id) at \(currentFloor) going \(direction == .up ? "up" : "down")"
    }

    private func updateDirection() {
        if stops.isEmpty { direction = .idle; return }
        let above = stops.contains { $0 > currentFloor }
        let below = stops.contains { $0 < currentFloor }
        switch direction {
        case .up:   direction = above ? .up : (below ? .down : .idle)
        case .down: direction = below ? .down : (above ? .up : .idle)
        case .idle: direction = above ? .up : .down
        }
    }
}

/// The variation axis: dispatch policy. Nearest-car here; SCAN/LOOK or
/// destination-dispatch would be different conformers.
public protocol ElevatorDispatchPolicy {
    var name: String { get }
    func select(_ elevators: [Elevator], for request: ElevatorRequest) -> Elevator?
}

public struct NearestCarPolicy: ElevatorDispatchPolicy {
    public init() {}
    public var name: String { "nearest-car" }
    public func select(_ elevators: [Elevator], for request: ElevatorRequest) -> Elevator? {
        // Prefer idle cars, then cars already heading toward the request, then anything.
        func score(_ e: Elevator) -> (Int, Int) {
            let distance = abs(e.currentFloor - request.floor)
            let movingToward = (e.direction == .up && request.floor >= e.currentFloor)
                || (e.direction == .down && request.floor <= e.currentFloor)
            let tier = e.direction == .idle ? 0 : (movingToward ? 1 : 2)
            return (tier, distance)
        }
        return elevators.min { a, b in score(a) < score(b) }
    }
}

public final class ElevatorBank {
    public private(set) var elevators: [Elevator]
    private var policy: any ElevatorDispatchPolicy

    public init(elevators: [Elevator], policy: any ElevatorDispatchPolicy) {
        self.elevators = elevators
        self.policy = policy
    }

    public func setPolicy(_ p: any ElevatorDispatchPolicy) { policy = p }

    @discardableResult
    public func request(_ r: ElevatorRequest) -> Elevator? {
        guard let chosen = policy.select(elevators, for: r) else { return nil }
        chosen.addStop(r.floor)
        return chosen
    }

    public func step() -> [String] { elevators.map { $0.step() } }
}

// =====================================================================
// SOLVED 2 — Chess (core rules; castling/en-passant/promotion out of scope)
// =====================================================================

public enum PieceColor: Equatable { case white, black }
public enum PieceKind: Equatable { case pawn, knight, bishop, rook, queen, king }

public struct Square: Hashable, CustomStringConvertible {
    public let file: Int      // 0...7 = a...h
    public let rank: Int      // 0...7 = 1...8
    public init(file: Int, rank: Int) { self.file = file; self.rank = rank }
    public init?(_ algebraic: String) {
        let chars = Array(algebraic.lowercased())
        guard chars.count == 2,
              let f = chars[0].asciiValue.map({ Int($0) - 97 }),
              let r = chars[1].wholeNumberValue.map({ $0 - 1 }),
              (0...7).contains(f), (0...7).contains(r) else { return nil }
        self.file = f; self.rank = r
    }
    public var description: String { "\(Character(UnicodeScalar(97 + file)!))\(rank + 1)" }
    public var isOnBoard: Bool { (0...7).contains(file) && (0...7).contains(rank) }
}

public struct Piece: Equatable {
    public let kind: PieceKind
    public let color: PieceColor
    public init(kind: PieceKind, color: PieceColor) { self.kind = kind; self.color = color }
}

public enum ChessError: Error, Equatable {
    case noPieceThere, notYourPiece, illegalMove, wouldLeaveKingInCheck, gameOver
}

public final class ChessGame {
    private var board: [Square: Piece] = [:]
    public private(set) var turn: PieceColor = .white
    public private(set) var isOver = false

    public init(standardSetup: Bool = true) {
        guard standardSetup else { return }
        let backRank: [PieceKind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0...7 {
            board[Square(file: file, rank: 0)] = Piece(kind: backRank[file], color: .white)
            board[Square(file: file, rank: 1)] = Piece(kind: .pawn, color: .white)
            board[Square(file: file, rank: 6)] = Piece(kind: .pawn, color: .black)
            board[Square(file: file, rank: 7)] = Piece(kind: backRank[file], color: .black)
        }
    }

    public func place(_ piece: Piece, at square: Square) { board[square] = piece }
    public func piece(at square: Square) -> Piece? { board[square] }
    public func clear() { board.removeAll() }

    public func move(from: Square, to: Square) throws {
        guard !isOver else { throw ChessError.gameOver }
        guard let piece = board[from] else { throw ChessError.noPieceThere }
        guard piece.color == turn else { throw ChessError.notYourPiece }
        guard isPseudoLegal(piece, from: from, to: to) else { throw ChessError.illegalMove }

        // Simulate, then verify the mover's king is not left in check.
        let captured = board[to]
        board[to] = piece
        board[from] = nil
        if isInCheck(piece.color) {
            board[from] = piece
            board[to] = captured
            throw ChessError.wouldLeaveKingInCheck
        }
        if captured?.kind == .king { isOver = true }
        turn = (turn == .white) ? .black : .white
    }

    public func isInCheck(_ color: PieceColor) -> Bool {
        guard let kingSquare = board.first(where: { $0.value == Piece(kind: .king, color: color) })?.key
        else { return false }
        return board.contains { entry in
            entry.value.color != color && isPseudoLegal(entry.value, from: entry.key, to: kingSquare)
        }
    }

    /// Movement rules only — does not consider whether the move exposes the king.
    private func isPseudoLegal(_ piece: Piece, from: Square, to: Square) -> Bool {
        guard to.isOnBoard, from != to else { return false }
        if let occupant = board[to], occupant.color == piece.color { return false }

        let df = to.file - from.file
        let dr = to.rank - from.rank

        switch piece.kind {
        case .knight:
            return (abs(df), abs(dr)) == (1, 2) || (abs(df), abs(dr)) == (2, 1)
        case .king:
            return abs(df) <= 1 && abs(dr) <= 1
        case .rook:
            return (df == 0 || dr == 0) && isPathClear(from: from, to: to)
        case .bishop:
            return abs(df) == abs(dr) && isPathClear(from: from, to: to)
        case .queen:
            return (df == 0 || dr == 0 || abs(df) == abs(dr)) && isPathClear(from: from, to: to)
        case .pawn:
            let forward = piece.color == .white ? 1 : -1
            let startRank = piece.color == .white ? 1 : 6
            if df == 0, dr == forward, board[to] == nil { return true }
            if df == 0, dr == 2 * forward, from.rank == startRank,
               board[to] == nil, board[Square(file: from.file, rank: from.rank + forward)] == nil { return true }
            if abs(df) == 1, dr == forward, board[to] != nil { return true }     // capture
            return false
        }
    }

    private func isPathClear(from: Square, to: Square) -> Bool {
        let stepFile = (to.file - from.file).signum()
        let stepRank = (to.rank - from.rank).signum()
        var file = from.file + stepFile, rank = from.rank + stepRank
        while file != to.file || rank != to.rank {
            if board[Square(file: file, rank: rank)] != nil { return false }
            file += stepFile; rank += stepRank
        }
        return true
    }
}

// =====================================================================
// SOLVED 3 — BookMyShow (show, seats, hold-then-pay)
// =====================================================================

public enum SeatKind: String, Equatable, CaseIterable { case regular, premium, recliner }

public struct Seat: Equatable, Hashable {
    public let id: String            // "A1"
    public let kind: SeatKind
    public init(id: String, kind: SeatKind) { self.id = id; self.kind = kind }
}

public enum SeatStatus: Equatable { case free, held(until: Double, by: String), booked(by: String) }

public enum BookingError13: Error, Equatable {
    case unknownSeat, seatUnavailable, holdExpired, notHeldByYou, paymentFailed
}

/// Hold → pay → confirm, with a TTL so a crashed client can't lock seats forever.
public final class Show {
    public let id: String
    public let startsAt: Double
    private var statuses: [String: SeatStatus] = [:]
    private var seats: [String: Seat] = [:]
    private let holdSeconds: Double
    private let pricing: [SeatKind: Decimal]

    public init(id: String, startsAt: Double, seats: [Seat], pricing: [SeatKind: Decimal], holdSeconds: Double = 300) {
        self.id = id
        self.startsAt = startsAt
        self.holdSeconds = holdSeconds
        self.pricing = pricing
        for s in seats { self.seats[s.id] = s; statuses[s.id] = .free }
    }

    public func status(of seatID: String, now: Double) -> SeatStatus? {
        guard let status = statuses[seatID] else { return nil }
        if case .held(let until, _) = status, until <= now { return .free }   // lazily expired
        return status
    }

    public func availableSeats(now: Double) -> [String] {
        statuses.keys.filter { status(of: $0, now: now) == .free }.sorted()
    }

    /// Atomic for the whole set: either every seat is held, or none is.
    public func hold(_ seatIDs: [String], by userID: String, now: Double) throws {
        for id in seatIDs {
            guard let s = status(of: id, now: now) else { throw BookingError13.unknownSeat }
            guard s == .free else { throw BookingError13.seatUnavailable }
        }
        for id in seatIDs { statuses[id] = .held(until: now + holdSeconds, by: userID) }
    }

    public func release(_ seatIDs: [String], by userID: String, now: Double) {
        for id in seatIDs {
            if case .held(_, let holder) = statuses[id], holder == userID { statuses[id] = .free }
        }
    }

    public func price(of seatIDs: [String]) -> Decimal {
        seatIDs.reduce(0) { $0 + (seats[$1].map { pricing[$0.kind] ?? 0 } ?? 0) }
    }

    /// Confirms a hold into a booking. Fails if the hold expired or belongs to someone else.
    public func confirm(_ seatIDs: [String], by userID: String, now: Double) throws {
        for id in seatIDs {
            guard let raw = statuses[id] else { throw BookingError13.unknownSeat }
            guard case .held(let until, let holder) = raw else { throw BookingError13.notHeldByYou }
            guard holder == userID else { throw BookingError13.notHeldByYou }
            guard until > now else { throw BookingError13.holdExpired }
        }
        for id in seatIDs { statuses[id] = .booked(by: userID) }
    }
}

public struct BookingFlow13 {
    private let show: Show
    private let charge: (Decimal) -> Bool
    public init(show: Show, charge: @escaping (Decimal) -> Bool) { self.show = show; self.charge = charge }

    /// hold → charge → confirm, releasing the hold if the payment fails.
    public func book(_ seatIDs: [String], user: String, now: Double) throws -> Decimal {
        try show.hold(seatIDs, by: user, now: now)
        let amount = show.price(of: seatIDs)
        guard charge(amount) else {
            show.release(seatIDs, by: user, now: now)
            throw BookingError13.paymentFailed
        }
        try show.confirm(seatIDs, by: user, now: now)
        return amount
    }
}

// =====================================================================
// SOLVED 4 — Food Delivery order lifecycle
// =====================================================================

public enum OrderState: Equatable {
    case placed, accepted, preparing, readyForPickup, pickedUp, delivered
    case cancelled(reason: String), rejected(reason: String)
}

public enum OrderError: Error, Equatable { case illegalTransition, cancellationWindowClosed, noPartner }

public struct OrderItem: Equatable {
    public let name: String
    public let unitPrice: Decimal        // snapshotted at order time
    public let quantity: Int
    public init(name: String, unitPrice: Decimal, quantity: Int) {
        self.name = name; self.unitPrice = unitPrice; self.quantity = quantity
    }
    public var subtotal: Decimal { unitPrice * Decimal(quantity) }
}

public final class FoodOrder {
    public let id: String
    public let items: [OrderItem]
    public private(set) var state: OrderState = .placed
    public private(set) var partnerID: String?
    public private(set) var history: [OrderState] = [.placed]

    public init(id: String, items: [OrderItem]) { self.id = id; self.items = items }

    public var total: Decimal { items.reduce(0) { $0 + $1.subtotal } }

    private static let allowed: [String: Set<String>] = [
        "placed": ["accepted", "rejected", "cancelled"],
        "accepted": ["preparing", "cancelled"],
        "preparing": ["readyForPickup"],
        "readyForPickup": ["pickedUp"],
        "pickedUp": ["delivered"],
    ]

    private func key(_ s: OrderState) -> String {
        switch s {
        case .placed: "placed"; case .accepted: "accepted"; case .preparing: "preparing"
        case .readyForPickup: "readyForPickup"; case .pickedUp: "pickedUp"; case .delivered: "delivered"
        case .cancelled: "cancelled"; case .rejected: "rejected"
        }
    }

    public func transition(to next: OrderState) throws {
        guard Self.allowed[key(state)]?.contains(key(next)) == true else {
            throw OrderError.illegalTransition
        }
        state = next
        history.append(next)
    }

    /// Free cancellation only before the restaurant accepts.
    public func cancelByCustomer(reason: String) throws {
        guard state == .placed else { throw OrderError.cancellationWindowClosed }
        try transition(to: .cancelled(reason: reason))
    }

    public func assign(partnerID: String) throws {
        guard state == .preparing || state == .readyForPickup else { throw OrderError.illegalTransition }
        self.partnerID = partnerID
    }
}

// =====================================================================
// SOLVED 5 — Inventory with reservations
// =====================================================================

public enum InventoryError13: Error, Equatable { case unknownSKU, insufficientStock, unknownReservation }

/// available = onHand − reserved. Orders reserve, then commit or release.
public final class InventoryService {
    private struct Line { var onHand: Int; var reserved: Int }
    private var lines: [String: Line] = [:]
    private var reservations: [String: [String: Int]] = [:]     // reservationID -> sku -> qty

    public init(stock: [String: Int]) {
        for (sku, qty) in stock { lines[sku] = Line(onHand: qty, reserved: 0) }
    }

    public func onHand(_ sku: String) -> Int { lines[sku]?.onHand ?? 0 }
    public func available(_ sku: String) -> Int {
        guard let l = lines[sku] else { return 0 }
        return l.onHand - l.reserved
    }

    /// All-or-nothing across every SKU in the request.
    public func reserve(_ request: [String: Int], reservationID: String) throws {
        if reservations[reservationID] != nil { return }          // idempotent
        for (sku, qty) in request {
            guard lines[sku] != nil else { throw InventoryError13.unknownSKU }
            guard available(sku) >= qty else { throw InventoryError13.insufficientStock }
        }
        for (sku, qty) in request { lines[sku]?.reserved += qty }
        reservations[reservationID] = request
    }

    /// Turns a reservation into a real stock decrement.
    public func commit(reservationID: String) throws {
        guard let request = reservations.removeValue(forKey: reservationID) else {
            throw InventoryError13.unknownReservation
        }
        for (sku, qty) in request {
            lines[sku]?.reserved -= qty
            lines[sku]?.onHand -= qty
        }
    }

    public func release(reservationID: String) {
        guard let request = reservations.removeValue(forKey: reservationID) else { return }
        for (sku, qty) in request { lines[sku]?.reserved -= qty }
    }
}

// =====================================================================
// Demo
// =====================================================================

public enum M13Demo {
    public static func run() {
        // Elevator
        let bank = ElevatorBank(elevators: [Elevator(id: "E1", currentFloor: 0),
                                            Elevator(id: "E2", currentFloor: 8)],
                                policy: NearestCarPolicy())
        let chosen = bank.request(ElevatorRequest(floor: 7, direction: .down))
        print("Elevator chosen:", chosen?.id ?? "none")
        for _ in 0..<3 { print("  ", bank.step().joined(separator: " | ")) }

        // Chess
        let chess = ChessGame()
        try? chess.move(from: Square("e2")!, to: Square("e4")!)
        try? chess.move(from: Square("e7")!, to: Square("e5")!)
        try? chess.move(from: Square("g1")!, to: Square("f3")!)
        print("Chess: knight on f3 =", chess.piece(at: Square("f3")!) as Any, "turn:", chess.turn)

        // BookMyShow
        let show = Show(id: "S1", startsAt: 1_000,
                        seats: [Seat(id: "A1", kind: .premium), Seat(id: "A2", kind: .regular)],
                        pricing: [.premium: 400, .regular: 250], holdSeconds: 300)
        let flow = BookingFlow13(show: show, charge: { _ in true })
        print("BMS paid:", (try? flow.book(["A1", "A2"], user: "u1", now: 0)) as Any,
              "available:", show.availableSeats(now: 0))

        // Food delivery
        let order = FoodOrder(id: "O1", items: [OrderItem(name: "Biryani", unitPrice: 320, quantity: 2)])
        try? order.transition(to: .accepted)
        try? order.transition(to: .preparing)
        try? order.assign(partnerID: "P9")
        print("Order total:", order.total, "state:", order.state, "partner:", order.partnerID ?? "-")

        // Inventory
        let inventory = InventoryService(stock: ["sku1": 10, "sku2": 2])
        try? inventory.reserve(["sku1": 3, "sku2": 2], reservationID: "r1")
        print("Inventory available sku2:", inventory.available("sku2"), "onHand:", inventory.onHand("sku2"))
        try? inventory.commit(reservationID: "r1")
        print("After commit onHand sku1:", inventory.onHand("sku1"))
    }
}
