//  Module 07 reference solutions.
//
//  HOW TO READ THIS FILE
//  Behavioural patterns are about WHERE A DECISION LIVES. For each one the
//  comments answer: which decision moved, who owns it now, and what becomes
//  possible that was not possible before (undo, queueing, swapping, notifying).
//
//  Pay special attention to the Observer comments — three of the four hazards
//  there are invisible in a sequential test and appear only in production.
//
//  Not part of the M07 target.

import Foundation

// MARK: - E1 Strategy

public protocol PricingStrategy {
    var name: String { get }
    func fee(hours: Int) -> Decimal
}

public struct HourlyPricing: PricingStrategy {
    public let rate: Decimal
    public init(rate: Decimal) { self.rate = rate }
    public var name: String { "hourly" }
    public func fee(hours: Int) -> Decimal { Decimal(hours) * rate }
}

public struct FlatPricing: PricingStrategy {
    public let amount: Decimal
    public init(amount: Decimal) { self.amount = amount }
    public var name: String { "flat" }
    public func fee(hours: Int) -> Decimal { amount }
}

public struct FreeThenHourlyPricing: PricingStrategy {
    public let freeHours: Int
    public let rate: Decimal
    public init(freeHours: Int, rate: Decimal) { self.freeHours = freeHours; self.rate = rate }
    public var name: String { "free-\(freeHours)-then-hourly" }
    public func fee(hours: Int) -> Decimal { Decimal(max(0, hours - freeHours)) * rate }
}

// `pricing` is a `var`, and that single keyword is the difference between
// Strategy and Bridge: the CLIENT swaps it at runtime. In Bridge the
// implementation side is normally fixed at construction and both hierarchies are
// first-class. The code looks the same; the intent does not.
//
// In production Swift this would often be `let fee: (Int) -> Decimal`. The
// protocol earns its place here because `name` is needed for receipts and audit —
// a closure cannot be printed, persisted or compared.
public final class ParkingLot7 {
    private var pricing: any PricingStrategy
    public init(pricing: any PricingStrategy) { self.pricing = pricing }
    public func setPricing(_ p: any PricingStrategy) { pricing = p }
    public var pricingName: String { pricing.name }
    public func charge(hours: Int) -> Decimal { pricing.fee(hours: hours) }
}

// MARK: - E2 State

public protocol VendingState {
    var name: String { get }
    func insertCoin(_ machine: VendingMachine) -> String
    func select(_ item: String, _ machine: VendingMachine) -> String
    func dispense(_ machine: VendingMachine) -> String
}

// THE DIVISION OF LABOUR: the machine owns the DATA, each state owns the RULES.
//
// `pendingItem` lives here, not on a state, because it must survive a transition —
// put it on DispensingState and it vanishes the moment you move on. That is a
// real bug people ship. Ask of every piece of state: does it outlive the state
// that uses it?
//
// And note there is not one `switch` in this entire design. "What happens if you
// press select while dispensing?" has exactly one place to look.
public final class VendingMachine {
    public private(set) var state: any VendingState
    public private(set) var stock: Int
    public private(set) var pendingItem: String?

    public init(stock: Int) { self.stock = stock; self.state = IdleState() }

    public func transition(to next: any VendingState) { state = next }
    public func setPendingItem(_ item: String?) { pendingItem = item }
    public func decrementStock() { stock = max(0, stock - 1) }

    public func insertCoin() -> String { state.insertCoin(self) }
    public func select(_ item: String) -> String { state.select(item, self) }
    public func dispense() -> String { state.dispense(self) }
    public var stateName: String { state.name }
}

public struct IdleState: VendingState {
    public init() {}
    public var name: String { "idle" }
    public func insertCoin(_ m: VendingMachine) -> String { m.transition(to: HasMoneyState()); return "coin accepted" }
    public func select(_ item: String, _ m: VendingMachine) -> String { "insert a coin first" }
    public func dispense(_ m: VendingMachine) -> String { "nothing to dispense" }
}

public struct HasMoneyState: VendingState {
    public init() {}
    public var name: String { "hasMoney" }
    public func insertCoin(_ m: VendingMachine) -> String { "coin already inserted" }
    public func select(_ item: String, _ m: VendingMachine) -> String {
        guard m.stock > 0 else { m.transition(to: SoldOutState()); return "sold out - refunded" }
        m.setPendingItem(item)
        m.transition(to: DispensingState())
        return "dispensing \(item)"
    }
    public func dispense(_ m: VendingMachine) -> String { "select an item first" }
}

public struct DispensingState: VendingState {
    public init() {}
    public var name: String { "dispensing" }
    public func insertCoin(_ m: VendingMachine) -> String { "please wait" }
    public func select(_ item: String, _ m: VendingMachine) -> String { "please wait" }
    public func dispense(_ m: VendingMachine) -> String {
        let item = m.pendingItem ?? "item"
        m.decrementStock()
        m.setPendingItem(nil)
        m.transition(to: m.stock == 0 ? SoldOutState() : IdleState())
        return "dispensed \(item)"
    }
}

public struct SoldOutState: VendingState {
    public init() {}
    public var name: String { "soldOut" }
    public func insertCoin(_ m: VendingMachine) -> String { "sold out" }
    public func select(_ item: String, _ m: VendingMachine) -> String { "sold out" }
    public func dispense(_ m: VendingMachine) -> String { "sold out" }
}

// MARK: - E3 Observer

public protocol PriceObserver: AnyObject {
    var observerID: String { get }
    func priceChanged(symbol: String, price: Decimal)
}

public final class StockTicker {
    private final class WeakBox {
        weak var value: (any PriceObserver)?
        init(_ v: any PriceObserver) { value = v }
    }
    private var boxes: [ObjectIdentifier: WeakBox] = [:]

    public init() {}

    public func subscribe(_ o: any PriceObserver) { boxes[ObjectIdentifier(o)] = WeakBox(o) }
    public func unsubscribe(_ o: any PriceObserver) { boxes[ObjectIdentifier(o)] = nil }

    // FOUR hazards, four mitigations, and every one of them is a real production
    // bug someone has shipped:
    //  1. RETAIN CYCLES   -> WeakBox, so the ticker never keeps a screen alive.
    //  2. RE-ENTRANCY     -> iterate a SNAPSHOT, because an observer may
    //                        unsubscribe while being notified.
    //  3. DUPLICATES      -> keyed by ObjectIdentifier, so subscribe() is
    //                        idempotent. With an array you get two callbacks,
    //                        which is how duplicate analytics events happen.
    //  4. ZOMBIES         -> purge(), so the dictionary does not grow forever.
    public func update(symbol: String, price: Decimal) {
        purge()
        let snapshot = boxes.values.compactMap(\.value)      // iterate a copy: safe re-entrancy
        snapshot.forEach { $0.priceChanged(symbol: symbol, price: price) }
    }

    public var liveObserverCount: Int {
        purge()
        return boxes.count
    }

    private func purge() { boxes = boxes.filter { $0.value.value != nil } }
}

// MARK: - E4 Command + Memento

public final class TextDocument {
    public private(set) var text: String = ""
    public init() {}
    public func append(_ s: String) { text += s }
    public func removeLast(_ n: Int) { text.removeLast(min(n, text.count)) }
    public func replaceAll(with s: String) { text = s }
}

public protocol Command {
    var describe: String { get }
    func execute()
    func undo()
}

public struct AppendCommand: Command {
    private let doc: TextDocument
    private let addition: String
    public init(doc: TextDocument, addition: String) { self.doc = doc; self.addition = addition }
    public var describe: String { "append '\(addition)'" }
    public func execute() { doc.append(addition) }
    public func undo() { doc.removeLast(addition.count) }
}

public final class UppercaseCommand: Command {
    private let doc: TextDocument
    private var snapshot: String?
    public init(doc: TextDocument) { self.doc = doc }
    public var describe: String { "uppercase" }
    public func execute() {
        snapshot = doc.text                                  // the memento
        doc.replaceAll(with: doc.text.uppercased())
    }
    public func undo() {
        guard let snapshot else { return }
        doc.replaceAll(with: snapshot)
    }
}

public final class CommandHistory {
    private var undoStack: [any Command] = []
    private var redoStack: [any Command] = []
    public init() {}

    // That third line is THE line. Without it: type "abc", undo, type "xyz", press
    // redo — and "abc" reappears on top of "xyz". Every undo system that feels
    // haunted is missing it.
    //
    // The two commands above show the two reversal strategies side by side:
    // AppendCommand stores the inverse operation (cheap, needs an inverse to
    // exist); UppercaseCommand stores a SNAPSHOT (always works, costs memory)
    // because you cannot recover "Hello World" from "HELLO WORLD".
    public func run(_ c: any Command) {
        c.execute()
        undoStack.append(c)
        redoStack.removeAll()                                // a new action invalidates redo
    }
    public func undo() {
        guard let c = undoStack.popLast() else { return }
        c.undo()
        redoStack.append(c)
    }
    public func redo() {
        guard let c = redoStack.popLast() else { return }
        c.execute()
        undoStack.append(c)
    }
    public var undoDescriptions: [String] { undoStack.map(\.describe) }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
}

// MARK: - E5 Chain of Responsibility

public protocol Approver: AnyObject {
    var next: (any Approver)? { get set }
    var title: String { get }
    var limit: Decimal { get }
    func approve(amount: Decimal) -> String
}

public extension Approver {
    // Routing lives once, in the extension, so each approver is three one-line
    // members. Adding a VP is a new type plus one line in buildChain.
    //
    // The terminal case is EXPLICIT: an unhandled request returns "rejected"
    // rather than vanishing. A chain that silently drops requests is the classic
    // bug — decide between a default handler, an error and a sentinel, and say
    // which you chose.
    func handle(_ amount: Decimal) -> String {
        if amount <= limit { return "\(title) approved \(amount)" }
        if let next { return next.approve(amount: amount) }
        return "rejected: \(amount)"
    }
}

public final class TeamLead: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { "TeamLead" }
    public var limit: Decimal { 10_000 }
    public func approve(amount: Decimal) -> String { handle(amount) }
}

public final class Manager7: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { "Manager" }
    public var limit: Decimal { 100_000 }
    public func approve(amount: Decimal) -> String { handle(amount) }
}

public final class Director: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { "Director" }
    public var limit: Decimal { 1_000_000 }
    public func approve(amount: Decimal) -> String { handle(amount) }
}

public func buildChain(_ approvers: [any Approver]) -> (any Approver)? {
    for (a, b) in zip(approvers, approvers.dropFirst()) { a.next = b }
    return approvers.first
}

// MARK: - E6 Template Method

public protocol Importer {
    func parse(_ raw: String) -> [String]
    func validate(_ rows: [String]) -> [String]
}

public extension Importer {
    func read(_ path: String) -> String { "a,b,,c" }
    func validate(_ rows: [String]) -> [String] { rows.filter { !$0.isEmpty } }
    func save(_ rows: [String]) -> String { "saved \(rows.count)" }
    // The template: four steps, fixed order, defined once. `parse` is declared in
    // the protocol body (required, dynamically dispatched); `validate` is declared
    // there too, which is WHY RawImporter can override it. `read` and `save` are
    // extension-only, so they are static — deliberately not overridable.
    //
    // Swift cannot mark an extension method `final`, so "the skeleton must not be
    // overridden" is a convention here. In a class-based version the compiler
    // would enforce it. Mention the gap; it is real.
    func run(_ path: String) -> String { save(validate(parse(read(path)))) }
}

public struct CSVImporter: Importer {
    public init() {}
    public func parse(_ raw: String) -> [String] {
        raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }
}

public struct RawImporter: Importer {
    public init() {}
    public func parse(_ raw: String) -> [String] {
        raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }
    public func validate(_ rows: [String]) -> [String] { rows }
}

// MARK: - E7 Iterator

public final class TreeNode7 {
    public let value: Int
    public let children: [TreeNode7]
    public init(value: Int, children: [TreeNode7] = []) { self.value = value; self.children = children }
}

public struct DepthFirstSequence: Sequence {
    private let root: TreeNode7
    public init(root: TreeNode7) { self.root = root }
    // Stack + reversed() gives preorder; queue + removeFirst() gives level order.
    // The captured mutable state inside the closure IS the iterator's state, which
    // is why this is four lines in Swift instead of a class.
    //
    // `reversed()` is easy to omit and silently gives [1,3,6,2,5,4] instead of
    // [1,2,4,5,3,6]. Understand it rather than memorising it.
    //
    // The real payoff is conformance to `Sequence`: filter, reduce, prefix, map and
    // lazy all arrive free. In Swift, "implement Iterator" means "conform to
    // Sequence" — hand-rolling a next() protocol is a red flag.
    public func makeIterator() -> AnyIterator<Int> {
        var stack = [root]
        return AnyIterator {
            guard let node = stack.popLast() else { return nil }
            stack.append(contentsOf: node.children.reversed())     // reversed keeps left-to-right order
            return node.value
        }
    }
}

public struct BreadthFirstSequence: Sequence {
    private let root: TreeNode7
    public init(root: TreeNode7) { self.root = root }
    public func makeIterator() -> AnyIterator<Int> {
        var queue = [root]
        return AnyIterator {
            guard !queue.isEmpty else { return nil }
            let node = queue.removeFirst()
            queue.append(contentsOf: node.children)
            return node.value
        }
    }
}

// MARK: - E8 Mediator

public protocol ChatMediator: AnyObject {
    func register(_ user: ChatUser)
    func send(_ message: String, from sender: ChatUser)
}

public final class ChatRoom: ChatMediator {
    private var users: [ChatUser] = []
    public init() {}
    public func register(_ user: ChatUser) { users.append(user); user.room = self }
    // Ten users through a mediator is ten edges, not forty-five. Adding a rule
    // ("muted users receive nothing") changes one place.
    //
    // The risk to name out loud: this type is one refactor away from owning
    // moderation, rate limiting, presence and delivery receipts — i.e. becoming
    // the God Object you were avoiding. Mediators COORDINATE; they must not
    // accumulate business policy. UIViewController is the cautionary tale.
    public func send(_ message: String, from sender: ChatUser) {
        users.filter { $0 !== sender }.forEach { $0.receive(message, from: sender.name) }
    }
}

public final class ChatUser {
    public let name: String
    public weak var room: (any ChatMediator)?
    public private(set) var inbox: [String] = []
    public init(name: String) { self.name = name }
    public func send(_ m: String) { room?.send(m, from: self) }
    public func receive(_ m: String, from: String) { inbox.append("\(from): \(m)") }
}

// MARK: - E9 Null Object

public protocol Analytics7 { func track(_ event: String) }

public final class RecordingAnalytics: Analytics7 {
    public private(set) var events: [String] = []
    public init() {}
    public func track(_ event: String) { events.append(event) }
}

// Safe here precisely because doing nothing is harmless. A no-op PAYMENT
// processor that silently "succeeds" would be a catastrophe — the question is
// always "is silence an acceptable outcome for this collaborator?"
public struct NoOpAnalytics: Analytics7 {
    public init() {}
    public func track(_ event: String) {}
}

public struct CheckoutService7 {
    private let analytics: any Analytics7
    public init(analytics: any Analytics7 = NoOpAnalytics()) { self.analytics = analytics }
    public func checkout(orderID: String) -> String {
        analytics.track("checkout_started")
        analytics.track("checkout_completed")
        return orderID
    }
}

// MARK: - E10

public enum BehavioralPattern: String, Equatable, CaseIterable {
    case strategy, state, observer, command, chainOfResponsibility
    case templateMethod, iterator, mediator, memento, visitor, nullObject
}

public enum BehavioralScenario: String, Equatable, CaseIterable {
    case parkingFeeCanBeHourlyOrFlat
    case machineBehavesDifferentlyWhenIdleOrDispensing
    case notifyEveryDashboardWhenThePriceChanges
    case supportUndoAndRedoOfEditorActions
    case tryTeamLeadThenManagerThenDirector
    case fiveFixedStepsWhereStepThreeDiffers
    case traverseTheTreeDepthFirstAndBreadthFirst
    case tenUIControlsThatAllAffectEachOther
    case snapshotTheDocumentToRestoreItLater
    case keepAddingNewExportFormatsOverFixedNodeTypes
    case theLoggerDependencyIsOptional
}

public func behavioralPattern(for s: BehavioralScenario) -> BehavioralPattern {
    switch s {
    case .parkingFeeCanBeHourlyOrFlat:                  .strategy
    case .machineBehavesDifferentlyWhenIdleOrDispensing: .state
    case .notifyEveryDashboardWhenThePriceChanges:      .observer
    case .supportUndoAndRedoOfEditorActions:            .command
    case .tryTeamLeadThenManagerThenDirector:           .chainOfResponsibility
    case .fiveFixedStepsWhereStepThreeDiffers:          .templateMethod
    case .traverseTheTreeDepthFirstAndBreadthFirst:     .iterator
    case .tenUIControlsThatAllAffectEachOther:          .mediator
    case .snapshotTheDocumentToRestoreItLater:          .memento
    case .keepAddingNewExportFormatsOverFixedNodeTypes: .visitor
    case .theLoggerDependencyIsOptional:                .nullObject
    }
}
