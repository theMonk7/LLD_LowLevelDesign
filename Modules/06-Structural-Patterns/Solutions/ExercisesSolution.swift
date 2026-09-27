//  Module 06 reference solutions.
//
//  HOW TO READ THIS FILE
//  Four of these patterns have IDENTICAL shapes — something holds something else
//  and forwards. The comments therefore talk about INTENT, because intent is the
//  only thing that separates them:
//    interface changed? -> Adapter
//    capability added, stackable? -> Decorator
//    access controlled, nothing added? -> Proxy
//    new simpler interface over several things? -> Facade
//
//  Not part of the M06 target.

import Foundation

// MARK: - E1 Adapter

public protocol PaymentProcessor {
    func pay(amountInPaise: Int, orderID: String) throws -> String
}

public final class LegacyPayGateway {
    private let alwaysDeclineOver: Double
    public init(alwaysDeclineOver: Double = .greatestFiniteMagnitude) { self.alwaysDeclineOver = alwaysDeclineOver }
    public func makePayment(_ rupees: Double, ref: String, currency: String) -> [String: Any] {
        rupees > alwaysDeclineOver ? ["status": "DECLINED"] : ["status": "OK", "txn": "TXN-\(ref)-\(currency)"]
    }
}

public enum PaymentError: Error, Equatable { case declined, malformedResponse }

public struct LegacyPayAdapter: PaymentProcessor {
    private let sdk: LegacyPayGateway
    public init(sdk: LegacyPayGateway) { self.sdk = sdk }

    // An adapter performs THREE translations, and each is a place bugs live:
    //  1. UNITS   paise (Int) inside the domain, rupees (Double) only at the edge.
    //             Keeping Double money out of the domain is half the value here.
    //  2. SHAPE   parameter names and order become the SDK's problem, not yours.
    //  3. ERRORS  a status string becomes a typed Swift error.
    //
    // Note `.malformedResponse` is SEPARATE from `.declined`: a missing txn on an
    // "OK" response is a server bug, not a payment decline. Collapsing them hides
    // an outage as a business outcome.
    public func pay(amountInPaise: Int, orderID: String) throws -> String {
        let rupees = Double(amountInPaise) / 100.0
        let raw = sdk.makePayment(rupees, ref: orderID, currency: "INR")
        guard let status = raw["status"] as? String else { throw PaymentError.malformedResponse }
        guard status == "OK" else { throw PaymentError.declined }
        guard let txn = raw["txn"] as? String else { throw PaymentError.malformedResponse }
        return txn
    }
}

// MARK: - E2 Bridge

public protocol Renderer {
    func renderCircle(radius: Double) -> String
    func renderSquare(side: Double) -> String
}

public struct SVGRenderer: Renderer {
    public init() {}
    public func renderCircle(radius: Double) -> String { "<circle r='\(radius)'/>" }
    public func renderSquare(side: Double) -> String { "<rect w='\(side)'/>" }
}

public struct ASCIIRenderer: Renderer {
    public init() {}
    public func renderCircle(radius: Double) -> String { "O(\(radius))" }
    public func renderSquare(side: Double) -> String { "[\(side)]" }
}

public protocol Shape6 { func draw() -> String }

// THE BRIDGE is the stored `renderer`. Two shapes and three renderers = FIVE
// types; without it, six — and with five shapes and four renderers it is nine
// versus twenty. The saving is multiplicative, which is why Bridge matters
// exactly when both dimensions grow.
//
// Honest wrinkle: `Renderer` has one method PER SHAPE, so adding a shape edits
// every renderer. Same axis asymmetry as Abstract Factory. The alternative — a
// generic `render(primitive:)` over a small vocabulary — trades type safety for
// extensibility. Naming that trade is the senior answer.
public struct Circle6: Shape6 {
    private let radius: Double
    private let renderer: any Renderer
    public init(radius: Double, renderer: any Renderer) { self.radius = radius; self.renderer = renderer }
    public func draw() -> String { renderer.renderCircle(radius: radius) }
}

public struct Square6: Shape6 {
    private let side: Double
    private let renderer: any Renderer
    public init(side: Double, renderer: any Renderer) { self.side = side; self.renderer = renderer }
    public func draw() -> String { renderer.renderSquare(side: side) }
}

// MARK: - E3 Composite

public protocol FileSystemItem {
    var name: String { get }
    func size() -> Int
    func paths(prefix: String) -> [String]
}

public struct FileItem: FileSystemItem {
    public let name: String
    public let bytes: Int
    public init(name: String, bytes: Int) { self.name = name; self.bytes = bytes }
    public func size() -> Int { bytes }
    public func paths(prefix: String) -> [String] { ["\(prefix)/\(name)"] }
}

public struct FolderItem: FileSystemItem {
    public let name: String
    public let children: [any FileSystemItem]
    public init(name: String, children: [any FileSystemItem]) { self.name = name; self.children = children }
    public func size() -> Int { children.reduce(0) { $0 + $1.size() } }
    // The composite calls the PROTOCOL method on its children, so nesting works to
    // any depth with zero type checks. `[here] + children.flatMap { ... }` gives
    // parents-before-children; swap the concatenation for post-order.
    //
    // Notice what is absent: `add(child:)`. Making `children` a `let` keeps the
    // tree immutable and sidesteps the "does a FILE have add()?" LSP problem
    // entirely. When mutation is required, put `add` on the composite only and
    // accept that callers must know what they hold — type safety over uniformity.
    public func paths(prefix: String) -> [String] {
        let here = "\(prefix)/\(name)"
        return [here] + children.flatMap { $0.paths(prefix: here) }
    }
}

// MARK: - E4 Decorator

public protocol Beverage {
    var describe: String { get }
    func cost() -> Decimal
}

public struct Espresso: Beverage {
    public init() {}
    public var describe: String { "espresso" }
    public func cost() -> Decimal { 120 }
}

public struct Milk: Beverage {
    private let base: any Beverage
    public init(_ base: any Beverage) { self.base = base }
    public var describe: String { base.describe + " + milk" }
    public func cost() -> Decimal { base.cost() + 20 }
}

public struct Caramel: Beverage {
    private let base: any Beverage
    public init(_ base: any Beverage) { self.base = base }
    public var describe: String { base.describe + " + caramel" }
    public func cost() -> Decimal { base.cost() + 35 }
}

// ORDER IS SEMANTICS: Tax(Milk(Espresso())) = 154, Milk(Tax(Espresso())) = 152.
// Same three objects, different composition, different answer. That is not a flaw
// — it is the pattern being honest that composition order carries meaning.
//
// And the design judgment: in a real cafe, tax applies once to the final total, so
// it is NOT optional and NOT stackable — which means it should not be a decorator
// at all. "I wouldn't model tax this way" is a better interview answer than a
// correct implementation of the wrong idea.
public struct Tax: Beverage {
    private let base: any Beverage
    private let rate: Decimal
    public init(_ base: any Beverage, rate: Decimal) { self.base = base; self.rate = rate }
    public var describe: String { base.describe + " + tax" }
    public func cost() -> Decimal { base.cost() * (1 + rate) }
}

// MARK: - E5 Cross-cutting decorators

public protocol UserRepository6 { func name(forID id: String) throws -> String }
public enum RepoError: Error, Equatable { case notFound, transient }

public final class CachingRepository: UserRepository6 {
    private let base: any UserRepository6
    private var cache: [String: String] = [:]
    public init(base: any UserRepository6) { self.base = base }
    public func name(forID id: String) throws -> String {
        if let hit = cache[id] { return hit }
        // NOT caching failures is deliberate. Cache a `.notFound` and the user who
        // just signed up stays missing until the process restarts. If you DO want
        // negative caching, it needs its own TTL — a separate decision, not an
        // accident of where the assignment sits.
        let fresh = try base.name(forID: id)      // a throw propagates and is NOT cached
        cache[id] = fresh
        return fresh
    }
    public var cachedIDs: [String] { cache.keys.sorted() }
}

public final class LoggingRepository: UserRepository6 {
    private let base: any UserRepository6
    public private(set) var log: [String] = []
    public init(base: any UserRepository6) { self.base = base }
    public func name(forID id: String) throws -> String {
        // Logged BEFORE the call, so failed attempts appear in the log. Log after,
        // and the entries you most need at 3 a.m. are exactly the ones missing.
        log.append("get:\(id)")
        return try base.name(forID: id)
    }
}

public final class RetryingRepository: UserRepository6 {
    private let base: any UserRepository6
    private let maxAttempts: Int
    public init(base: any UserRepository6, maxAttempts: Int) { self.base = base; self.maxAttempts = maxAttempts }
    public func name(forID id: String) throws -> String {
        var lastError: Error = RepoError.transient
        for _ in 0..<max(1, maxAttempts) {
            do { return try base.name(forID: id) }
            // Retrying ONLY transient errors is what separates a retry policy from an
            // infinite loop against a permanent failure. Also note `maxAttempts`
            // counts total attempts, not retries — "3 retries" and "3 attempts"
            // differ by one real network call, so say which you mean.
            catch RepoError.transient { lastError = RepoError.transient; continue }
            catch { throw error }                 // non-transient: give up immediately
        }
        throw lastError
    }
}

// MARK: - E6 Facade

public struct VideoDecoder6 { public init() {}; public func decode(_ file: String) -> [String] { ["\(file)#f1", "\(file)#f2"] } }
public struct AudioExtractor6 { public init() {}; public func extract(_ file: String) -> String { "\(file)#audio" } }
public struct Transcoder6 { public init() {}; public func transcode(_ frames: [String], to format: String) -> String { "\(frames.count)frames.\(format)" } }
public struct Muxer6 { public init() {}; public func mux(_ video: String, _ audio: String) -> String { "\(video)+\(audio)" } }

public struct MediaConverter {
    public init() {}
    public func convert(file: String, to format: String) -> String {
        let frames = VideoDecoder6().decode(file)
        let audio = AudioExtractor6().extract(file)
        let video = Transcoder6().transcode(frames, to: format)
        return Muxer6().mux(video, audio)
    }
}

// MARK: - E7 Flyweight

public final class PieceType {
    public let name: String
    public let moveRules: String
    public init(name: String, moveRules: String) { self.name = name; self.moveRules = moveRules }
}

public final class PieceTypeFactory {
    private var cache: [String: PieceType] = [:]
    public init() {}
    // Two correctness requirements are embodied here, not merely described:
    //  - PieceType has only `let` properties. Mutable shared state would be a
    //    global-state bug wearing an optimisation costume.
    //  - This factory is the ONLY way to obtain one, otherwise duplicates appear
    //    and the saving evaporates.
    //
    // Honest framing: at 32 chess pieces this is over-engineering and you should
    // say so. At a million particles it is the difference between shipping and
    // running out of memory.
    public func type(_ name: String, rules: String) -> PieceType {
        if let hit = cache[name] { return hit }
        let made = PieceType(name: name, moveRules: rules)
        cache[name] = made
        return made
    }
    public var distinctTypeCount: Int { cache.count }
}

public struct Piece6 {
    public let type: PieceType
    public var square: String
    public var isWhite: Bool
    public init(type: PieceType, square: String, isWhite: Bool) {
        self.type = type; self.square = square; self.isWhite = isWhite
    }
}

// MARK: - E8 Proxy

public protocol Document6 { func contents() throws -> String }

public final class RealDocument: Document6 {
    public private(set) var loadCount = 0
    private let text: String
    public init(text: String) { self.text = text }
    public func contents() throws -> String { loadCount += 1; return text }
}

public enum AccessError: Error, Equatable { case forbidden }
public enum Role: Equatable { case admin, viewer }

public struct SecureDocument: Document6 {
    private let base: any Document6
    private let role: Role
    public init(base: any Document6, role: Role) { self.base = base; self.role = role }
    public func contents() throws -> String {
        guard role == .admin else { throw AccessError.forbidden }
        return try base.contents()
    }
}

public final class LazyDocument: Document6 {
    private let make: () -> RealDocument
    private var loaded: RealDocument?
    public private(set) var makeCallCount = 0
    public init(make: @escaping () -> RealDocument) { self.make = make }
    // Both proxies keep `Document6` UNCHANGED — that is what makes them proxies
    // rather than adapters. Neither adds a capability the caller asked for — that
    // is what makes them proxies rather than decorators.
    //
    // `LazyDocument` is a class because it caches; `SecureDocument` is a struct
    // because it is stateless. Swift's `lazy var` is this same virtual-proxy idea
    // built into the language.
    public func contents() throws -> String {
        if loaded == nil { makeCallCount += 1; loaded = make() }
        return try loaded!.contents()
    }
    public var isLoaded: Bool { loaded != nil }
}

// MARK: - E9

public enum StructuralPattern: String, Equatable, CaseIterable {
    case adapter, bridge, composite, decorator, facade, flyweight, proxy
}

public enum StructuralScenario: String, Equatable, CaseIterable {
    case wrapAThirdPartySDKWhoseMethodNamesDiffer
    case addCachingWithoutChangingTheRepository
    case treatAFolderAndAFileIdentically
    case oneSimpleCallOverFourSubsystemSteps
    case denyReadsUnlessTheUserIsAnAdmin
    case shapesTimesRenderersWouldBeMTimesNClasses
    case millionsOfParticlesSharingOneTexture
}

public func pattern(for scenario: StructuralScenario) -> StructuralPattern {
    switch scenario {
    case .wrapAThirdPartySDKWhoseMethodNamesDiffer:  .adapter
    case .addCachingWithoutChangingTheRepository:    .decorator
    case .treatAFolderAndAFileIdentically:           .composite
    case .oneSimpleCallOverFourSubsystemSteps:       .facade
    case .denyReadsUnlessTheUserIsAnAdmin:           .proxy
    case .shapesTimesRenderersWouldBeMTimesNClasses: .bridge
    case .millionsOfParticlesSharingOneTexture:      .flyweight
    }
}
