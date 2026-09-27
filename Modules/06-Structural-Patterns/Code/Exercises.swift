//  Module 06 — Structural pattern exercises.
//
//  BEFORE YOU TYPE: all of these wrap or arrange objects, so the question is
//  always WHAT DECISION IS THE WRAPPER MAKING?
//    did the interface change?                      -> translation (E1)
//    is a capability added, and can it stack?       -> layering (E4, E5)
//    is access controlled with nothing added?       -> a gate (E8)
//    is a new simpler interface over several things? -> a front door (E6)
//    is the structure recursive?                    -> container shares the leaf's
//                                                      contract (E3)
//    are there two independent axes?                -> separate hierarchies (E2)
//    is instance COUNT the problem?                 -> share the invariant part (E7)
//
//  For E4 and E5, also ask: does ORDER of composition change the answer? (It does.)
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 Adapter — translate shape, units and error model

/// The interface your domain wants. Amounts in paise, typed errors.
public protocol PaymentProcessor {
    func pay(amountInPaise: Int, orderID: String) throws -> String
}

/// A third-party SDK you cannot change. Rupees as Double, dictionary result, no errors.
public final class LegacyPayGateway {
    private let alwaysDeclineOver: Double
    public init(alwaysDeclineOver: Double = .greatestFiniteMagnitude) {
        self.alwaysDeclineOver = alwaysDeclineOver
    }
    public func makePayment(_ rupees: Double, ref: String, currency: String) -> [String: Any] {
        rupees > alwaysDeclineOver
            ? ["status": "DECLINED"]
            : ["status": "OK", "txn": "TXN-\(ref)-\(currency)"]
    }
}

public enum PaymentError: Error, Equatable { case declined, malformedResponse }

public struct LegacyPayAdapter: PaymentProcessor {
    private let sdk: LegacyPayGateway
    public init(sdk: LegacyPayGateway) { fatalError("TODO E1a") }

    /// Translate: paise -> rupees (divide by 100), currency is always "INR",
    /// "OK" + txn -> return txn, "DECLINED" -> throw .declined,
    /// anything else (missing txn) -> throw .malformedResponse.
    public func pay(amountInPaise: Int, orderID: String) throws -> String { fatalError("TODO E1b") }
}

// MARK: - E2 Bridge — two dimensions that vary independently

public protocol Renderer {
    func renderCircle(radius: Double) -> String
    func renderSquare(side: Double) -> String
}

public struct SVGRenderer: Renderer {
    public init() {}
    public func renderCircle(radius: Double) -> String { fatalError("TODO E2a") }   // "<circle r='2.0'/>"
    public func renderSquare(side: Double) -> String { fatalError("TODO E2a") }     // "<rect w='3.0'/>"
}

public struct ASCIIRenderer: Renderer {
    public init() {}
    public func renderCircle(radius: Double) -> String { fatalError("TODO E2b") }   // "O(2.0)"
    public func renderSquare(side: Double) -> String { fatalError("TODO E2b") }     // "[3.0]"
}

public protocol Shape6 { func draw() -> String }

public struct Circle6: Shape6 {
    private let radius: Double
    private let renderer: any Renderer
    public init(radius: Double, renderer: any Renderer) { fatalError("TODO E2c") }
    public func draw() -> String { fatalError("TODO E2c") }
}

public struct Square6: Shape6 {
    private let side: Double
    private let renderer: any Renderer
    public init(side: Double, renderer: any Renderer) { fatalError("TODO E2d") }
    public func draw() -> String { fatalError("TODO E2d") }
}

// MARK: - E3 Composite — one and many treated the same

public protocol FileSystemItem {
    var name: String { get }
    func size() -> Int
    /// Full paths of this item and everything under it, depth-first, parents before children.
    func paths(prefix: String) -> [String]
}

public struct FileItem: FileSystemItem {
    public let name: String
    public let bytes: Int
    public init(name: String, bytes: Int) { self.name = name; self.bytes = bytes }
    public func size() -> Int { fatalError("TODO E3a") }
    public func paths(prefix: String) -> [String] { fatalError("TODO E3a") }   // ["<prefix>/<name>"]
}

public struct FolderItem: FileSystemItem {
    public let name: String
    public let children: [any FileSystemItem]
    public init(name: String, children: [any FileSystemItem]) { self.name = name; self.children = children }
    /// Sum of the whole subtree.
    public func size() -> Int { fatalError("TODO E3b") }
    /// This folder's own path first, then every child's paths relative to it.
    public func paths(prefix: String) -> [String] { fatalError("TODO E3b") }
}

// MARK: - E4 Decorator — stackable behaviour behind one interface

public protocol Beverage {
    var describe: String { get }
    func cost() -> Decimal
}

public struct Espresso: Beverage {
    public init() {}
    public var describe: String { fatalError("TODO E4a") }     // "espresso"
    public func cost() -> Decimal { fatalError("TODO E4a") }   // 120
}

public struct Milk: Beverage {
    private let base: any Beverage
    public init(_ base: any Beverage) { fatalError("TODO E4b") }
    public var describe: String { fatalError("TODO E4b") }     // "<base> + milk"
    public func cost() -> Decimal { fatalError("TODO E4b") }   // base + 20
}

public struct Caramel: Beverage {
    private let base: any Beverage
    public init(_ base: any Beverage) { fatalError("TODO E4c") }
    public var describe: String { fatalError("TODO E4c") }     // "<base> + caramel"
    public func cost() -> Decimal { fatalError("TODO E4c") }   // base + 35
}

/// Multiplies the wrapped cost by (1 + rate). Order in the chain therefore matters.
public struct Tax: Beverage {
    private let base: any Beverage
    private let rate: Decimal
    public init(_ base: any Beverage, rate: Decimal) { fatalError("TODO E4d") }
    public var describe: String { fatalError("TODO E4d") }     // "<base> + tax"
    public func cost() -> Decimal { fatalError("TODO E4d") }
}

// MARK: - E5 Decorator for cross-cutting concerns (the version you'll actually ship)

public protocol UserRepository6 {
    func name(forID id: String) throws -> String
}

public enum RepoError: Error, Equatable { case notFound, transient }

/// Caches successful lookups. A cached id must not reach the wrapped repository again.
public final class CachingRepository: UserRepository6 {
    private let base: any UserRepository6
    private var cache: [String: String] = [:]
    public init(base: any UserRepository6) { fatalError("TODO E5a") }
    public func name(forID id: String) throws -> String { fatalError("TODO E5a") }
    public var cachedIDs: [String] { fatalError("TODO E5a") }      // sorted
}

/// Records "get:<id>" before each call to the wrapped repository (even if it throws).
public final class LoggingRepository: UserRepository6 {
    private let base: any UserRepository6
    public private(set) var log: [String] = []
    public init(base: any UserRepository6) { fatalError("TODO E5b") }
    public func name(forID id: String) throws -> String { fatalError("TODO E5b") }
}

/// Retries only on RepoError.transient, up to `maxAttempts` TOTAL attempts.
/// Any other error propagates immediately.
public final class RetryingRepository: UserRepository6 {
    private let base: any UserRepository6
    private let maxAttempts: Int
    public init(base: any UserRepository6, maxAttempts: Int) { fatalError("TODO E5c") }
    public func name(forID id: String) throws -> String { fatalError("TODO E5c") }
}

// MARK: - E6 Facade — one call over a four-step subsystem

public struct VideoDecoder6 { public init() {}; public func decode(_ file: String) -> [String] { ["\(file)#f1", "\(file)#f2"] } }
public struct AudioExtractor6 { public init() {}; public func extract(_ file: String) -> String { "\(file)#audio" } }
public struct Transcoder6 { public init() {}; public func transcode(_ frames: [String], to format: String) -> String { "\(frames.count)frames.\(format)" } }
public struct Muxer6 { public init() {}; public func mux(_ video: String, _ audio: String) -> String { "\(video)+\(audio)" } }

/// Delegates only. Must contain no logic beyond wiring the four steps in order.
public struct MediaConverter {
    public init() {}
    /// decode -> extract -> transcode -> mux
    public func convert(file: String, to format: String) -> String { fatalError("TODO E6") }
}

// MARK: - E7 Flyweight — share the intrinsic state

/// Intrinsic (shared, immutable) state.
public final class PieceType {
    public let name: String
    public let moveRules: String
    public init(name: String, moveRules: String) { self.name = name; self.moveRules = moveRules }
}

public final class PieceTypeFactory {
    private var cache: [String: PieceType] = [:]
    public init() {}
    /// Returns the SAME instance for the same name; creates it on first request.
    public func type(_ name: String, rules: String) -> PieceType { fatalError("TODO E7a") }
    public var distinctTypeCount: Int { fatalError("TODO E7a") }
}

/// Extrinsic (unique) state + a reference to the shared type.
public struct Piece6 {
    public let type: PieceType
    public var square: String
    public var isWhite: Bool
    public init(type: PieceType, square: String, isWhite: Bool) {
        self.type = type; self.square = square; self.isWhite = isWhite
    }
}

// MARK: - E8 Proxy — control access

public protocol Document6 { func contents() throws -> String }

public final class RealDocument: Document6 {
    public private(set) var loadCount = 0
    private let text: String
    public init(text: String) { self.text = text }
    public func contents() throws -> String { loadCount += 1; return text }
}

public enum AccessError: Error, Equatable { case forbidden }
public enum Role: Equatable { case admin, viewer }

/// Protection proxy: only `.admin` may read.
public struct SecureDocument: Document6 {
    private let base: any Document6
    private let role: Role
    public init(base: any Document6, role: Role) { fatalError("TODO E8a") }
    public func contents() throws -> String { fatalError("TODO E8a") }
}

/// Virtual proxy: builds the RealDocument on FIRST access only, then reuses it.
public final class LazyDocument: Document6 {
    private let make: () -> RealDocument
    private var loaded: RealDocument?
    public private(set) var makeCallCount = 0
    public init(make: @escaping () -> RealDocument) { fatalError("TODO E8b") }
    public func contents() throws -> String { fatalError("TODO E8b") }
    public var isLoaded: Bool { fatalError("TODO E8b") }
}

// MARK: - E9 — pattern identification (knowledge check)

public enum StructuralPattern: String, Equatable, CaseIterable {
    case adapter, bridge, composite, decorator, facade, flyweight, proxy
}

public enum StructuralScenario: String, Equatable, CaseIterable
{
    case wrapAThirdPartySDKWhoseMethodNamesDiffer
    case addCachingWithoutChangingTheRepository
    case treatAFolderAndAFileIdentically
    case oneSimpleCallOverFourSubsystemSteps
    case denyReadsUnlessTheUserIsAnAdmin
    case shapesTimesRenderersWouldBeMTimesNClasses
    case millionsOfParticlesSharingOneTexture
}

public func pattern(for scenario: StructuralScenario) -> StructuralPattern { fatalError("TODO E9") }
