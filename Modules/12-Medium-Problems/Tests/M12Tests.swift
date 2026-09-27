import XCTest
@testable import M12

final class S1LFUTests: XCTestCase {
    func test_basicGetPut() {
        let c = LFUCache<String, Int>(capacity: 2)
        c.put("a", 1); c.put("b", 2)
        XCTAssertEqual(c.get("a"), 1)
        XCTAssertNil(c.get("zz"))
        XCTAssertEqual(c.count, 2)
    }
    func test_evictsLeastFrequent() {
        let c = LFUCache<String, Int>(capacity: 2)
        c.put("a", 1); c.put("b", 2)
        _ = c.get("a"); _ = c.get("a")        // a: 3 uses, b: 1 use
        c.put("c", 3)
        XCTAssertEqual(c.evictedKeys, ["b"])
        XCTAssertNil(c.get("b"))
        XCTAssertEqual(c.get("a"), 1)
    }
    func test_tieBrokenByLeastRecentlyUsed() {
        let c = LFUCache<String, Int>(capacity: 2)
        c.put("a", 1)          // a freq 1
        c.put("b", 2)          // b freq 1, more recent
        c.put("c", 3)          // tie on frequency -> evict the older, a
        XCTAssertEqual(c.evictedKeys, ["a"])
        XCTAssertEqual(c.get("b"), 2)
    }
    func test_putOnExistingKeyUpdatesAndCounts() {
        let c = LFUCache<String, Int>(capacity: 2)
        c.put("a", 1); c.put("a", 9)
        XCTAssertEqual(c.get("a"), 9)
        XCTAssertEqual(c.frequency(of: "a"), 3)
        XCTAssertEqual(c.count, 1)
    }
    func test_frequencyTracking() {
        let c = LFUCache<String, Int>(capacity: 3)
        c.put("a", 1)
        _ = c.get("a"); _ = c.get("a")
        XCTAssertEqual(c.frequency(of: "a"), 3)
        XCTAssertEqual(c.frequency(of: "missing"), 0)
    }
}

final class S2CouponTests: XCTestCase {
    private var engine: CouponEngine {
        CouponEngine(coupons: [
            PercentageCoupon(code: "SAVE10", percent: 10, maxDiscount: 200, minSubtotal: 500),
            FlatCoupon(code: "FLAT150", amount: 150, minSubtotal: 1_000),
            CategoryCoupon(code: "NEWFOOD", category: "food", percent: 25, firstOrderOnly: true),
        ])
    }
    func test_percentageRespectsMinimum() {
        XCTAssertNil(PercentageCoupon(code: "X", percent: 10, maxDiscount: 200, minSubtotal: 500)
            .discount(for: Order12(subtotal: 400, category: "food")))
    }
    func test_percentageIsCapped() {
        XCTAssertEqual(PercentageCoupon(code: "X", percent: 10, maxDiscount: 200, minSubtotal: 500)
            .discount(for: Order12(subtotal: 5_000, category: "food")), 200)
    }
    func test_flatNeverExceedsSubtotal() {
        XCTAssertEqual(FlatCoupon(code: "X", amount: 5_000, minSubtotal: 100)
            .discount(for: Order12(subtotal: 800, category: "x")), 800)
    }
    func test_categoryCouponRules() {
        let c = CategoryCoupon(code: "X", category: "food", percent: 25, firstOrderOnly: true)
        XCTAssertNil(c.discount(for: Order12(subtotal: 1_000, category: "books", isFirstOrder: true)))
        XCTAssertNil(c.discount(for: Order12(subtotal: 1_000, category: "food", isFirstOrder: false)))
        XCTAssertEqual(c.discount(for: Order12(subtotal: 1_000, category: "food", isFirstOrder: true)), 250)
    }
    func test_bestCouponWins() {
        let best = engine.bestCoupon(for: Order12(subtotal: 1_000, category: "food", isFirstOrder: true))
        XCTAssertEqual(best?.code, "NEWFOOD")
        XCTAssertEqual(best?.discount, 250)
    }
    func test_bestCouponWhenCategoryDoesNotApply() {
        let best = engine.bestCoupon(for: Order12(subtotal: 1_000, category: "books", isFirstOrder: true))
        XCTAssertEqual(best?.code, "FLAT150")
    }
    func test_noCouponApplies() {
        XCTAssertNil(engine.bestCoupon(for: Order12(subtotal: 100, category: "books")))
        XCTAssertEqual(engine.finalTotal(for: Order12(subtotal: 100, category: "books")), 100)
    }
    func test_finalTotal() {
        XCTAssertEqual(engine.finalTotal(for: Order12(subtotal: 1_000, category: "food", isFirstOrder: true)), 750)
    }
    /// A coupon type the engine has never seen must work unchanged.
    func test_engineIsOpenForNewCouponTypes() {
        struct AlwaysHalf: Coupon {
            let code = "AAA"
            func discount(for order: Order12) -> Decimal? { order.subtotal / 2 }
        }
        let e = CouponEngine(coupons: [AlwaysHalf(),
                                       FlatCoupon(code: "FLAT150", amount: 150, minSubtotal: 0)])
        XCTAssertEqual(e.bestCoupon(for: Order12(subtotal: 1_000, category: "x"))?.code, "AAA")
    }
}

final class S3FileSystemTests: XCTestCase {
    private func loaded() throws -> FileSystem {
        let fs = FileSystem()
        try fs.mkdir("/a/b")
        try fs.writeFile("/a/b/one.txt", contents: "hello")      // 5
        try fs.writeFile("/a/two.txt", contents: "hi")           // 2
        return fs
    }
    func test_mkdirIsRecursive() throws {
        let fs = try loaded()
        XCTAssertEqual(try fs.ls("/"), ["a"])
        XCTAssertEqual(try fs.ls("/a").sorted(), ["b", "two.txt"])
    }
    func test_readWrite() throws {
        let fs = try loaded()
        XCTAssertEqual(try fs.readFile("/a/b/one.txt"), "hello")
    }
    func test_overwrite() throws {
        let fs = try loaded()
        try fs.writeFile("/a/two.txt", contents: "changed")
        XCTAssertEqual(try fs.readFile("/a/two.txt"), "changed")
        XCTAssertEqual(try fs.ls("/a").sorted(), ["b", "two.txt"])
    }
    func test_sizeIsRecursive() throws {
        let fs = try loaded()
        XCTAssertEqual(try fs.size("/"), 7)
        XCTAssertEqual(try fs.size("/a/b"), 5)
        XCTAssertEqual(try fs.size("/a/two.txt"), 2)
    }
    func test_errors() throws {
        let fs = try loaded()
        XCTAssertThrowsError(try fs.readFile("/nope")) { XCTAssertEqual($0 as? FSError, .notFound) }
        XCTAssertThrowsError(try fs.readFile("/a")) { XCTAssertEqual($0 as? FSError, .notAFile) }
        XCTAssertThrowsError(try fs.ls("/a/two.txt")) { XCTAssertEqual($0 as? FSError, .notADirectory) }
        XCTAssertThrowsError(try fs.writeFile("/missing/x.txt", contents: "x")) {
            XCTAssertEqual($0 as? FSError, .notFound)
        }
    }
    func test_emptyDirectory() throws {
        let fs = FileSystem()
        try fs.mkdir("/empty")
        XCTAssertEqual(try fs.ls("/empty"), [])
        XCTAssertEqual(try fs.size("/empty"), 0)
    }
}

final class S4SchedulerTests: XCTestCase {
    func test_respectsDependencies() throws {
        let s = JobScheduler(jobs: [
            Job(name: "deploy", priority: 1, dependsOn: ["build", "test"]),
            Job(name: "build", priority: 1),
            Job(name: "test", priority: 1, dependsOn: ["build"]),
        ])
        XCTAssertEqual(try s.runOrder(), ["build", "test", "deploy"])
    }
    func test_priorityAmongReadyJobs() throws {
        let s = JobScheduler(jobs: [
            Job(name: "low", priority: 1),
            Job(name: "high", priority: 9),
            Job(name: "mid", priority: 5),
        ])
        XCTAssertEqual(try s.runOrder(), ["high", "mid", "low"])
    }
    func test_tieBrokenByName() throws {
        let s = JobScheduler(jobs: [
            Job(name: "zeta", priority: 5),
            Job(name: "alpha", priority: 5),
        ])
        XCTAssertEqual(try s.runOrder(), ["alpha", "zeta"])
    }
    func test_priorityNeverBreaksDependencies() throws {
        let s = JobScheduler(jobs: [
            Job(name: "urgent", priority: 100, dependsOn: ["slow"]),
            Job(name: "slow", priority: 1),
        ])
        XCTAssertEqual(try s.runOrder(), ["slow", "urgent"])
    }
    func test_cycle() {
        let s = JobScheduler(jobs: [
            Job(name: "a", priority: 1, dependsOn: ["b"]),
            Job(name: "b", priority: 1, dependsOn: ["a"]),
        ])
        XCTAssertThrowsError(try s.runOrder()) { XCTAssertEqual($0 as? SchedulerError, .cycleDetected) }
    }
    func test_unknownDependency() {
        let s = JobScheduler(jobs: [Job(name: "a", priority: 1, dependsOn: ["ghost"])])
        XCTAssertThrowsError(try s.runOrder()) {
            XCTAssertEqual($0 as? SchedulerError, .unknownDependency("ghost"))
        }
    }
    func test_duplicateJob() {
        let s = JobScheduler(jobs: [Job(name: "a", priority: 1), Job(name: "a", priority: 2)])
        XCTAssertThrowsError(try s.runOrder()) {
            XCTAssertEqual($0 as? SchedulerError, .duplicateJob("a"))
        }
    }
    func test_emptyGraph() throws {
        XCTAssertEqual(try JobScheduler(jobs: []).runOrder(), [])
    }
}

final class S5MeetingTests: XCTestCase {
    private let meetings = [
        Meeting(id: "m1", start: 0, end: 30),
        Meeting(id: "m2", start: 5, end: 10),
        Meeting(id: "m3", start: 15, end: 20),
        Meeting(id: "m4", start: 30, end: 40),
    ]
    func test_overlap() {
        XCTAssertTrue(Meeting(id: "a", start: 0, end: 10).overlaps(Meeting(id: "b", start: 5, end: 15)))
        XCTAssertFalse(Meeting(id: "a", start: 0, end: 10).overlaps(Meeting(id: "b", start: 10, end: 20)),
                       "end is exclusive: back-to-back meetings do not overlap")
    }
    func test_minimumRooms() {
        XCTAssertEqual(MeetingPlanner().minimumRooms(meetings), 2)
        XCTAssertEqual(MeetingPlanner().minimumRooms([]), 0)
        XCTAssertEqual(MeetingPlanner().minimumRooms([Meeting(id: "x", start: 0, end: 1)]), 1)
    }
    func test_minimumRoomsWithTripleOverlap() {
        XCTAssertEqual(MeetingPlanner().minimumRooms([
            Meeting(id: "a", start: 0, end: 10),
            Meeting(id: "b", start: 1, end: 10),
            Meeting(id: "c", start: 2, end: 10),
        ]), 3)
    }
    func test_assignment() {
        let assignment = MeetingPlanner().assignRooms(meetings)
        XCTAssertEqual(assignment["m1"], 0)
        XCTAssertEqual(assignment["m2"], 1)
        XCTAssertEqual(assignment["m3"], 1, "m3 reuses room 1 because m2 has ended")
        XCTAssertEqual(assignment["m4"], 0, "m4 starts exactly when m1 ends")
    }
    func test_calendarBooking() throws {
        let cal = RoomCalendar()
        try cal.book(room: "R1", meeting: Meeting(id: "a", start: 0, end: 10))
        XCTAssertThrowsError(try cal.book(room: "R1", meeting: Meeting(id: "b", start: 5, end: 15))) {
            XCTAssertEqual($0 as? MeetingError, .roomBusy)
        }
        try cal.book(room: "R1", meeting: Meeting(id: "c", start: 10, end: 20))
        XCTAssertEqual(cal.meetings(in: "R1").map(\.id), ["a", "c"])
    }
    func test_invalidInterval() {
        let cal = RoomCalendar()
        XCTAssertThrowsError(try cal.book(room: "R1", meeting: Meeting(id: "a", start: 10, end: 10))) {
            XCTAssertEqual($0 as? MeetingError, .invalidInterval)
        }
    }
}
