import XCTest
@testable import M13

final class FakeClock13: @unchecked Sendable {
    private var t: Double = 0
    private let lock = NSLock()
    var now: Double { lock.lock(); defer { lock.unlock() }; return t }
    func advance(_ d: Double) { lock.lock(); t += d; lock.unlock() }
}

final class S1JobQueueTests: XCTestCase {
    func test_pollsHighestPriorityFirst() {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 1, now: { clock.now })
        q.submit(QueuedJob(id: "low", priority: 1, maxAttempts: 3))
        q.submit(QueuedJob(id: "high", priority: 9, maxAttempts: 3))
        q.submit(QueuedJob(id: "mid", priority: 5, maxAttempts: 3))
        XCTAssertEqual(q.poll()?.id, "high")
        XCTAssertEqual(q.poll()?.id, "mid")
        XCTAssertEqual(q.poll()?.id, "low")
        XCTAssertNil(q.poll())
        XCTAssertEqual(q.inFlightCount, 3)
    }
    func test_tieBrokenByID() {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 1, now: { clock.now })
        q.submit(QueuedJob(id: "zeta", priority: 5, maxAttempts: 1))
        q.submit(QueuedJob(id: "alpha", priority: 5, maxAttempts: 1))
        XCTAssertEqual(q.poll()?.id, "alpha")
    }
    func test_completeRemovesTheJob() throws {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 1, now: { clock.now })
        q.submit(QueuedJob(id: "a", priority: 1, maxAttempts: 3))
        _ = q.poll()
        try q.complete("a")
        XCTAssertEqual(q.inFlightCount, 0)
        XCTAssertEqual(q.readyCount, 0)
        XCTAssertThrowsError(try q.complete("a")) { XCTAssertEqual($0 as? QueueError, .notInFlight) }
    }
    func test_exponentialBackoff() throws {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 10, now: { clock.now })
        q.submit(QueuedJob(id: "a", priority: 1, maxAttempts: 3))

        XCTAssertEqual(q.poll()?.id, "a")
        XCTAssertEqual(q.attempts(of: "a"), 1)
        try q.fail("a")                                  // due at now + 10 * 2^0 = 10
        XCTAssertEqual(q.readyCount, 0)
        XCTAssertNil(q.poll(), "the job is backing off")

        clock.advance(10)
        XCTAssertEqual(q.poll()?.id, "a")
        XCTAssertEqual(q.attempts(of: "a"), 2)
        try q.fail("a")                                  // due at 10 + 10 * 2^1 = 30
        clock.advance(10)
        XCTAssertNil(q.poll(), "backoff doubled")
        clock.advance(10)
        XCTAssertEqual(q.poll()?.id, "a")
        XCTAssertEqual(q.attempts(of: "a"), 3)
    }
    func test_deadLetterAfterFinalAttempt() throws {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 1, now: { clock.now })
        q.submit(QueuedJob(id: "a", priority: 1, maxAttempts: 2))
        _ = q.poll(); try q.fail("a")
        clock.advance(100)
        _ = q.poll(); try q.fail("a")
        XCTAssertEqual(q.deadLetterIDs, ["a"])
        XCTAssertEqual(q.readyCount, 0)
        XCTAssertNil(q.poll())
    }
    func test_failingAJobThatIsNotInFlight() {
        let clock = FakeClock13()
        let q = RetryingJobQueue(baseDelay: 1, now: { clock.now })
        q.submit(QueuedJob(id: "a", priority: 1, maxAttempts: 2))
        XCTAssertThrowsError(try q.fail("a")) { XCTAssertEqual($0 as? QueueError, .notInFlight) }
    }
}

final class S2BrokerTests: XCTestCase {
    private func loaded() throws -> TopicBroker {
        let b = TopicBroker()
        b.createTopic("orders")
        for i in 0..<5 { try b.publish("m\(i)", to: "orders") }
        return b
    }
    func test_publishAssignsSequentialOffsets() throws {
        let b = TopicBroker()
        b.createTopic("t")
        XCTAssertEqual(try b.publish("a", to: "t"), 0)
        XCTAssertEqual(try b.publish("b", to: "t"), 1)
        XCTAssertEqual(try b.messageCount(topic: "t"), 2)
    }
    func test_unknownTopic() {
        let b = TopicBroker()
        XCTAssertThrowsError(try b.publish("a", to: "nope")) {
            XCTAssertEqual($0 as? BrokerError, .unknownTopic)
        }
    }
    func test_pollDoesNotAdvanceTheOffset() throws {
        let b = try loaded()
        XCTAssertEqual(try b.poll(topic: "orders", group: "g1", max: 2).map(\.payload), ["m0", "m1"])
        XCTAssertEqual(try b.poll(topic: "orders", group: "g1", max: 2).map(\.payload), ["m0", "m1"])
    }
    func test_commitAdvances() throws {
        let b = try loaded()
        try b.commit(topic: "orders", group: "g1", offset: 1)
        XCTAssertEqual(try b.poll(topic: "orders", group: "g1", max: 2).map(\.payload), ["m2", "m3"])
        XCTAssertEqual(try b.lag(topic: "orders", group: "g1"), 3)
    }
    func test_groupsAreIndependent() throws {
        let b = try loaded()
        try b.commit(topic: "orders", group: "g1", offset: 3)
        XCTAssertEqual(try b.poll(topic: "orders", group: "g2", max: 1).map(\.payload), ["m0"])
        XCTAssertEqual(try b.lag(topic: "orders", group: "g1"), 1)
        XCTAssertEqual(try b.lag(topic: "orders", group: "g2"), 5)
    }
    func test_invalidCommits() throws {
        let b = try loaded()
        try b.commit(topic: "orders", group: "g1", offset: 2)
        XCTAssertThrowsError(try b.commit(topic: "orders", group: "g1", offset: 1)) {
            XCTAssertEqual($0 as? BrokerError, .invalidCommit)
        }
        XCTAssertThrowsError(try b.commit(topic: "orders", group: "g1", offset: 99)) {
            XCTAssertEqual($0 as? BrokerError, .invalidCommit)
        }
    }
    func test_pollAtTheEnd() throws {
        let b = try loaded()
        try b.commit(topic: "orders", group: "g1", offset: 4)
        XCTAssertEqual(try b.poll(topic: "orders", group: "g1", max: 10), [])
        XCTAssertEqual(try b.lag(topic: "orders", group: "g1"), 0)
    }
}

final class S3HashRingTests: XCTestCase {
    /// Deterministic positions for virtual nodes and keys.
    private let positions: [String: Int] = [
        "A#0": 10, "A#1": 210,
        "B#0": 110, "B#1": 310,
        "C#0": 60, "C#1": 260,
        "k1": 5, "k2": 70, "k3": 150, "k4": 250, "k5": 350,
    ]
    private func ring(virtualNodes: Int = 2) -> ConsistentHashRing {
        ConsistentHashRing(virtualNodes: virtualNodes, hash: { self.positions[$0] ?? 0 })
    }
    func test_emptyRing() {
        XCTAssertNil(ring().node(for: "k1"))
        XCTAssertEqual(ring().ringSize, 0)
    }
    func test_ringSizeAndNodes() {
        let r = ring()
        r.addNode("A"); r.addNode("B")
        XCTAssertEqual(r.nodes, ["A", "B"])
        XCTAssertEqual(r.ringSize, 4)
    }
    func test_clockwiseAssignment() {
        let r = ring()
        r.addNode("A"); r.addNode("B")          // positions 10,210 (A) and 110,310 (B)
        XCTAssertEqual(r.node(for: "k1"), "A")  // 5   -> 10   (A#0)
        XCTAssertEqual(r.node(for: "k2"), "B")  // 70  -> 110  (B#0)
        XCTAssertEqual(r.node(for: "k3"), "A")  // 150 -> 210  (A#1)
        XCTAssertEqual(r.node(for: "k4"), "B")  // 250 -> 310  (B#1)
    }
    func test_wrapAround() {
        let r = ring()
        r.addNode("A"); r.addNode("B")
        XCTAssertEqual(r.node(for: "k5"), "A", "350 is past every position, so it wraps to the lowest (10)")
    }
    func test_addingANodeOnlyMovesSomeKeys() {
        let r = ring()
        r.addNode("A"); r.addNode("B")
        let before = ["k1", "k2", "k3", "k4", "k5"].map { r.node(for: $0) }
        r.addNode("C")                          // positions 60, 260
        let after = ["k1", "k2", "k3", "k4", "k5"].map { r.node(for: $0) }
        let moved = zip(before, after).filter { $0 != $1 }.count
        XCTAssertEqual(after[1], "B", "k2 at 70 maps to the next position clockwise, 110 -> B")
        XCTAssertGreaterThanOrEqual(moved, 0)
        XCTAssertTrue(moved <= 2, "adding one node must not reshuffle every key, moved=\(moved)")
    }
    func test_removeNode() {
        let r = ring()
        r.addNode("A"); r.addNode("B")
        r.removeNode("B")
        XCTAssertEqual(r.nodes, ["A"])
        XCTAssertEqual(r.ringSize, 2)
        XCTAssertEqual(r.node(for: "k2"), "A", "every key falls to the surviving node")
    }
    func test_stableForTheSameKey() {
        let r = ring()
        r.addNode("A"); r.addNode("B")
        XCTAssertEqual(r.node(for: "k3"), r.node(for: "k3"))
    }
}

final class S4LookTests: XCTestCase {
    private let s = LookScheduler()

    func test_goingUp() {
        XCTAssertEqual(s.order(currentFloor: 5, direction: .up, stops: [3, 7, 9, 1]), [7, 9, 3, 1])
    }
    func test_goingDown() {
        XCTAssertEqual(s.order(currentFloor: 5, direction: .down, stops: [3, 7, 9, 1]), [3, 1, 7, 9])
    }
    func test_currentFloorIsServedFirst() {
        XCTAssertEqual(s.order(currentFloor: 5, direction: .up, stops: [5, 8]), [5, 8])
    }
    func test_emptyStops() {
        XCTAssertEqual(s.order(currentFloor: 5, direction: .up, stops: []), [])
        XCTAssertEqual(s.distance(currentFloor: 5, direction: .up, stops: []), 0)
    }
    func test_distance() {
        // 5 -> 7 -> 9 -> 3 -> 1 = 2 + 2 + 6 + 2 = 12
        XCTAssertEqual(s.distance(currentFloor: 5, direction: .up, stops: [3, 7, 9, 1]), 12)
    }
    func test_distanceGoingDown() {
        // 5 -> 3 -> 1 -> 7 -> 9 = 2 + 2 + 6 + 2 = 12
        XCTAssertEqual(s.distance(currentFloor: 5, direction: .down, stops: [3, 7, 9, 1]), 12)
    }
    func test_bestCarPrefersTheCloserOne() {
        let best = s.bestCar(for: 3, cars: [
            (floor: 0, direction: .up, stops: []),
            (floor: 10, direction: .down, stops: []),
        ])
        XCTAssertEqual(best, 0)
    }
    func test_bestCarAccountsForDirection() {
        // Car 0 is at 4 heading up: it must go up to 9 first, then come back down to 3.
        // Car 1 is at 8 heading down: it passes 3 directly.
        let best = s.bestCar(for: 3, cars: [
            (floor: 4, direction: .up, stops: [9]),
            (floor: 8, direction: .down, stops: [1]),
        ])
        XCTAssertEqual(best, 1)
    }
    func test_bestCarWithNoCars() {
        XCTAssertNil(s.bestCar(for: 3, cars: []))
    }
    func test_bestCarTieGoesToLowerIndex() {
        let best = s.bestCar(for: 5, cars: [
            (floor: 3, direction: .up, stops: []),
            (floor: 7, direction: .down, stops: []),
        ])
        XCTAssertEqual(best, 0)
    }
}
