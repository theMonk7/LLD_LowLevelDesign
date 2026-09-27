//  Module 11 — SOLO problem reference solutions.
//
//  HOW TO READ THIS FILE
//  Small problems are DIAGNOSTIC: everyone can make them work, so what is being
//  measured is how. The comments therefore flag the habits, not the algorithms:
//    - the rule lives in the type, not in the caller
//    - validate everything, then mutate
//    - the data structure is derived from the OPERATION LIST
//    - unpredictable inputs (randomness, time) are injected
//    - after a change, check only what could have become true
//
//  Not part of the M11 target.

import Foundation

// MARK: - SOLO 1 Deck

public enum Suit: String, CaseIterable, Equatable { case clubs, diamonds, hearts, spades }

public enum Rank: Int, CaseIterable, Equatable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace
    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }
    var name: String {
        switch self {
        case .two: "two"; case .three: "three"; case .four: "four"; case .five: "five"
        case .six: "six"; case .seven: "seven"; case .eight: "eight"; case .nine: "nine"
        case .ten: "ten"; case .jack: "jack"; case .queen: "queen"; case .king: "king"; case .ace: "ace"
        }
    }
}

public struct Card: Equatable, Hashable, CustomStringConvertible {
    public let rank: Rank
    public let suit: Suit
    public init(rank: Rank, suit: Suit) { self.rank = rank; self.suit = suit }
    public var description: String { "\(rank.name) of \(suit.rawValue)" }
}

public final class Deck {
    private var cards: [Card] = []
    private let rng: (Int) -> Int

    public init(rng: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) {
        self.rng = rng
        reset()
    }

    public var remaining: Int { cards.count }

    // Fisher-Yates, and the direction matters. The common wrong version calls
    // rng(count) on every iteration — that is the "naive shuffle", and it is
    // BIASED: it does not produce every permutation with equal probability.
    // Walking downward with rng(i + 1) does.
    //
    // `rng` is injected so the grader can pass an identity generator and assert the
    // deck is unchanged. You cannot test a shuffle you do not control.
    public func shuffle() {
        guard cards.count > 1 else { return }
        for i in stride(from: cards.count - 1, through: 1, by: -1) {
            let j = rng(i + 1)
            cards.swapAt(i, j)
        }
    }

    // `popLast()`, not `removeFirst()`. Removing from the front of an array is
    // O(n); the "top of the deck" is the END of the array. The physical metaphor
    // and the efficient implementation agree — but only because the representation
    // was chosen deliberately.
    public func deal() -> Card? { cards.popLast() }

    public func deal(_ count: Int) -> [Card] {
        (0..<count).compactMap { _ in deal() }
    }

    public func reset() {
        cards = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
    }
}

// MARK: - SOLO 2 Connect Four

public enum Disc: String, Equatable { case red = "R", yellow = "Y" }

public enum ConnectFourResult: Equatable { case inProgress, win(Disc), draw }

public enum ConnectFourError: Error, Equatable {
    case columnOutOfRange, columnFull, gameOver, notYourTurn
}

public final class ConnectFour {
    public let rows: Int
    public let columns: Int
    public private(set) var current: Disc = .red
    public private(set) var result: ConnectFourResult = .inProgress
    private var grid: [[Disc?]]          // grid[column][row], row 0 = bottom
    private var placed = 0

    public init(rows: Int = 6, columns: Int = 7) {
        self.rows = rows
        self.columns = columns
        self.grid = Array(repeating: Array(repeating: nil, count: rows), count: columns)
    }

    public func disc(atRow row: Int, column: Int) -> Disc? {
        guard (0..<rows).contains(row), (0..<columns).contains(column) else { return nil }
        return grid[column][row]
    }

    @discardableResult
    public func drop(_ disc: Disc, into column: Int) throws -> Int {
        guard result == .inProgress else { throw ConnectFourError.gameOver }
        guard disc == current else { throw ConnectFourError.notYourTurn }
        guard (0..<columns).contains(column) else { throw ConnectFourError.columnOutOfRange }
        // Gravity in one line: the disc lands in the lowest empty row. Storing
        // grid[column][row] (column-major) rather than grid[row][column] is what
        // makes this natural — the representation follows the access pattern.
        guard let row = grid[column].firstIndex(where: { $0 == nil }) else { throw ConnectFourError.columnFull }

        grid[column][row] = disc
        placed += 1

        if wins(disc, row: row, column: column) {
            result = .win(disc)
        } else if placed == rows * columns {
            result = .draw
        } else {
            current = (disc == .red) ? .yellow : .red
        }
        return row
    }

    /// Only lines through the last disc can be new wins: 4 directions, count both ways.
    // Only lines THROUGH THE LAST DISC can be newly complete, so this is O(1) per
    // move instead of scanning 42 cells. Four directions, each counted BOTH WAYS,
    // so a disc dropped into the middle of a run is still detected — eight
    // separate direction checks would double the code for the same answer.
    //
    // The transferable instinct: after a change, ask what could possibly have
    // become true, and check only that.
    private func wins(_ disc: Disc, row: Int, column: Int) -> Bool {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]      // (dCol, dRow)
        for (dc, dr) in directions {
            var total = 1
            total += run(disc, from: (column, row), step: (dc, dr))
            total += run(disc, from: (column, row), step: (-dc, -dr))
            if total >= 4 { return true }
        }
        return false
    }

    private func run(_ disc: Disc, from start: (Int, Int), step: (Int, Int)) -> Int {
        var c = start.0 + step.0, r = start.1 + step.1, n = 0
        while (0..<columns).contains(c), (0..<rows).contains(r), grid[c][r] == disc {
            n += 1; c += step.0; r += step.1
        }
        return n
    }
}

// MARK: - SOLO 3 Ring Buffer

public enum RingBufferError: Error, Equatable { case full }

// WHY does `count` exist when we already have head and tail?
// Because `head == tail` is AMBIGUOUS: it is true when the buffer is empty and
// also when it is full. The alternatives are to keep a count (chosen here, and
// clearest) or to waste one slot. Naming the ambiguity is the interview point.
//
// `elements` walks (head + i) % capacity — that is what makes the wrap-around
// test pass. Returning `storage.compactMap { $0 }` gives you STORAGE order, not
// queue order, and the bug only appears after a wrap.
public struct RingBuffer<Element> {
    private var storage: [Element?]
    private var head = 0
    private var tail = 0
    public private(set) var count = 0
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = Array(repeating: nil, count: max(1, capacity))
    }

    public var isEmpty: Bool { count == 0 }
    public var isFull: Bool { count == capacity }
    public var peek: Element? { isEmpty ? nil : storage[head] }

    public mutating func enqueue(_ element: Element) throws {
        guard !isFull else { throw RingBufferError.full }
        storage[tail] = element
        tail = (tail + 1) % capacity
        count += 1
    }

    @discardableResult
    public mutating func enqueueOverwriting(_ element: Element) -> Element? {
        var dropped: Element?
        if isFull { dropped = dequeue() }
        try? enqueue(element)
        return dropped
    }

    public mutating func dequeue() -> Element? {
        guard !isEmpty else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % capacity
        count -= 1
        return element
    }

    public var elements: [Element] {
        (0..<count).compactMap { storage[(head + $0) % capacity] }
    }
}

// MARK: - SOLO 4 Autocomplete

public final class Autocomplete {
    private final class Node {
        var children: [Character: Node] = [:]
        var frequency: Int?
    }
    private let root = Node()
    private var distinctWords = 0

    public init() {}

    public func insert(_ word: String, frequency: Int) {
        var node = root
        for ch in word {
            if let next = node.children[ch] { node = next }
            else { let fresh = Node(); node.children[ch] = fresh; node = fresh }
        }
        if node.frequency == nil { distinctWords += 1 }
        node.frequency = frequency
    }

    public func suggest(prefix: String, limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        var node = root
        for ch in prefix {
            guard let next = node.children[ch] else { return [] }
            node = next
        }
        var found: [(word: String, frequency: Int)] = []
        collect(node, current: prefix, into: &found)
        // The alphabetical tie-break is not decoration. "Sort by frequency" alone
        // leaves equal-frequency words in an unstable order, which produces a
        // suggestion list that RESHUFFLES between keystrokes — a real bug that
        // starts as a missing comparator.
        //
        // Design note: this collects the subtree then sorts, O(m log m) per query.
        // For a huge dictionary you would instead cache the top-k at each node
        // during insert — trading memory and write cost for O(k) reads. Right
        // answer depends on the read/write ratio; say which you assumed.
        return found
            .sorted { $0.frequency != $1.frequency ? $0.frequency > $1.frequency : $0.word < $1.word }
            .prefix(limit)
            .map(\.word)
    }

    public var wordCount: Int { distinctWords }

    private func collect(_ node: Node, current: String, into out: inout [(word: String, frequency: Int)]) {
        if let f = node.frequency { out.append((current, f)) }
        for (ch, child) in node.children { collect(child, current: current + String(ch), into: &out) }
    }
}

// MARK: - SOLO 5 Leaderboard

public struct LeaderboardEntry: Equatable {
    public let playerID: String
    public let score: Int
    public init(playerID: String, score: Int) { self.playerID = playerID; self.score = score }
}

public final class Leaderboard {
    private var scores: [String: Int] = [:]
    public init() {}

    public func addScore(_ playerID: String, delta: Int) {
        scores[playerID, default: 0] += delta
    }

    public func top(_ k: Int) -> [LeaderboardEntry] {
        ranked().prefix(max(0, k)).map { LeaderboardEntry(playerID: $0.key, score: $0.value) }
    }

    public func rank(of playerID: String) -> Int? {
        guard scores[playerID] != nil else { return nil }
        return ranked().firstIndex { $0.key == playerID }.map { $0 + 1 }
    }

    public func reset(_ playerID: String) {
        guard scores[playerID] != nil else { return }
        scores[playerID] = 0
    }

    public func score(of playerID: String) -> Int? { scores[playerID] }
    public var playerCount: Int { scores.count }

    /// Score descending, then id ascending. O(n log n) per query —
    /// fine here; a heap or an ordered index is the answer at scale.
    // ONE comparator, used by both `top` and `rank`, so the two can never
    // disagree. Duplicating the sort in both methods is how "you are rank 4" ends
    // up inconsistent with a leaderboard that shows you third.
    //
    // Honest complexity: O(n log n) per query. Fine for thousands, wrong for
    // millions — then a max-heap for top(k) and an order-statistics structure for
    // rank(). Saying "I would sort now and move to a heap when n grows, and the
    // interface already allows it" is the correct answer; premature optimisation
    // is also a failure mode.
    private func ranked() -> [(key: String, value: Int)] {
        scores.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
    }
}
