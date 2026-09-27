import XCTest
@testable import M07

final class SpyObserver: PriceObserver, @unchecked Sendable {
    let observerID: String
    private(set) var received: [String] = []
    init(id: String) { self.observerID = id }
    func priceChanged(symbol: String, price: Decimal) { received.append("\(symbol)=\(price)") }
}

final class E1StrategyTests: XCTestCase {
    func test_hourly() { XCTAssertEqual(HourlyPricing(rate: 50).fee(hours: 3), 150) }
    func test_flat() { XCTAssertEqual(FlatPricing(amount: 200).fee(hours: 9), 200) }
    func test_freeThenHourly() {
        let p = FreeThenHourlyPricing(freeHours: 2, rate: 30)
        XCTAssertEqual(p.fee(hours: 1), 0)
        XCTAssertEqual(p.fee(hours: 2), 0)
        XCTAssertEqual(p.fee(hours: 5), 90)
        XCTAssertEqual(p.name, "free-2-then-hourly")
    }
    func test_lotSwapsStrategyAtRuntime() {
        let lot = ParkingLot7(pricing: HourlyPricing(rate: 50))
        XCTAssertEqual(lot.charge(hours: 2), 100)
        XCTAssertEqual(lot.pricingName, "hourly")
        lot.setPricing(FlatPricing(amount: 199))
        XCTAssertEqual(lot.charge(hours: 2), 199)
        XCTAssertEqual(lot.pricingName, "flat")
    }
    func test_lotAcceptsAStrategyItHasNeverSeen() {
        struct WeekendFree: PricingStrategy {
            var name: String { "weekend" }
            func fee(hours: Int) -> Decimal { 0 }
        }
        let lot = ParkingLot7(pricing: WeekendFree())
        XCTAssertEqual(lot.charge(hours: 100), 0)
    }
}

final class E2StateTests: XCTestCase {
    func test_startsIdle() {
        XCTAssertEqual(VendingMachine(stock: 2).stateName, "idle")
    }
    func test_selectBeforeCoin() {
        let m = VendingMachine(stock: 2)
        XCTAssertEqual(m.select("cola"), "insert a coin first")
        XCTAssertEqual(m.stateName, "idle")
    }
    func test_happyPath() {
        let m = VendingMachine(stock: 2)
        XCTAssertEqual(m.insertCoin(), "coin accepted")
        XCTAssertEqual(m.stateName, "hasMoney")
        XCTAssertEqual(m.select("cola"), "dispensing cola")
        XCTAssertEqual(m.stateName, "dispensing")
        XCTAssertEqual(m.dispense(), "dispensed cola")
        XCTAssertEqual(m.stateName, "idle")
        XCTAssertEqual(m.stock, 1)
    }
    func test_doubleCoin() {
        let m = VendingMachine(stock: 1)
        _ = m.insertCoin()
        XCTAssertEqual(m.insertCoin(), "coin already inserted")
    }
    func test_actionsDuringDispensingAreRejected() {
        let m = VendingMachine(stock: 1)
        _ = m.insertCoin(); _ = m.select("cola")
        XCTAssertEqual(m.insertCoin(), "please wait")
        XCTAssertEqual(m.select("chips"), "please wait")
    }
    func test_lastItemGoesToSoldOut() {
        let m = VendingMachine(stock: 1)
        _ = m.insertCoin(); _ = m.select("cola")
        XCTAssertEqual(m.dispense(), "dispensed cola")
        XCTAssertEqual(m.stateName, "soldOut")
        XCTAssertEqual(m.insertCoin(), "sold out")
        XCTAssertEqual(m.select("cola"), "sold out")
    }
    func test_selectingWithZeroStock() {
        let m = VendingMachine(stock: 0)
        _ = m.insertCoin()
        XCTAssertEqual(m.select("cola"), "sold out - refunded")
        XCTAssertEqual(m.stateName, "soldOut")
    }
}

final class E3ObserverTests: XCTestCase {
    func test_allSubscribersNotified() {
        let t = StockTicker()
        let a = SpyObserver(id: "a"), b = SpyObserver(id: "b")
        t.subscribe(a); t.subscribe(b)
        t.update(symbol: "AAPL", price: 100)
        XCTAssertEqual(a.received, ["AAPL=100"])
        XCTAssertEqual(b.received, ["AAPL=100"])
    }
    func test_unsubscribe() {
        let t = StockTicker()
        let a = SpyObserver(id: "a"), b = SpyObserver(id: "b")
        t.subscribe(a); t.subscribe(b); t.unsubscribe(a)
        t.update(symbol: "AAPL", price: 100)
        XCTAssertEqual(a.received, [])
        XCTAssertEqual(b.received, ["AAPL=100"])
    }
    func test_doubleSubscribeDoesNotDoubleNotify() {
        let t = StockTicker()
        let a = SpyObserver(id: "a")
        t.subscribe(a); t.subscribe(a)
        t.update(symbol: "X", price: 1)
        XCTAssertEqual(a.received, ["X=1"])
    }
    func test_observersAreHeldWeakly() {
        let t = StockTicker()
        do {
            let temp = SpyObserver(id: "temp")
            t.subscribe(temp)
            XCTAssertEqual(t.liveObserverCount, 1)
        }
        XCTAssertEqual(t.liveObserverCount, 0, "a deallocated observer must not be retained")
        t.update(symbol: "X", price: 1)          // must not crash
    }
    func test_unsubscribingDuringNotificationIsSafe() {
        final class SelfRemoving: PriceObserver, @unchecked Sendable {
            let observerID = "selfRemoving"
            weak var ticker: StockTicker?
            private(set) var count = 0
            func priceChanged(symbol: String, price: Decimal) {
                count += 1
                ticker?.unsubscribe(self)
            }
        }
        let t = StockTicker()
        let s = SelfRemoving(); s.ticker = t
        let other = SpyObserver(id: "other")
        t.subscribe(s); t.subscribe(other)
        t.update(symbol: "X", price: 1)
        t.update(symbol: "X", price: 2)
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(other.received, ["X=1", "X=2"])
    }
}

final class E4CommandTests: XCTestCase {
    func test_executeAndUndo() {
        let doc = TextDocument(), history = CommandHistory()
        history.run(AppendCommand(doc: doc, addition: "hello "))
        history.run(AppendCommand(doc: doc, addition: "world"))
        XCTAssertEqual(doc.text, "hello world")
        history.undo()
        XCTAssertEqual(doc.text, "hello ")
        history.undo()
        XCTAssertEqual(doc.text, "")
        XCTAssertFalse(history.canUndo)
    }
    func test_redo() {
        let doc = TextDocument(), history = CommandHistory()
        history.run(AppendCommand(doc: doc, addition: "abc"))
        history.undo()
        XCTAssertTrue(history.canRedo)
        history.redo()
        XCTAssertEqual(doc.text, "abc")
        XCTAssertFalse(history.canRedo)
    }
    func test_newCommandClearsRedoStack() {
        let doc = TextDocument(), history = CommandHistory()
        history.run(AppendCommand(doc: doc, addition: "abc"))
        history.undo()
        history.run(AppendCommand(doc: doc, addition: "xyz"))
        XCTAssertFalse(history.canRedo, "a new action must invalidate the redo stack")
        history.redo()
        XCTAssertEqual(doc.text, "xyz")
    }
    func test_mementoStyleUndoForIrreversibleCommand() {
        let doc = TextDocument(), history = CommandHistory()
        history.run(AppendCommand(doc: doc, addition: "Hello World"))
        history.run(UppercaseCommand(doc: doc))
        XCTAssertEqual(doc.text, "HELLO WORLD")
        history.undo()
        XCTAssertEqual(doc.text, "Hello World", "undo restores the snapshot, not an inverse operation")
    }
    func test_descriptions() {
        let doc = TextDocument(), history = CommandHistory()
        history.run(AppendCommand(doc: doc, addition: "a"))
        history.run(UppercaseCommand(doc: doc))
        XCTAssertEqual(history.undoDescriptions, ["append 'a'", "uppercase"])
    }
    func test_undoOnEmptyHistoryIsSafe() {
        CommandHistory().undo()
        CommandHistory().redo()
    }
}

final class E5ChainTests: XCTestCase {
    private func chain() -> any Approver {
        buildChain([TeamLead(), Manager7(), Director()])!
    }
    func test_firstHandler() { XCTAssertEqual(chain().approve(amount: 5_000), "TeamLead approved 5000") }
    func test_secondHandler() { XCTAssertEqual(chain().approve(amount: 50_000), "Manager approved 50000") }
    func test_thirdHandler() { XCTAssertEqual(chain().approve(amount: 900_000), "Director approved 900000") }
    func test_boundaryIsInclusive() { XCTAssertEqual(chain().approve(amount: 10_000), "TeamLead approved 10000") }
    func test_noHandler() { XCTAssertEqual(chain().approve(amount: 9_000_000), "rejected: 9000000") }
    func test_emptyChain() { XCTAssertNil(buildChain([])) }
    func test_reorderedChainChangesRouting() {
        let head = buildChain([Manager7(), Director()])!
        XCTAssertEqual(head.approve(amount: 5_000), "Manager approved 5000")
    }
}

final class E6TemplateTests: XCTestCase {
    func test_csvImporterDropsEmptyRows() {
        XCTAssertEqual(CSVImporter().run("ignored"), "saved 3")     // a,b,,c -> a,b,c
    }
    func test_rawImporterKeepsEmptyRows() {
        XCTAssertEqual(RawImporter().run("ignored"), "saved 4")
    }
    func test_skeletonIsShared() {
        XCTAssertEqual(CSVImporter().parse("x,y"), ["x", "y"])
        XCTAssertEqual(CSVImporter().validate(["a", "", "b"]), ["a", "b"])
        XCTAssertEqual(RawImporter().validate(["a", "", "b"]), ["a", "", "b"])
    }
}

final class E7IteratorTests: XCTestCase {
    private var tree: TreeNode7 {
        TreeNode7(value: 1, children: [
            TreeNode7(value: 2, children: [TreeNode7(value: 4), TreeNode7(value: 5)]),
            TreeNode7(value: 3, children: [TreeNode7(value: 6)]),
        ])
    }
    func test_depthFirst() {
        XCTAssertEqual(Array(DepthFirstSequence(root: tree)), [1, 2, 4, 5, 3, 6])
    }
    func test_breadthFirst() {
        XCTAssertEqual(Array(BreadthFirstSequence(root: tree)), [1, 2, 3, 4, 5, 6])
    }
    func test_singleNode() {
        XCTAssertEqual(Array(DepthFirstSequence(root: TreeNode7(value: 9))), [9])
        XCTAssertEqual(Array(BreadthFirstSequence(root: TreeNode7(value: 9))), [9])
    }
    /// Conforming to Sequence means every standard algorithm works for free.
    func test_sequenceAlgorithmsComeFree() {
        XCTAssertEqual(DepthFirstSequence(root: tree).filter { $0 % 2 == 0 }, [2, 4, 6])
        XCTAssertEqual(BreadthFirstSequence(root: tree).reduce(0, +), 21)
        XCTAssertEqual(Array(DepthFirstSequence(root: tree).prefix(3)), [1, 2, 4])
    }
}

final class E8MediatorTests: XCTestCase {
    func test_broadcastExcludesSender() {
        let room = ChatRoom()
        let a = ChatUser(name: "A"), b = ChatUser(name: "B"), c = ChatUser(name: "C")
        [a, b, c].forEach { room.register($0) }
        a.send("hi")
        XCTAssertEqual(a.inbox, [])
        XCTAssertEqual(b.inbox, ["A: hi"])
        XCTAssertEqual(c.inbox, ["A: hi"])
    }
    func test_usersDoNotReferenceEachOther() {
        let room = ChatRoom()
        let a = ChatUser(name: "A"), b = ChatUser(name: "B")
        room.register(a); room.register(b)
        b.send("yo"); a.send("sup")
        XCTAssertEqual(a.inbox, ["B: yo"])
        XCTAssertEqual(b.inbox, ["A: sup"])
    }
    func test_unregisteredUserSendingIsSafe() {
        ChatUser(name: "lonely").send("anyone?")
    }
}

final class E9NullObjectTests: XCTestCase {
    func test_defaultDoesNothing() {
        XCTAssertEqual(CheckoutService7().checkout(orderID: "o1"), "o1")
    }
    func test_realAnalyticsReceivesEvents() {
        let spy = RecordingAnalytics()
        _ = CheckoutService7(analytics: spy).checkout(orderID: "o1")
        XCTAssertEqual(spy.events, ["checkout_started", "checkout_completed"])
    }
}

final class E10IdentificationTests: XCTestCase {
    func test_mapping() {
        let expected: [BehavioralScenario: BehavioralPattern] = [
            .parkingFeeCanBeHourlyOrFlat: .strategy,
            .machineBehavesDifferentlyWhenIdleOrDispensing: .state,
            .notifyEveryDashboardWhenThePriceChanges: .observer,
            .supportUndoAndRedoOfEditorActions: .command,
            .tryTeamLeadThenManagerThenDirector: .chainOfResponsibility,
            .fiveFixedStepsWhereStepThreeDiffers: .templateMethod,
            .traverseTheTreeDepthFirstAndBreadthFirst: .iterator,
            .tenUIControlsThatAllAffectEachOther: .mediator,
            .snapshotTheDocumentToRestoreItLater: .memento,
            .keepAddingNewExportFormatsOverFixedNodeTypes: .visitor,
            .theLoggerDependencyIsOptional: .nullObject,
        ]
        for s in BehavioralScenario.allCases {
            XCTAssertEqual(behavioralPattern(for: s), expected[s], "wrong pattern for \(s.rawValue)")
        }
    }
}
