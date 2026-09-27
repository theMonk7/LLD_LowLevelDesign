//  Module 07 — Behavioural pattern exercises.
//
//  BEFORE YOU TYPE: behaviour is a thing you can MOVE. For each exercise, ask who
//  should own the decision:
//    E1  WHO CHOOSES the algorithm — the client, or the object itself?
//    E2  does behaviour change over the object's own LIFETIME, and do the
//        alternatives know about each other? (Then each state owns its rules and
//        there is no switch anywhere.)
//    E3  three things break every naive notifier: lifetime, re-entrancy,
//        duplicates. Handle all three.
//    E4  can this operation be reversed by an INVERSE, or must it be reversed by a
//        SNAPSHOT? And what invalidates the redo history?
//    E5  what happens when NOBODY handles the request?
//    E6  which steps must a conformer be able to override — those go in the
//        protocol body, not only the extension.
//    E7  in Swift, "implement Iterator" means "conform to Sequence".
//    E8  does the coordinator hold business rules? It must not.
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 Strategy

public protocol PricingStrategy {
    var name: String { get }
    func fee(hours: Int) -> Decimal
}

public struct HourlyPricing: PricingStrategy {
    public let rate: Decimal
    public init(rate: Decimal) { self.rate = rate }
    public var name: String { fatalError("TODO E1a") }              // "hourly"
    public func fee(hours: Int) -> Decimal { fatalError("TODO E1a") }
}

public struct FlatPricing: PricingStrategy {
    public let amount: Decimal
    public init(amount: Decimal) { self.amount = amount }
    public var name: String { fatalError("TODO E1b") }              // "flat"
    public func fee(hours: Int) -> Decimal { fatalError("TODO E1b") }
}

/// First `freeHours` are free, every hour after that costs `rate`.
public struct FreeThenHourlyPricing: PricingStrategy {
    public let freeHours: Int
    public let rate: Decimal
    public init(freeHours: Int, rate: Decimal) { self.freeHours = freeHours; self.rate = rate }
    public var name: String { fatalError("TODO E1c") }              // "free-<n>-then-hourly"
    public func fee(hours: Int) -> Decimal { fatalError("TODO E1c") }
}

public final class ParkingLot7 {
    private var pricing: any PricingStrategy
    public init(pricing: any PricingStrategy) { fatalError("TODO E1d") }
    public func setPricing(_ p: any PricingStrategy) { fatalError("TODO E1d") }
    public var pricingName: String { fatalError("TODO E1d") }
    public func charge(hours: Int) -> Decimal { fatalError("TODO E1d") }
}

// MARK: - E2 State (a vending machine with no switch statements)

public protocol VendingState {
    var name: String { get }
    func insertCoin(_ machine: VendingMachine) -> String
    func select(_ item: String, _ machine: VendingMachine) -> String
    func dispense(_ machine: VendingMachine) -> String
}

public final class VendingMachine {
    public private(set) var state: any VendingState
    public private(set) var stock: Int
    public private(set) var pendingItem: String?

    public init(stock: Int) { fatalError("TODO E2a") }              // starts in IdleState

    public func transition(to next: any VendingState) { fatalError("TODO E2a") }
    public func setPendingItem(_ item: String?) { fatalError("TODO E2a") }
    public func decrementStock() { fatalError("TODO E2a") }

    public func insertCoin() -> String { fatalError("TODO E2a") }
    public func select(_ item: String) -> String { fatalError("TODO E2a") }
    public func dispense() -> String { fatalError("TODO E2a") }
    public var stateName: String { fatalError("TODO E2a") }
}

/// Idle: insertCoin -> HasMoney, "coin accepted". select -> "insert a coin first".
/// dispense -> "nothing to dispense".
public struct IdleState: VendingState {
    public init() {}
    public var name: String { fatalError("TODO E2b") }              // "idle"
    public func insertCoin(_ m: VendingMachine) -> String { fatalError("TODO E2b") }
    public func select(_ item: String, _ m: VendingMachine) -> String { fatalError("TODO E2b") }
    public func dispense(_ m: VendingMachine) -> String { fatalError("TODO E2b") }
}

/// HasMoney: insertCoin -> "coin already inserted".
/// select: stock > 0 -> set pending item, go to DispensingState, "dispensing <item>";
///         stock == 0 -> go to SoldOutState, "sold out - refunded".
/// dispense -> "select an item first".
public struct HasMoneyState: VendingState {
    public init() {}
    public var name: String { fatalError("TODO E2c") }              // "hasMoney"
    public func insertCoin(_ m: VendingMachine) -> String { fatalError("TODO E2c") }
    public func select(_ item: String, _ m: VendingMachine) -> String { fatalError("TODO E2c") }
    public func dispense(_ m: VendingMachine) -> String { fatalError("TODO E2c") }
}

/// Dispensing: insertCoin / select -> "please wait".
/// dispense: decrement stock, clear the pending item, then go to
///           SoldOutState if stock hit 0 else IdleState; returns "dispensed <item>".
public struct DispensingState: VendingState {
    public init() {}
    public var name: String { fatalError("TODO E2d") }              // "dispensing"
    public func insertCoin(_ m: VendingMachine) -> String { fatalError("TODO E2d") }
    public func select(_ item: String, _ m: VendingMachine) -> String { fatalError("TODO E2d") }
    public func dispense(_ m: VendingMachine) -> String { fatalError("TODO E2d") }
}

/// SoldOut: everything -> "sold out".
public struct SoldOutState: VendingState {
    public init() {}
    public var name: String { fatalError("TODO E2e") }              // "soldOut"
    public func insertCoin(_ m: VendingMachine) -> String { fatalError("TODO E2e") }
    public func select(_ item: String, _ m: VendingMachine) -> String { fatalError("TODO E2e") }
    public func dispense(_ m: VendingMachine) -> String { fatalError("TODO E2e") }
}

// MARK: - E3 Observer (weak storage, safe unsubscribe)

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

    public func subscribe(_ o: any PriceObserver) { fatalError("TODO E3a") }
    public func unsubscribe(_ o: any PriceObserver) { fatalError("TODO E3b") }

    /// Notifies every live observer. Must iterate a SNAPSHOT so an observer may
    /// subscribe or unsubscribe during notification without breaking the loop.
    /// Dead (deallocated) observers must be purged.
    public func update(symbol: String, price: Decimal) { fatalError("TODO E3c") }

    /// Number of observers still alive.
    public var liveObserverCount: Int { fatalError("TODO E3d") }
}

// MARK: - E4 Command + Memento (undo / redo)

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
    public var describe: String { fatalError("TODO E4a") }          // "append '<addition>'"
    public func execute() { fatalError("TODO E4a") }
    public func undo() { fatalError("TODO E4a") }
}

/// Uppercases the whole document. Not reversible by arithmetic, so it snapshots
/// the previous text (a Memento) at execute() time.
public final class UppercaseCommand: Command {
    private let doc: TextDocument
    private var snapshot: String?
    public init(doc: TextDocument) { self.doc = doc }
    public var describe: String { fatalError("TODO E4b") }          // "uppercase"
    public func execute() { fatalError("TODO E4b") }
    public func undo() { fatalError("TODO E4b") }
}

public final class CommandHistory {
    private var undoStack: [any Command] = []
    private var redoStack: [any Command] = []
    public init() {}

    /// Executes, pushes to the undo stack, and CLEARS the redo stack.
    public func run(_ c: any Command) { fatalError("TODO E4c") }
    public func undo() { fatalError("TODO E4c") }
    public func redo() { fatalError("TODO E4c") }
    public var undoDescriptions: [String] { fatalError("TODO E4c") }   // oldest first
    public var canUndo: Bool { fatalError("TODO E4c") }
    public var canRedo: Bool { fatalError("TODO E4c") }
}

// MARK: - E5 Chain of Responsibility

public protocol Approver: AnyObject {
    var next: (any Approver)? { get set }
    var title: String { get }
    var limit: Decimal { get }
    func approve(amount: Decimal) -> String
}

public extension Approver {
    /// Approves when amount <= limit ("<title> approved <amount>"),
    /// otherwise delegates to `next`, or returns "rejected: <amount>" when the chain ends.
    func handle(_ amount: Decimal) -> String { fatalError("TODO E5a") }
}

public final class TeamLead: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { fatalError("TODO E5b") }             // "TeamLead"
    public var limit: Decimal { fatalError("TODO E5b") }            // 10_000
    public func approve(amount: Decimal) -> String { fatalError("TODO E5b") }
}

public final class Manager7: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { fatalError("TODO E5c") }             // "Manager"
    public var limit: Decimal { fatalError("TODO E5c") }            // 100_000
    public func approve(amount: Decimal) -> String { fatalError("TODO E5c") }
}

public final class Director: Approver {
    public var next: (any Approver)?
    public init() {}
    public var title: String { fatalError("TODO E5d") }             // "Director"
    public var limit: Decimal { fatalError("TODO E5d") }            // 1_000_000
    public func approve(amount: Decimal) -> String { fatalError("TODO E5d") }
}

/// Links the approvers in order and returns the head of the chain.
public func buildChain(_ approvers: [any Approver]) -> (any Approver)? { fatalError("TODO E5e") }

// MARK: - E6 Template Method (protocol + extension form)

public protocol Importer {
    /// Required step — each importer parses differently.
    func parse(_ raw: String) -> [String]
    /// Overridable hook with a default.
    func validate(_ rows: [String]) -> [String]
}

public extension Importer {
    func read(_ path: String) -> String { "a,b,,c" }
    func validate(_ rows: [String]) -> [String] { fatalError("TODO E6a") }   // drops empty rows
    func save(_ rows: [String]) -> String { "saved \(rows.count)" }
    /// The template: read -> parse -> validate -> save. Must not be overridable in practice.
    func run(_ path: String) -> String { fatalError("TODO E6a") }
}

public struct CSVImporter: Importer {
    public init() {}
    public func parse(_ raw: String) -> [String] { fatalError("TODO E6b") }  // split on ","
}

/// Same skeleton, but keeps empty rows (overrides the hook).
public struct RawImporter: Importer {
    public init() {}
    public func parse(_ raw: String) -> [String] { fatalError("TODO E6c") }  // split on "," keeping empties
    public func validate(_ rows: [String]) -> [String] { fatalError("TODO E6c") }
}

// MARK: - E7 Iterator (custom traversal orders)

public final class TreeNode7 {
    public let value: Int
    public let children: [TreeNode7]
    public init(value: Int, children: [TreeNode7] = []) { self.value = value; self.children = children }
}

/// Depth-first preorder.
public struct DepthFirstSequence: Sequence {
    private let root: TreeNode7
    public init(root: TreeNode7) { self.root = root }
    public func makeIterator() -> AnyIterator<Int> { fatalError("TODO E7a") }
}

/// Level order.
public struct BreadthFirstSequence: Sequence {
    private let root: TreeNode7
    public init(root: TreeNode7) { self.root = root }
    public func makeIterator() -> AnyIterator<Int> { fatalError("TODO E7b") }
}

// MARK: - E8 Mediator

public protocol ChatMediator: AnyObject {
    func register(_ user: ChatUser)
    func send(_ message: String, from sender: ChatUser)
}

public final class ChatRoom: ChatMediator {
    private var users: [ChatUser] = []
    public init() {}
    public func register(_ user: ChatUser) { fatalError("TODO E8a") }        // also sets user.room = self
    /// Delivers to everyone EXCEPT the sender, in registration order.
    public func send(_ message: String, from sender: ChatUser) { fatalError("TODO E8a") }
}

public final class ChatUser {
    public let name: String
    public weak var room: (any ChatMediator)?
    public private(set) var inbox: [String] = []
    public init(name: String) { self.name = name }
    public func send(_ m: String) { fatalError("TODO E8b") }
    public func receive(_ m: String, from: String) { fatalError("TODO E8b") } // appends "<from>: <m>"
}

// MARK: - E9 Null Object

public protocol Analytics7 { func track(_ event: String) }

public final class RecordingAnalytics: Analytics7 {
    public private(set) var events: [String] = []
    public init() {}
    public func track(_ event: String) { events.append(event) }
}

/// Does nothing, successfully.
public struct NoOpAnalytics: Analytics7 {
    public init() {}
    public func track(_ event: String) { fatalError("TODO E9a") }
}

public struct CheckoutService7 {
    private let analytics: any Analytics7
    /// Defaults to the null object so call sites never write `if let`.
    public init(analytics: any Analytics7 = NoOpAnalytics()) { fatalError("TODO E9b") }
    /// Tracks "checkout_started" then "checkout_completed"; returns the order id.
    public func checkout(orderID: String) -> String { fatalError("TODO E9b") }
}

// MARK: - E10 — pattern identification

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

public func behavioralPattern(for s: BehavioralScenario) -> BehavioralPattern { fatalError("TODO E10") }
