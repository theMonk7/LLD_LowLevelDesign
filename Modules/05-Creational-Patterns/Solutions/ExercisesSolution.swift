//  Module 05 reference solutions.
//
//  HOW TO READ THIS FILE
//  Every pattern here exists to move a DECISION out of code whose job is something
//  else. For each one, the comments answer: which decision moved, where did it go,
//  and what choice does that preserve? If a construct preserves no choice, it is
//  indirection rather than design — and two of the comments below say exactly that.
//
//  Not part of the M05 target.

import Foundation

// MARK: - E1

public protocol ConfigProviding { func value(for key: String) -> String? }

// Three separate things are doing work in this small type:
//
// 1. `static let` gives lazy, once-only, THREAD-SAFE initialisation. Swift's
//    runtime handles it; you write no locking. Candidates who recite Java's
//    double-checked locking are answering about a language they are not using.
// 2. `private init` is what actually enforces "only one". Without it you have a
//    convenience accessor, not a singleton — `AppConfig(...)` still compiles.
// 3. `values` is immutable, which is WHY this singleton is safe. A singleton
//    holding mutable state needs an actor or a lock — and at that point, ask
//    whether it should be owned and injected instead.
public final class AppConfig: ConfigProviding, Sendable {
    public static let shared = AppConfig(values: ["env": "prod", "apiHost": "api.example.com"])
    private let values: [String: String]
    private init(values: [String: String]) { self.values = values }
    public func value(for key: String) -> String? { values[key] }
}

public struct FeatureGate {
    private let config: any ConfigProviding
    // THE TRICK: a defaulted parameter. Call sites stay clean — `FeatureGate()` —
    // while tests stay honest — `FeatureGate(config: StubConfig(...))`.
    // You keep the singleton's ergonomics and lose its untestability.
    // A bare `AppConfig.shared` inside a method body would be a hidden dependency:
    // invisible in the initialiser, invisible to the compiler, invisible to tests.
    public init(config: any ConfigProviding = AppConfig.shared) { self.config = config }
    public func isEnabled(_ key: String) -> Bool { config.value(for: key) == "on" }
}

// MARK: - E2

public protocol Shape5 { var kind: String { get }; func area() -> Double }

public struct Circle5: Shape5 {
    public let radius: Double
    public init(radius: Double) { self.radius = radius }
    public var kind: String { "circle" }
    public func area() -> Double { .pi * radius * radius }
}

public struct Square5: Shape5 {
    public let side: Double
    public init(side: Double) { self.side = side }
    public var kind: String { "square" }
    public func area() -> Double { side * side }
}

public enum ShapeKind: String, CaseIterable { case circle, square }

public enum SimpleShapeFactory {
    public static func make(_ kind: ShapeKind, size: Double) -> any Shape5 {
        switch kind {
        case .circle: Circle5(radius: size)
        case .square: Square5(side: size)
        }
    }
}

public final class ShapeRegistry {
    private var makers: [String: (Double) -> any Shape5] = [:]
    public init() {}
    // This is the IDIOMATIC Swift factory: a dictionary of closures. No protocol,
    // no class per product. Compare with SimpleShapeFactory above — same job,
    // different answer, because the set of kinds is open instead of closed.
    //
    // `make` returns an Optional rather than trapping: unknown input at a registry
    // boundary is a normal condition, not a programmer error.
    public func register(_ key: String, maker: @escaping (Double) -> any Shape5) { makers[key] = maker }
    public func make(_ key: String, size: Double) -> (any Shape5)? { makers[key]?(size) }
    public var registeredKeys: [String] { makers.keys.sorted() }
}

// MARK: - E3

public protocol Exporter {
    var fileExtension: String { get }
    func export(_ rows: [[String]]) -> String
}

public struct CSVExporter: Exporter {
    public init() {}
    public var fileExtension: String { "csv" }
    public func export(_ rows: [[String]]) -> String {
        rows.map { $0.joined(separator: ",") }.joined(separator: "\n")
    }
}

public struct TSVExporter: Exporter {
    public init() {}
    public var fileExtension: String { "tsv" }
    public func export(_ rows: [[String]]) -> String {
        rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
}

public protocol ExporterFactory { func makeExporter() -> any Exporter }

public struct CSVExporterFactory: ExporterFactory {
    public init() {}
    public func makeExporter() -> any Exporter { CSVExporter() }
}
public struct TSVExporterFactory: ExporterFactory {
    public init() {}
    public func makeExporter() -> any Exporter { TSVExporter() }
}

public struct ReportWriter {
    private let factory: any ExporterFactory
    public init(factory: any ExporterFactory) { self.factory = factory }
    // Note WHERE `fileExtension` lives: on the PRODUCT, not on the writer.
    // Put it on the writer and you need a switch mapping factory to extension,
    // which re-introduces exactly the coupling the pattern removed. Where
    // information lives decides whether a pattern actually works.
    //
    // Honest assessment for an interview: for two exporters in one app,
    // injecting the product directly is simpler and just as extensible. Factory
    // Method earns its keep when CREATION itself varies — needs configuration,
    // pooling, or a fresh instance per call.
    public func write(_ rows: [[String]]) -> (filename: String, body: String) {
        let exporter = factory.makeExporter()
        return ("report.\(exporter.fileExtension)", exporter.export(rows))
    }
}

// MARK: - E4

public protocol Button5 { func render() -> String }
public protocol Checkbox5 { func render() -> String }

public struct LightButton: Button5 { public init() {}; public func render() -> String { "light-button" } }
public struct LightCheckbox: Checkbox5 { public init() {}; public func render() -> String { "light-checkbox" } }
public struct DarkButton: Button5 { public init() {}; public func render() -> String { "dark-button" } }
public struct DarkCheckbox: Checkbox5 { public init() {}; public func render() -> String { "dark-checkbox" } }

public protocol ThemeFactory {
    var themeName: String { get }
    func makeButton() -> any Button5
    func makeCheckbox() -> any Checkbox5
}

public struct LightTheme: ThemeFactory {
    public init() {}
    public var themeName: String { "light" }
    public func makeButton() -> any Button5 { LightButton() }
    public func makeCheckbox() -> any Checkbox5 { LightCheckbox() }
}

public struct DarkTheme: ThemeFactory {
    public init() {}
    public var themeName: String { "dark" }
    public func makeButton() -> any Button5 { DarkButton() }
    public func makeCheckbox() -> any Checkbox5 { DarkCheckbox() }
}

public struct SettingsScreen {
    private let theme: any ThemeFactory
    public init(theme: any ThemeFactory) { self.theme = theme }
    public func render() -> [String] { [theme.makeButton().render(), theme.makeCheckbox().render()] }
}

// MARK: - E5

public struct HTTPRequest5: Equatable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let retries: Int
}

public enum BuildError: Error, Equatable {
    case bodyOnGET, negativeRetries, missingContentTypeForBody
}

public final class HTTPRequestBuilder {
    private let url: String
    private var method = "GET"
    private var headers: [String: String] = [:]
    private var body: String?
    private var retries = 0

    public init(url: String) { self.url = url }

    @discardableResult public func method(_ m: String) -> Self { method = m; return self }
    @discardableResult public func header(_ key: String, _ value: String) -> Self { headers[key] = value; return self }
    @discardableResult public func body(_ b: String) -> Self { body = b; return self }
    @discardableResult public func retries(_ n: Int) -> Self { retries = n; return self }

    // WHY a builder at all, when Swift has default arguments?
    // Because all three rules below span MORE THAN ONE FIELD, so none of them can
    // be checked in a property setter. That — plus construction spread across
    // several functions — is the only thing that justifies a builder in Swift.
    //
    // Note the shape: MUTABLE BUILDER, IMMUTABLE PRODUCT. All the churn happens
    // during assembly; none afterwards. And the builder is a `class` deliberately:
    // a struct builder handed to two functions would give each of them a copy and
    // silently lose their changes.
    public func build() throws -> HTTPRequest5 {
        if method == "GET", body != nil { throw BuildError.bodyOnGET }
        if retries < 0 { throw BuildError.negativeRetries }
        if body != nil, headers["Content-Type"] == nil { throw BuildError.missingContentTypeForBody }
        return HTTPRequest5(url: url, method: method, headers: headers, body: body, retries: retries)
    }
}

// MARK: - E6

public final class TreeNode {
    public var value: String
    public var children: [TreeNode]
    public init(value: String, children: [TreeNode] = []) { self.value = value; self.children = children }

    // One line apart, completely different semantics. The array copy in
    // `shallowCopy` copies the REFERENCES, not the objects — so mutating
    // `copy.children[0]` changes the original's child too.
    //
    // This is why Prototype is a reference-type pattern. Make TreeNode a struct
    // and `let copy = original` is already a deep copy, with copy-on-write making
    // it cheap. Swift solved the common case at the language level; you need this
    // only where identity or class inheritance forced you into a class.
    public func deepCopy() -> TreeNode {
        TreeNode(value: value, children: children.map { $0.deepCopy() })
    }
    public func shallowCopy() -> TreeNode {
        TreeNode(value: value, children: children)
    }
    public func preorderValues() -> [String] {
        [value] + children.flatMap { $0.preorderValues() }
    }
}

// MARK: - E7

public final class PooledConnection {
    public private(set) var id: Int
    public private(set) var scratch: String = ""
    public init(id: Int) { self.id = id }
    public func use(_ text: String) { scratch = text }
    public func reset() { scratch = "" }
}

public enum PoolError: Error, Equatable { case exhausted, foreignObject }

public final class ConnectionPool {
    private var available: [PooledConnection] = []
    private var inUseIDs: Set<Int> = []
    private var created = 0
    private let maxSize: Int

    public init(maxSize: Int) { self.maxSize = maxSize }

    public func acquire() throws -> PooledConnection {
        if let reused = available.popLast() {
            inUseIDs.insert(reused.id)
            return reused
        }
        guard created < maxSize else { throw PoolError.exhausted }
        created += 1
        let fresh = PooledConnection(id: created)
        inUseIDs.insert(fresh.id)
        return fresh
    }

    // Every line here answers one of the three questions any pool must answer:
    //
    //  EXHAUSTION  -> `acquire` throws. Blocking with a timeout or growing past max
    //                 are equally valid IF STATED; growing silently is how you
    //                 exhaust the database instead of the pool.
    //  RESET       -> `c.reset()` below, before it goes back. Skip it and the next
    //                 client receives the previous client's data. That is a
    //                 security bug, not a performance detail.
    //  DOUBLE/FOREIGN RELEASE -> the guard. Without it, a double release puts one
    //                 connection into `available` twice and two clients get the
    //                 same connection — the worst possible pool bug.
    public func release(_ c: PooledConnection) throws {
        guard inUseIDs.remove(c.id) != nil else { throw PoolError.foreignObject }
        c.reset()
        available.append(c)
    }

    public var availableCount: Int { available.count }
    public var inUseCount: Int { inUseIDs.count }
}
