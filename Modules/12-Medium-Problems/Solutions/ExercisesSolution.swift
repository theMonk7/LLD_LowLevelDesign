//  Module 12 — SOLO problem reference solutions.
//
//  HOW TO READ THIS FILE
//  Medium problems add three things small ones did not have: resources that run
//  out, facts that must stay true after the world changes, and operations that can
//  half-fail. The comments flag those, plus the two recurring habits:
//    - name the POLICY whenever you choose from candidates
//    - state the complexity you chose and the upgrade you did not
//
//  Not part of the M12 target.

import Foundation

// MARK: - SOLO 1 LFU Cache

public final class LFUCache<Key: Hashable, Value> {
    // LFU needs TWO orderings at once — frequency, then recency as the tie-break —
    // which is what makes it harder than LRU. A monotonic `tick` gives a total
    // order on recency with no clock, no timestamps and no collisions.
    //
    // Every mutation (get, put-existing, put-new) bumps BOTH fields, so the two
    // orderings stay consistent. The classic bug is forgetting that `get` counts
    // as a use: the cache then evicts by insertion count and behaves like a
    // broken FIFO while still passing most tests.
    private struct Entry {
        var value: Value
        var frequency: Int
        var lastUsedTick: Int
    }
    private var entries: [Key: Entry] = [:]
    private var tick = 0
    public let capacity: Int
    public private(set) var evictedKeys: [Key] = []

    public init(capacity: Int) { self.capacity = max(1, capacity) }

    public var count: Int { entries.count }
    public func frequency(of key: Key) -> Int { entries[key]?.frequency ?? 0 }

    public func get(_ key: Key) -> Value? {
        guard var entry = entries[key] else { return nil }
        tick += 1
        entry.frequency += 1
        entry.lastUsedTick = tick
        entries[key] = entry
        return entry.value
    }

    public func put(_ key: Key, _ value: Value) {
        tick += 1
        if var existing = entries[key] {
            existing.value = value
            existing.frequency += 1
            existing.lastUsedTick = tick
            entries[key] = existing
            return
        }
        if entries.count >= capacity { evictOne() }
        entries[key] = Entry(value: value, frequency: 1, lastUsedTick: tick)
    }

    /// Least frequent, then least recently used.
    // Honest complexity: this is O(n) because of the `min`. The O(1) design keeps
    // a dictionary from frequency -> doubly-linked list of keys at that frequency,
    // plus a `minFrequency` pointer. WRITE THE SIMPLE ONE in an interview, state
    // the complexity, and offer the O(1) structure as the follow-up — attempting
    // it cold usually produces a bug.
    private func evictOne() {
        guard let victim = entries.min(by: { a, b in
            a.value.frequency != b.value.frequency
                ? a.value.frequency < b.value.frequency
                : a.value.lastUsedTick < b.value.lastUsedTick
        })?.key else { return }
        entries[victim] = nil
        evictedKeys.append(victim)
    }
}

// MARK: - SOLO 2 Coupon Engine

public struct Order12: Equatable {
    public let subtotal: Decimal
    public let category: String
    public let isFirstOrder: Bool
    public init(subtotal: Decimal, category: String, isFirstOrder: Bool = false) {
        self.subtotal = subtotal; self.category = category; self.isFirstOrder = isFirstOrder
    }
}

public protocol Coupon {
    var code: String { get }
    func discount(for order: Order12) -> Decimal?
}

public struct PercentageCoupon: Coupon {
    public let code: String
    public let percent: Decimal
    public let maxDiscount: Decimal
    public let minSubtotal: Decimal
    public init(code: String, percent: Decimal, maxDiscount: Decimal, minSubtotal: Decimal) {
        self.code = code; self.percent = percent; self.maxDiscount = maxDiscount; self.minSubtotal = minSubtotal
    }
    // `Decimal?` carries TWO distinct meanings: nil = "does not apply",
    // 0 = "applies but saves nothing". Collapse them into a plain Decimal and you
    // can no longer tell a non-applicable coupon from a worthless one — which
    // matters the moment the UI wants to explain WHY a code did not work.
    public func discount(for order: Order12) -> Decimal? {
        guard order.subtotal >= minSubtotal else { return nil }
        return min(order.subtotal * percent / 100, maxDiscount)
    }
}

public struct FlatCoupon: Coupon {
    public let code: String
    public let amount: Decimal
    public let minSubtotal: Decimal
    public init(code: String, amount: Decimal, minSubtotal: Decimal) {
        self.code = code; self.amount = amount; self.minSubtotal = minSubtotal
    }
    public func discount(for order: Order12) -> Decimal? {
        guard order.subtotal >= minSubtotal else { return nil }
        return min(amount, order.subtotal)
    }
}

public struct CategoryCoupon: Coupon {
    public let code: String
    public let category: String
    public let percent: Decimal
    public let firstOrderOnly: Bool
    public init(code: String, category: String, percent: Decimal, firstOrderOnly: Bool) {
        self.code = code; self.category = category; self.percent = percent; self.firstOrderOnly = firstOrderOnly
    }
    public func discount(for order: Order12) -> Decimal? {
        guard order.category == category else { return nil }
        guard !firstOrderOnly || order.isFirstOrder else { return nil }
        return order.subtotal * percent / 100
    }
}

public struct CouponEngine {
    private let coupons: [any Coupon]
    public init(coupons: [any Coupon]) { self.coupons = coupons }

    // The engine contains NO knowledge of any coupon type — no switch, no casts —
    // which is why the grader's own coupon type works untouched. OCP with a test
    // behind it.
    //
    // Each rule keeps its own invariant: `min(amount, subtotal)` inside FlatCoupon
    // guarantees a flat coupon can never exceed the price, rather than the engine
    // clamping afterwards. Invariants belong to the type that owns them.
    public func bestCoupon(for order: Order12) -> (code: String, discount: Decimal)? {
        coupons
            .compactMap { c in c.discount(for: order).map { (code: c.code, discount: $0) } }
            .min { a, b in a.discount != b.discount ? a.discount > b.discount : a.code < b.code }
    }

    public func finalTotal(for order: Order12) -> Decimal {
        max(0, order.subtotal - (bestCoupon(for: order)?.discount ?? 0))
    }
}

// MARK: - SOLO 3 File System

public enum FSError: Error, Equatable {
    case notFound, notADirectory, notAFile, alreadyExists, invalidPath
}

public final class FileSystem {
    // This is COMPOSITE (Module 06): one type that is either leaf or container,
    // so `size` recurses without caring which it holds.
    //
    // The alternative — an enum with .file(String) and .directory([String: Node]) —
    // is arguably more Swift-like and makes the two cases mutually exclusive by
    // construction. Both are good answers: the enum is stronger on correctness,
    // the class is easier to mutate in place. Say which you chose and why.
    private final class Node {
        var children: [String: Node]?     // non-nil => directory
        var contents: String?             // non-nil => file
        init(directory: Bool) {
            if directory { children = [:] } else { contents = "" }
        }
        var isDirectory: Bool { children != nil }
    }

    private let root = Node(directory: true)
    public init() {}

    private func components(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private func node(at path: String) -> Node? {
        var current = root
        for part in components(path) {
            guard let children = current.children, let next = children[part] else { return nil }
            current = next
        }
        return current
    }

    // Note the deliberate asymmetry: `mkdir` creates intermediate directories
    // (mkdir -p semantics) and `writeFile` does NOT. Two functions, two policies,
    // both written down in the doc comment. That is exactly the kind of thing to
    // clarify in an interview rather than assume — and four distinct error cases
    // (notFound / notADirectory / notAFile / alreadyExists) exist because
    // returning nil for all four gives the caller no way to say anything useful.
    public func mkdir(_ path: String) throws {
        var current = root
        for part in components(path) {
            guard current.isDirectory else { throw FSError.notADirectory }
            if let existing = current.children?[part] {
                guard existing.isDirectory else { throw FSError.alreadyExists }
                current = existing
            } else {
                let fresh = Node(directory: true)
                current.children?[part] = fresh
                current = fresh
            }
        }
    }

    public func writeFile(_ path: String, contents: String) throws {
        let parts = components(path)
        guard let name = parts.last else { throw FSError.invalidPath }
        var current = root
        for part in parts.dropLast() {
            guard let next = current.children?[part] else { throw FSError.notFound }
            guard next.isDirectory else { throw FSError.notADirectory }
            current = next
        }
        if let existing = current.children?[name], existing.isDirectory { throw FSError.alreadyExists }
        let file = Node(directory: false)
        file.contents = contents
        current.children?[name] = file
    }

    public func readFile(_ path: String) throws -> String {
        guard let node = node(at: path) else { throw FSError.notFound }
        guard let contents = node.contents, !node.isDirectory else { throw FSError.notAFile }
        return contents
    }

    public func ls(_ path: String) throws -> [String] {
        guard let node = node(at: path) else { throw FSError.notFound }
        guard let children = node.children else { throw FSError.notADirectory }
        return children.keys.sorted()
    }

    /// Composite: a file reports its own size, a directory sums its subtree.
    public func size(_ path: String) throws -> Int {
        guard let node = node(at: path) else { throw FSError.notFound }
        return Self.size(of: node)
    }

    private static func size(of node: Node) -> Int {
        if let children = node.children {
            return children.values.reduce(0) { $0 + size(of: $1) }
        }
        return node.contents?.utf8.count ?? 0
    }
}

// MARK: - SOLO 4 Job Scheduler

public struct Job: Equatable {
    public let name: String
    public let priority: Int
    public let dependsOn: [String]
    public init(name: String, priority: Int, dependsOn: [String] = []) {
        self.name = name; self.priority = priority; self.dependsOn = dependsOn
    }
}

public enum SchedulerError: Error, Equatable {
    case cycleDetected
    case unknownDependency(String)
    case duplicateJob(String)
}

public struct JobScheduler {
    private let jobs: [Job]
    public init(jobs: [Job]) { self.jobs = jobs }

    public func runOrder() throws -> [String] {
        var byName: [String: Job] = [:]
        for job in jobs {
            guard byName[job.name] == nil else { throw SchedulerError.duplicateJob(job.name) }
            byName[job.name] = job
        }
        for job in jobs {
            for dep in job.dependsOn where byName[dep] == nil {
                throw SchedulerError.unknownDependency(dep)
            }
        }

        // Kahn's algorithm, with a priority-aware choice among ready jobs.
        var remaining = Set(byName.keys)
        var done: Set<String> = []
        var order: [String] = []

        while !remaining.isEmpty {
            // THE KEY PROPERTY: priority only orders jobs that are ALREADY runnable.
            // A priority-100 job with an unmet dependency is not in `ready`, so it
            // cannot jump the queue. The mistake people make is sorting by priority
            // first and then trying to repair the order.
            //
            // Cycle detection falls out free: if work remains but nothing is ready,
            // every remaining job waits on another remaining job. No colouring, no
            // DFS stack.
            let ready = remaining
                .map { byName[$0]! }
                .filter { $0.dependsOn.allSatisfy(done.contains) }
            guard let next = ready.min(by: {
                $0.priority != $1.priority ? $0.priority > $1.priority : $0.name < $1.name
            }) else {
                throw SchedulerError.cycleDetected        // nothing runnable but work remains
            }
            order.append(next.name)
            done.insert(next.name)
            remaining.remove(next.name)
        }
        return order
    }
}

// MARK: - SOLO 5 Meeting Rooms

public struct Meeting: Equatable {
    public let id: String
    public let start: Int
    public let end: Int
    public init(id: String, start: Int, end: Int) { self.id = id; self.start = start; self.end = end }
    public func overlaps(_ other: Meeting) -> Bool { start < other.end && other.start < end }
}

public enum MeetingError: Error, Equatable { case roomBusy, invalidInterval }

public struct MeetingPlanner {
    public init() {}

    /// Sweep line: +1 at every start, -1 at every end; the peak is the room count.
    // Sweep line: walk sorted starts and ends together; the PEAK concurrent count
    // is the room count. `starts[i] < ends[j]` — strictly less — is what lets a
    // meeting ending at 10 and one starting at 10 share a room. Change it to <=
    // and you silently need an extra room for every back-to-back pair.
    //
    // Checking overlaps pairwise gives the wrong answer for three mutually
    // overlapping meetings, which is why that test exists.
    public func minimumRooms(_ meetings: [Meeting]) -> Int {
        let starts = meetings.map(\.start).sorted()
        let ends = meetings.map(\.end).sorted()
        var i = 0, j = 0, inUse = 0, peak = 0
        while i < starts.count {
            if starts[i] < ends[j] {
                inUse += 1
                peak = max(peak, inUse)
                i += 1
            } else {
                inUse -= 1
                j += 1
            }
        }
        return peak
    }

    public func assignRooms(_ meetings: [Meeting]) -> [String: Int] {
        var freeAt: [Int] = []                        // freeAt[room] = time the room frees up
        var assignment: [String: Int] = [:]
        for meeting in meetings.sorted(by: { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }) {
            if let room = freeAt.indices.first(where: { freeAt[$0] <= meeting.start }) {
                freeAt[room] = meeting.end
                assignment[meeting.id] = room
            } else {
                freeAt.append(meeting.end)
                assignment[meeting.id] = freeAt.count - 1
            }
        }
        return assignment
    }
}

public final class RoomCalendar {
    private var booked: [String: [Meeting]] = [:]
    public init() {}

    public func book(room: String, meeting: Meeting) throws {
        guard meeting.end > meeting.start else { throw MeetingError.invalidInterval }
        let existing = booked[room] ?? []
        guard !existing.contains(where: { $0.overlaps(meeting) }) else { throw MeetingError.roomBusy }
        booked[room] = (existing + [meeting]).sorted { $0.start < $1.start }
    }

    public func meetings(in room: String) -> [Meeting] { booked[room] ?? [] }
}
