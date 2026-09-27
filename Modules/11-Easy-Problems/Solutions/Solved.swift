//  Module 11 — SOLVED problems, fully implemented.
//
//  HOW TO READ THIS FILE
//  Read the requirements in README.md, design your own version for twenty minutes,
//  and only THEN read here. Reading a solution you have not attempted produces
//  recognition, which feels like learning and is not.
//
//  When you do read, compare DECISIONS rather than syntax:
//    - which nouns became types, and which turned out to be one type (Jump)
//    - where each rule lives, and what it would cost if it lived in the caller
//    - why each data structure was forced by the operation list
//    - what was injected so the thing could be tested at all (Dice)
//
//  Everything here compiles and is exercised by M11Demo.run().

import Foundation

// =====================================================================
// SOLVED 1 — Tic-Tac-Toe
// =====================================================================

public enum Mark: String, Equatable { case x = "X", o = "O" }

public enum GameResult: Equatable {
    case inProgress
    case win(Mark)
    case draw
}

public enum MoveError: Error, Equatable {
    case outOfBounds
    case cellTaken
    case gameOver
    case notYourTurn
}

/// `size` is a parameter, not a constant: the same engine plays 3×3 and 5×5.
public final class TicTacToe {
    public let size: Int
    private var board: [[Mark?]]
    public private(set) var current: Mark = .x
    public private(set) var result: GameResult = .inProgress
    private var movesPlayed = 0

    public init(size: Int = 3) {
        self.size = size
        self.board = Array(repeating: Array(repeating: nil, count: size), count: size)
    }

    public func mark(at row: Int, _ col: Int) -> Mark? {
        guard (0..<size).contains(row), (0..<size).contains(col) else { return nil }
        return board[row][col]
    }

    @discardableResult
    public func play(_ mark: Mark, row: Int, col: Int) throws -> GameResult {
        guard result == .inProgress else { throw MoveError.gameOver }
        guard mark == current else { throw MoveError.notYourTurn }
        guard (0..<size).contains(row), (0..<size).contains(col) else { throw MoveError.outOfBounds }
        guard board[row][col] == nil else { throw MoveError.cellTaken }

        board[row][col] = mark
        movesPlayed += 1

        if wins(mark, lastRow: row, lastCol: col) {
            result = .win(mark)
        } else if movesPlayed == size * size {
            result = .draw
        } else {
            current = (mark == .x) ? .o : .x
        }
        return result
    }

    /// Only four lines can be completed by the last move — O(size), not O(size²).
    private func wins(_ mark: Mark, lastRow r: Int, lastCol c: Int) -> Bool {
        let row = (0..<size).allSatisfy { board[r][$0] == mark }
        let col = (0..<size).allSatisfy { board[$0][c] == mark }
        let diag = (r == c) && (0..<size).allSatisfy { board[$0][$0] == mark }
        let anti = (r + c == size - 1) && (0..<size).allSatisfy { board[$0][size - 1 - $0] == mark }
        return row || col || diag || anti
    }

    public func render() -> String {
        board.map { row in row.map { $0?.rawValue ?? "." }.joined(separator: " ") }
            .joined(separator: "\n")
    }
}

// =====================================================================
// SOLVED 2 — Snake & Ladder
// =====================================================================

public protocol Dice {
    func roll() -> Int
}

public struct StandardDice: Dice {
    public let sides: Int
    private let rng: () -> Int
    public init(sides: Int = 6, rng: @escaping () -> Int = { Int.random(in: 1...6) }) {
        self.sides = sides
        self.rng = rng
    }
    public func roll() -> Int { rng() }
}

/// A snake and a ladder are the same concept with different directions.
public struct Jump: Equatable {
    public let from: Int
    public let to: Int
    public init(from: Int, to: Int) { self.from = from; self.to = to }
    public var isLadder: Bool { to > from }
}

public struct SnakeLadderPlayer: Equatable {
    public let name: String
    public var position: Int
    public init(name: String, position: Int = 0) { self.name = name; self.position = position }
}

public final class SnakeAndLadder {
    public private(set) var players: [SnakeLadderPlayer]
    public private(set) var winner: String?
    private let jumps: [Int: Int]
    private let dice: any Dice
    private let finalSquare: Int
    private var turnIndex = 0

    public init(playerNames: [String], jumps: [Jump], dice: any Dice, finalSquare: Int = 100) {
        self.players = playerNames.map { SnakeLadderPlayer(name: $0) }
        self.jumps = Dictionary(uniqueKeysWithValues: jumps.map { ($0.from, $0.to) })
        self.dice = dice
        self.finalSquare = finalSquare
    }

    public var currentPlayer: String { players[turnIndex].name }

    /// One turn. Overshooting the final square does not move the player (a common house rule —
    /// exactly the kind of thing to clarify before coding).
    @discardableResult
    public func playTurn() -> String {
        guard winner == nil else { return "game over" }
        let player = players[turnIndex]
        let roll = dice.roll()
        var next = player.position + roll
        var note = "\(player.name) rolled \(roll)"

        if next > finalSquare {
            note += " and stayed at \(player.position)"
            next = player.position
        } else if let jumped = jumps[next] {
            note += " to \(next) then " + (jumped > next ? "climbed" : "slid") + " to \(jumped)"
            next = jumped
        } else {
            note += " to \(next)"
        }

        players[turnIndex].position = next
        if next == finalSquare {
            winner = player.name
            note += " — WINS"
        }
        turnIndex = (turnIndex + 1) % players.count
        return note
    }
}

// =====================================================================
// SOLVED 3 — Browser History
// =====================================================================

/// Two stacks. `visit` clears the forward stack — the same invariant as a redo stack.
public final class BrowserHistory {
    private var backStack: [String] = []
    private var forwardStack: [String] = []
    public private(set) var current: String

    public init(homepage: String) { self.current = homepage }

    public func visit(_ url: String) {
        backStack.append(current)
        current = url
        forwardStack.removeAll()
    }

    @discardableResult
    public func back(_ steps: Int = 1) -> String {
        for _ in 0..<steps {
            guard let previous = backStack.popLast() else { break }
            forwardStack.append(current)
            current = previous
        }
        return current
    }

    @discardableResult
    public func forward(_ steps: Int = 1) -> String {
        for _ in 0..<steps {
            guard let next = forwardStack.popLast() else { break }
            backStack.append(current)
            current = next
        }
        return current
    }

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }
}

// =====================================================================
// SOLVED 4 — Min Stack (O(1) push / pop / min)
// =====================================================================

/// Each entry carries the minimum of the stack up to that point — trading O(n) memory
/// for O(1) minimum. The alternative (a second stack of minima) is equivalent.
public struct MinStack<Element: Comparable> {
    private var entries: [(value: Element, min: Element)] = []

    public init() {}

    public mutating func push(_ value: Element) {
        let newMin = entries.last.map { Swift.min($0.min, value) } ?? value
        entries.append((value, newMin))
    }

    @discardableResult
    public mutating func pop() -> Element? {
        entries.popLast()?.value
    }

    public var top: Element? { entries.last?.value }
    public var minimum: Element? { entries.last?.min }
    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }
}

// =====================================================================
// SOLVED 5 — LRU Cache (O(1) get / put)
// =====================================================================

/// Dictionary for O(1) lookup + doubly-linked list for O(1) recency updates.
/// An array would make `get` O(n) because of the move-to-front.
public final class LRUCache<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) { self.key = key; self.value = value }
    }

    private var map: [Key: Node] = [:]
    private var head: Node?          // most recently used
    private var tail: Node?          // least recently used
    public let capacity: Int
    public private(set) var evictions = 0

    public init(capacity: Int) { self.capacity = max(1, capacity) }

    public var count: Int { map.count }
    public var keysMostRecentFirst: [Key] {
        var result: [Key] = []
        var node = head
        while let n = node { result.append(n.key); node = n.next }
        return result
    }

    public func get(_ key: Key) -> Value? {
        guard let node = map[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    public func put(_ key: Key, _ value: Value) {
        if let existing = map[key] {
            existing.value = value
            moveToFront(existing)
            return
        }
        let node = Node(key: key, value: value)
        map[key] = node
        addToFront(node)
        if map.count > capacity, let lru = tail {
            remove(lru)
            map[lru.key] = nil
            evictions += 1
        }
    }

    private func addToFront(_ node: Node) {
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func remove(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        node.prev = nil
        node.next = nil
    }

    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        remove(node)
        addToFront(node)
    }
}

// =====================================================================
// SOLVED 6 — HashMap with separate chaining
// =====================================================================

/// Built from first principles: buckets, chaining, load factor, resize.
public final class SimpleHashMap<Key: Hashable, Value> {
    private struct Entry { let key: Key; var value: Value }
    private var buckets: [[Entry]]
    public private(set) var count = 0
    private let loadFactor: Double

    public init(initialCapacity: Int = 8, loadFactor: Double = 0.75) {
        self.buckets = Array(repeating: [], count: max(1, initialCapacity))
        self.loadFactor = loadFactor
    }

    public var capacity: Int { buckets.count }

    private func index(for key: Key, in size: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(key)
        return abs(hasher.finalize() % size)
    }

    public func put(_ key: Key, _ value: Value) {
        let i = index(for: key, in: buckets.count)
        if let j = buckets[i].firstIndex(where: { $0.key == key }) {
            buckets[i][j].value = value                       // update, not insert
            return
        }
        buckets[i].append(Entry(key: key, value: value))
        count += 1
        if Double(count) / Double(buckets.count) > loadFactor { resize() }
    }

    public func get(_ key: Key) -> Value? {
        buckets[index(for: key, in: buckets.count)].first { $0.key == key }?.value
    }

    @discardableResult
    public func remove(_ key: Key) -> Value? {
        let i = index(for: key, in: buckets.count)
        guard let j = buckets[i].firstIndex(where: { $0.key == key }) else { return nil }
        let removed = buckets[i].remove(at: j)
        count -= 1
        return removed.value
    }

    private func resize() {
        let bigger = buckets.count * 2
        var newBuckets: [[Entry]] = Array(repeating: [], count: bigger)
        for bucket in buckets {
            for entry in bucket {
                newBuckets[index(for: entry.key, in: bigger)].append(entry)
            }
        }
        buckets = newBuckets
    }
}

// =====================================================================
// SOLVED 7 — Trie (prefix tree)
// =====================================================================

public final class Trie {
    private final class Node {
        var children: [Character: Node] = [:]
        var isWord = false
    }
    private let root = Node()
    public private(set) var wordCount = 0

    public init() {}

    public func insert(_ word: String) {
        var node = root
        for ch in word {
            if let next = node.children[ch] { node = next }
            else { let fresh = Node(); node.children[ch] = fresh; node = fresh }
        }
        if !node.isWord { node.isWord = true; wordCount += 1 }
    }

    public func contains(_ word: String) -> Bool { node(for: word)?.isWord ?? false }
    public func hasPrefix(_ prefix: String) -> Bool { node(for: prefix) != nil }

    /// All words starting with `prefix`, sorted — the autocomplete use case.
    public func words(withPrefix prefix: String) -> [String] {
        guard let start = node(for: prefix) else { return [] }
        var out: [String] = []
        collect(start, current: prefix, into: &out)
        return out.sorted()
    }

    private func node(for string: String) -> Node? {
        var node = root
        for ch in string {
            guard let next = node.children[ch] else { return nil }
            node = next
        }
        return node
    }

    private func collect(_ node: Node, current: String, into out: inout [String]) {
        if node.isWord { out.append(current) }
        for (ch, child) in node.children { collect(child, current: current + String(ch), into: &out) }
    }
}

// =====================================================================
// Demo
// =====================================================================

public enum M11Demo {
    public static func run() {
        // Tic-Tac-Toe
        let game = TicTacToe()
        try? game.play(.x, row: 0, col: 0); try? game.play(.o, row: 1, col: 1)
        try? game.play(.x, row: 0, col: 1); try? game.play(.o, row: 2, col: 2)
        let final = try? game.play(.x, row: 0, col: 2)
        print("TicTacToe:", final as Any)
        print(game.render())

        // Snake & Ladder with a scripted dice — deterministic, testable
        var rolls = [4, 6, 2, 5].makeIterator()
        let dice = StandardDice(rng: { rolls.next() ?? 1 })
        let snl = SnakeAndLadder(playerNames: ["A", "B"],
                                 jumps: [Jump(from: 4, to: 14), Jump(from: 16, to: 6)],
                                 dice: dice, finalSquare: 20)
        for _ in 0..<4 { print("SnL:", snl.playTurn()) }

        // Browser history
        let history = BrowserHistory(homepage: "home")
        history.visit("a"); history.visit("b")
        print("Browser back:", history.back(), "forward:", history.forward())

        // Min stack
        var stack = MinStack<Int>()
        [5, 3, 7, 3].forEach { stack.push($0) }
        print("MinStack min:", stack.minimum as Any)
        stack.pop(); stack.pop()
        print("MinStack min after pops:", stack.minimum as Any)

        // LRU
        let lru = LRUCache<String, Int>(capacity: 2)
        lru.put("a", 1); lru.put("b", 2); _ = lru.get("a"); lru.put("c", 3)
        print("LRU keys:", lru.keysMostRecentFirst, "evictions:", lru.evictions)

        // HashMap
        let map = SimpleHashMap<String, Int>(initialCapacity: 2)
        for i in 0..<10 { map.put("k\(i)", i) }
        print("HashMap count:", map.count, "capacity:", map.capacity, "k7:", map.get("k7") as Any)

        // Trie
        let trie = Trie()
        ["car", "cart", "carbon", "dog"].forEach { trie.insert($0) }
        print("Trie carX:", trie.words(withPrefix: "car"))
    }
}
