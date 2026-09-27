import XCTest
@testable import M11

final class S1DeckTests: XCTestCase {
    func test_orderedDeckHas52UniqueCards() {
        let d = Deck()
        XCTAssertEqual(d.remaining, 52)
        let all = d.deal(52)
        XCTAssertEqual(Set(all).count, 52)
        XCTAssertEqual(d.remaining, 0)
    }
    func test_buildOrder() {
        let d = Deck()
        let all = d.deal(52)                       // dealt from the top = reversed build order
        XCTAssertEqual(all.first, Card(rank: .ace, suit: .spades))
        XCTAssertEqual(all.last, Card(rank: .two, suit: .clubs))
    }
    func test_description() {
        XCTAssertEqual(Card(rank: .ace, suit: .spades).description, "ace of spades")
        XCTAssertEqual(Card(rank: .two, suit: .hearts).description, "two of hearts")
    }
    func test_identityShuffleLeavesOrderUnchanged() {
        let before = Deck().deal(52)
        let d = Deck(rng: { $0 - 1 })              // j == i for every i: no swaps
        d.shuffle()
        XCTAssertEqual(d.deal(52), before)
    }
    func test_shuffleKeepsAllCards() {
        var seed = 7
        let d = Deck(rng: { n in seed = (seed &* 31 &+ 17) % 1_000; return seed % n })
        d.shuffle()
        let all = d.deal(52)
        XCTAssertEqual(Set(all).count, 52)
    }
    func test_dealMoreThanRemaining() {
        let d = Deck()
        _ = d.deal(50)
        XCTAssertEqual(d.deal(5).count, 2)
        XCTAssertNil(d.deal())
    }
    func test_reset() {
        let d = Deck()
        _ = d.deal(10)
        d.reset()
        XCTAssertEqual(d.remaining, 52)
    }
}

final class S2ConnectFourTests: XCTestCase {
    func test_discFallsToTheBottom() throws {
        let g = ConnectFour()
        XCTAssertEqual(try g.drop(.red, into: 3), 0)
        XCTAssertEqual(try g.drop(.yellow, into: 3), 1)
        XCTAssertEqual(g.disc(atRow: 0, column: 3), .red)
        XCTAssertEqual(g.disc(atRow: 1, column: 3), .yellow)
        XCTAssertNil(g.disc(atRow: 2, column: 3))
    }
    func test_turnOrderEnforced() {
        let g = ConnectFour()
        XCTAssertThrowsError(try g.drop(.yellow, into: 0)) {
            XCTAssertEqual($0 as? ConnectFourError, .notYourTurn)
        }
    }
    func test_columnBounds() {
        let g = ConnectFour()
        XCTAssertThrowsError(try g.drop(.red, into: 7)) {
            XCTAssertEqual($0 as? ConnectFourError, .columnOutOfRange)
        }
    }
    func test_columnFull() throws {
        let g = ConnectFour(rows: 2, columns: 2)
        try g.drop(.red, into: 0); try g.drop(.yellow, into: 0)
        XCTAssertThrowsError(try g.drop(.red, into: 0)) {
            XCTAssertEqual($0 as? ConnectFourError, .columnFull)
        }
    }
    func test_verticalWin() throws {
        let g = ConnectFour()
        for _ in 0..<3 { try g.drop(.red, into: 0); try g.drop(.yellow, into: 1) }
        try g.drop(.red, into: 0)
        XCTAssertEqual(g.result, .win(.red))
    }
    func test_horizontalWinProper() throws {
        let g = ConnectFour()
        try g.drop(.red, into: 0); try g.drop(.yellow, into: 0)
        try g.drop(.red, into: 1); try g.drop(.yellow, into: 1)
        try g.drop(.red, into: 2); try g.drop(.yellow, into: 2)
        try g.drop(.red, into: 3)
        XCTAssertEqual(g.result, .win(.red))
    }
    func test_diagonalWin() throws {
        let g = ConnectFour()
        // build a red diagonal (0,0) (1,1) (2,2) (3,3)
        try g.drop(.red, into: 0)                    // (0,0) R
        try g.drop(.yellow, into: 1)                 // (0,1) Y
        try g.drop(.red, into: 1)                    // (1,1) R
        try g.drop(.yellow, into: 2)                 // (0,2) Y
        try g.drop(.red, into: 3)                    // (0,3) R  (filler)
        try g.drop(.yellow, into: 2)                 // (1,2) Y
        try g.drop(.red, into: 2)                    // (2,2) R
        try g.drop(.yellow, into: 3)                 // (1,3) Y
        try g.drop(.red, into: 6)                    // filler
        try g.drop(.yellow, into: 3)                 // (2,3) Y
        try g.drop(.red, into: 3)                    // (3,3) R -> wins
        XCTAssertEqual(g.result, .win(.red))
    }
    func test_drawOnAFullBoard() throws {
        let g = ConnectFour(rows: 1, columns: 2)
        try g.drop(.red, into: 0)
        try g.drop(.yellow, into: 1)
        XCTAssertEqual(g.result, .draw)
        XCTAssertThrowsError(try g.drop(.red, into: 0)) {
            XCTAssertEqual($0 as? ConnectFourError, .gameOver)
        }
    }
}

final class S3RingBufferTests: XCTestCase {
    func test_fifo() throws {
        var b = RingBuffer<Int>(capacity: 3)
        try b.enqueue(1); try b.enqueue(2)
        XCTAssertEqual(b.peek, 1)
        XCTAssertEqual(b.dequeue(), 1)
        XCTAssertEqual(b.dequeue(), 2)
        XCTAssertNil(b.dequeue())
        XCTAssertTrue(b.isEmpty)
    }
    func test_fullThrows() throws {
        var b = RingBuffer<Int>(capacity: 2)
        try b.enqueue(1); try b.enqueue(2)
        XCTAssertTrue(b.isFull)
        XCTAssertThrowsError(try b.enqueue(3)) { XCTAssertEqual($0 as? RingBufferError, .full) }
    }
    func test_overwriteDropsOldest() throws {
        var b = RingBuffer<Int>(capacity: 2)
        try b.enqueue(1); try b.enqueue(2)
        XCTAssertEqual(b.enqueueOverwriting(3), 1)
        XCTAssertEqual(b.elements, [2, 3])
        XCTAssertEqual(b.count, 2)
    }
    func test_wrapAround() throws {
        var b = RingBuffer<Int>(capacity: 3)
        try b.enqueue(1); try b.enqueue(2); try b.enqueue(3)
        _ = b.dequeue(); _ = b.dequeue()
        try b.enqueue(4); try b.enqueue(5)
        XCTAssertEqual(b.elements, [3, 4, 5])
    }
    func test_overwriteWhenNotFullJustEnqueues() {
        var b = RingBuffer<Int>(capacity: 3)
        XCTAssertNil(b.enqueueOverwriting(1))
        XCTAssertEqual(b.elements, [1])
    }
}

final class S4AutocompleteTests: XCTestCase {
    private func loaded() -> Autocomplete {
        let a = Autocomplete()
        a.insert("car", frequency: 10)
        a.insert("cart", frequency: 30)
        a.insert("carbon", frequency: 30)
        a.insert("care", frequency: 5)
        a.insert("dog", frequency: 100)
        return a
    }
    func test_frequencyThenAlphabetical() {
        XCTAssertEqual(loaded().suggest(prefix: "car", limit: 3), ["carbon", "cart", "car"])
    }
    func test_limit() {
        XCTAssertEqual(loaded().suggest(prefix: "car", limit: 1), ["carbon"])
    }
    func test_emptyPrefixMatchesEverything() {
        XCTAssertEqual(loaded().suggest(prefix: "", limit: 2), ["dog", "carbon"])
    }
    func test_unknownPrefix() {
        XCTAssertEqual(loaded().suggest(prefix: "zz", limit: 5), [])
    }
    func test_reinsertReplacesFrequency() {
        let a = loaded()
        a.insert("car", frequency: 999)
        XCTAssertEqual(a.suggest(prefix: "car", limit: 1), ["car"])
        XCTAssertEqual(a.wordCount, 5, "re-inserting must not create a duplicate word")
    }
    func test_prefixThatIsAlsoAWord() {
        XCTAssertTrue(loaded().suggest(prefix: "car", limit: 10).contains("car"))
    }
}

final class S5LeaderboardTests: XCTestCase {
    private func loaded() -> Leaderboard {
        let b = Leaderboard()
        b.addScore("zoe", delta: 50)
        b.addScore("amy", delta: 50)
        b.addScore("bob", delta: 70)
        b.addScore("amy", delta: 30)      // 80
        return b
    }
    func test_scoresAccumulate() {
        XCTAssertEqual(loaded().score(of: "amy"), 80)
        XCTAssertNil(loaded().score(of: "nobody"))
    }
    func test_topOrdering() {
        XCTAssertEqual(loaded().top(3), [
            LeaderboardEntry(playerID: "amy", score: 80),
            LeaderboardEntry(playerID: "bob", score: 70),
            LeaderboardEntry(playerID: "zoe", score: 50),
        ])
    }
    func test_tieBrokenByIDAscending() {
        let b = Leaderboard()
        b.addScore("zoe", delta: 10)
        b.addScore("amy", delta: 10)
        XCTAssertEqual(b.top(2).map(\.playerID), ["amy", "zoe"])
    }
    func test_topLargerThanBoard() {
        XCTAssertEqual(loaded().top(99).count, 3)
    }
    func test_rank() {
        let b = loaded()
        XCTAssertEqual(b.rank(of: "amy"), 1)
        XCTAssertEqual(b.rank(of: "zoe"), 3)
        XCTAssertNil(b.rank(of: "nobody"))
    }
    func test_resetKeepsThePlayer() {
        let b = loaded()
        b.reset("amy")
        XCTAssertEqual(b.score(of: "amy"), 0)
        XCTAssertEqual(b.playerCount, 3)
        XCTAssertEqual(b.rank(of: "amy"), 3)
    }
}
