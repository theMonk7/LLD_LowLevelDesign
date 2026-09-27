//  Module 13 — SOLO problem reference solutions.
//
//  HOW TO READ THIS FILE
//  Hard problems are where the same few shapes keep reappearing. Watch for them:
//    - intend -> do -> settle, with an expiry on the middle state
//    - leases + idempotent work as the substitute for exactly-once
//    - read and acknowledge as SEPARATE operations
//    - cost functions that are not the obvious metric
//
//  Not part of the M13 target.

import Foundation

// MARK: - SOLO 1 Retrying Job Queue

public struct QueuedJob: Equatable {
    public let id: String
    public let priority: Int
    public let maxAttempts: Int
    public init(id: String, priority: Int, maxAttempts: Int) {
        self.id = id; self.priority = priority; self.maxAttempts = maxAttempts
    }
}

public enum QueueError: Error, Equatable { case notInFlight, unknownJob }

public final class RetryingJobQueue {
    private enum Status { case ready, inFlight, dead }
    private struct Record {
        let job: QueuedJob
        var attempts: Int
        var dueAt: Double
        var status: Status
    }

    private var records: [String: Record] = [:]
    private let baseDelay: Double
    private let now: () -> Double

    public init(baseDelay: Double, now: @escaping () -> Double) {
        self.baseDelay = baseDelay
        self.now = now
    }

    public func submit(_ job: QueuedJob) {
        records[job.id] = Record(job: job, attempts: 0, dueAt: now(), status: .ready)
    }

    // WHERE `attempts` INCREMENTS IS A DESIGN DECISION, not a detail.
    // Incrementing on poll means a worker that crashes without reporting has still
    // consumed an attempt — which is what you want, otherwise a job that reliably
    // kills its worker retries forever. Incrementing on `fail` would be more
    // "accurate" and less safe.
    //
    // The three states (ready / inFlight / dead) make "two workers get the same
    // job" unrepresentable, which is the queue's core invariant.
    public func poll() -> QueuedJob? {
        let t = now()
        let candidates = records.values.filter { $0.status == .ready && $0.dueAt <= t }
        guard let chosen = candidates.min(by: {
            $0.job.priority != $1.job.priority ? $0.job.priority > $1.job.priority : $0.job.id < $1.job.id
        }) else { return nil }
        records[chosen.job.id]?.status = .inFlight
        records[chosen.job.id]?.attempts += 1        // an attempt begins when a worker takes it
        return chosen.job
    }

    public func complete(_ jobID: String) throws {
        guard records[jobID]?.status == .inFlight else { throw QueueError.notInFlight }
        records[jobID] = nil
    }

    public func fail(_ jobID: String) throws {
        guard var record = records[jobID], record.status == .inFlight else { throw QueueError.notInFlight }
        if record.attempts < record.job.maxAttempts {
            record.status = .ready
            // base * 2^(attempts-1) gives 10, 20, 40 for base 10 — doubling FROM
            // the base. "Exponential backoff" is ambiguous about the first delay,
            // so state the formula.
            //
            // Production systems add JITTER (a random +/-20%) so a thousand jobs
            // failing at once do not all retry at the same instant — a stampede
            // you cause by being too precise. And the dead-letter queue below is
            // why a poison job does not occupy a worker slot forever.
            record.dueAt = now() + baseDelay * pow(2, Double(record.attempts - 1))
        } else {
            record.status = .dead
        }
        records[jobID] = record
    }

    public func attempts(of jobID: String) -> Int { records[jobID]?.attempts ?? 0 }
    public var deadLetterIDs: [String] { records.values.filter { $0.status == .dead }.map(\.job.id).sorted() }
    public var readyCount: Int {
        let t = now()
        return records.values.filter { $0.status == .ready && $0.dueAt <= t }.count
    }
    public var inFlightCount: Int { records.values.filter { $0.status == .inFlight }.count }
}

// MARK: - SOLO 2 Topic Broker

public struct Message: Equatable {
    public let offset: Int
    public let payload: String
    public init(offset: Int, payload: String) { self.offset = offset; self.payload = payload }
}

public enum BrokerError: Error, Equatable { case unknownTopic, invalidCommit }

public final class TopicBroker {
    private var topics: [String: [String]] = [:]
    private var offsets: [String: Int] = [:]          // "topic|group" -> next offset to read

    public init() {}

    public func createTopic(_ topic: String) { topics[topic] = topics[topic] ?? [] }

    @discardableResult
    public func publish(_ payload: String, to topic: String) throws -> Int {
        guard topics[topic] != nil else { throw BrokerError.unknownTopic }
        topics[topic]!.append(payload)
        return topics[topic]!.count - 1
    }

    // SEPARATING POLL FROM COMMIT IS THE ENTIRE DESIGN.
    // If polling advanced the offset, a consumer that crashed mid-work would lose
    // the message — at-most-once delivery. Committing only after successful work
    // gives AT-LEAST-ONCE, which is why consumers must be idempotent (Module 09).
    // That trade is the thing to say out loud.
    //
    // Offsets are keyed by (topic, group), not per consumer — one choice that
    // gives both behaviours people expect: consumers in a group share progress
    // (work splitting), different groups each see the whole stream (fan-out).
    public func poll(topic: String, group: String, max: Int) throws -> [Message] {
        guard let messages = topics[topic] else { throw BrokerError.unknownTopic }
        let start = offsets[key(topic, group)] ?? 0
        guard start < messages.count, max > 0 else { return [] }
        let end = Swift.min(messages.count, start + max)
        return (start..<end).map { Message(offset: $0, payload: messages[$0]) }
    }

    public func commit(topic: String, group: String, offset: Int) throws {
        guard let messages = topics[topic] else { throw BrokerError.unknownTopic }
        let current = offsets[key(topic, group)] ?? 0
        guard offset >= 0, offset < messages.count, offset + 1 > current else {
            throw BrokerError.invalidCommit                 // no rewinds, no committing the future
        }
        offsets[key(topic, group)] = offset + 1
    }

    public func lag(topic: String, group: String) throws -> Int {
        guard let messages = topics[topic] else { throw BrokerError.unknownTopic }
        return messages.count - (offsets[key(topic, group)] ?? 0)
    }

    public func messageCount(topic: String) throws -> Int {
        guard let messages = topics[topic] else { throw BrokerError.unknownTopic }
        return messages.count
    }

    private func key(_ topic: String, _ group: String) -> String { "\(topic)|\(group)" }
}

// MARK: - SOLO 3 Consistent Hash Ring

public final class ConsistentHashRing {
    private let virtualNodes: Int
    private let hash: (String) -> Int
    /// Sorted by position so lookup is a binary search.
    private var ring: [(position: Int, node: String)] = []

    public init(virtualNodes: Int, hash: @escaping (String) -> Int = { abs($0.hashValue) }) {
        self.virtualNodes = max(1, virtualNodes)
        self.hash = hash
    }

    public func addNode(_ node: String) {
        guard !nodes.contains(node) else { return }
        for i in 0..<virtualNodes {
            ring.append((position: hash("\(node)#\(i)"), node: node))
        }
        ring.sort { $0.position < $1.position }
    }

    public func removeNode(_ node: String) {
        ring.removeAll { $0.node == node }
    }

    // WHY THIS EXISTS: with `hash(key) % n`, changing n from 3 to 4 moves ~75% of
    // keys — caches empty, connections shuffle, load spikes. On a ring, adding a
    // node steals only the arc between it and its predecessor, about 1/n of keys.
    //
    // Two details are the difference between working and not:
    //  - MANY positions per node (one each gives wildly uneven shares; real
    //    systems use 100-200 replicas).
    //  - the WRAP (`?? ring[0]`): a key hashing past the highest position belongs
    //    to the lowest. Forget it and every such key misroutes or crashes.
    //
    // `ring` is sorted, so the linear `first` could be a binary search — worth
    // saying, since 100 nodes x 150 replicas is 15,000 entries.
    public func node(for key: String) -> String? {
        guard !ring.isEmpty else { return nil }
        let h = hash(key)
        // First position clockwise; wrap to the smallest when past the end.
        return (ring.first { $0.position >= h } ?? ring[0]).node
    }

    public var nodes: [String] { Array(Set(ring.map(\.node))).sorted() }
    public var ringSize: Int { ring.count }
}

// MARK: - SOLO 4 LOOK Scheduler

public enum CarDirection: Equatable { case up, down }

public struct LookScheduler {
    public init() {}

    // Six lines for the algorithm that makes elevators feel sane. LOOK means
    // "continue in the current direction until nothing is left that way, then
    // reverse" — unlike SCAN, which travels to the end of the shaft first.
    //
    // `>= currentFloor` is INCLUSIVE so a stop at the current floor is served
    // immediately rather than after a full round trip. That is a real bug in naive
    // implementations, and the reason one of the tests exists.
    public func order(currentFloor: Int, direction: CarDirection, stops: Set<Int>) -> [Int] {
        switch direction {
        case .up:
            let ahead = stops.filter { $0 >= currentFloor }.sorted()
            let behind = stops.filter { $0 < currentFloor }.sorted(by: >)
            return ahead + behind
        case .down:
            let ahead = stops.filter { $0 <= currentFloor }.sorted(by: >)
            let behind = stops.filter { $0 > currentFloor }.sorted()
            return ahead + behind
        }
    }

    public func distance(currentFloor: Int, direction: CarDirection, stops: Set<Int>) -> Int {
        travel(from: currentFloor, along: order(currentFloor: currentFloor, direction: direction, stops: stops))
    }

    // THE INSIGHT THE WHOLE PROBLEM IS TESTING: cost is "time until this candidate
    // can actually serve me", NOT "distance right now". A car at floor 8 heading
    // down beats a car at floor 4 heading up for a request at floor 3, because the
    // first passes floor 3 on its way and the second must finish its upward run.
    //
    // Generalise the question: what is the TRUE cost function here, and what am I
    // substituting for it because it is easier to compute?
    public func bestCar(for requestFloor: Int,
                        cars: [(floor: Int, direction: CarDirection, stops: Set<Int>)]) -> Int? {
        let costs = cars.map { car -> Int in
            let plan = order(currentFloor: car.floor, direction: car.direction,
                             stops: car.stops.union([requestFloor]))
            guard let stopIndex = plan.firstIndex(of: requestFloor) else { return .max }
            return travel(from: car.floor, along: Array(plan.prefix(stopIndex + 1)))
        }
        return costs.indices.min { costs[$0] != costs[$1] ? costs[$0] < costs[$1] : $0 < $1 }
    }

    private func travel(from start: Int, along plan: [Int]) -> Int {
        var position = start, total = 0
        for floor in plan { total += abs(floor - position); position = floor }
        return total
    }
}
