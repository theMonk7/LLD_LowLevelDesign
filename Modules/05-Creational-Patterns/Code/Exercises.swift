//  Module 05 — Creational pattern exercises.
//
//  BEFORE YOU TYPE: every one of these moves a DECISION out of code whose job is
//  something else. For each exercise, say which decision moved and what choice
//  that preserves:
//    E1  can a test substitute this, or is the dependency hidden?
//    E2  is the set of kinds CLOSED (enum + exhaustive switch) or OPEN (registry)?
//        This is a question about the product, not the code.
//    E3  does the consumer ever name a concrete product? If so, the indirection
//        bought nothing.
//    E4  what invariant holds across the whole FAMILY that no single object can
//        guarantee alone?
//    E5  which rules span more than one field, and therefore cannot be checked in
//        a setter?
//    E6  what does this object contain that is itself mutable and shared?
//    E7  exhaustion, reset, and leaks — answer all three.
//
//  Replace every fatalError("TODO").

import Foundation

// MARK: - E1 Singleton (done properly: single instance + injectable abstraction)

public protocol ConfigProviding {
    func value(for key: String) -> String?
}

public final class AppConfig: ConfigProviding, Sendable {
    public static let shared = AppConfig(values: ["env": "prod", "apiHost": "api.example.com"])
    private let values: [String: String]

    /// Must be private so no second AppConfig can be created from outside.
    private init(values: [String: String]) { fatalError("TODO E1a") }

    public func value(for key: String) -> String? { fatalError("TODO E1b") }
}

/// Uses the singleton by DEFAULT but accepts any provider, so tests can substitute one.
public struct FeatureGate {
    private let config: any ConfigProviding
    public init(config: any ConfigProviding = AppConfig.shared) { fatalError("TODO E1c") }
    /// True when the config value for `key` is exactly "on".
    public func isEnabled(_ key: String) -> Bool { fatalError("TODO E1d") }
}

// MARK: - E2 Simple factory + closure registry

public protocol Shape5 {
    var kind: String { get }
    func area() -> Double
}

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

/// Closed set → one switch, in one place.
public enum SimpleShapeFactory {
    /// circle uses `size` as radius; square uses `size` as side.
    public static func make(_ kind: ShapeKind, size: Double) -> any Shape5 { fatalError("TODO E2a") }
}

/// Open set → callers register their own makers. No switch anywhere.
public final class ShapeRegistry {
    private var makers: [String: (Double) -> any Shape5] = [:]
    public init() {}
    public func register(_ key: String, maker: @escaping (Double) -> any Shape5) { fatalError("TODO E2b") }
    public func make(_ key: String, size: Double) -> (any Shape5)? { fatalError("TODO E2c") }
    /// Registered keys, sorted.
    public var registeredKeys: [String] { fatalError("TODO E2d") }
}

// MARK: - E3 Factory Method

public protocol Exporter {
    var fileExtension: String { get }
    func export(_ rows: [[String]]) -> String
}

public struct CSVExporter: Exporter {
    public init() {}
    public var fileExtension: String { fatalError("TODO E3a") }      // "csv"
    /// Rows joined by "\n", fields joined by ",".
    public func export(_ rows: [[String]]) -> String { fatalError("TODO E3a") }
}

public struct TSVExporter: Exporter {
    public init() {}
    public var fileExtension: String { fatalError("TODO E3b") }      // "tsv"
    public func export(_ rows: [[String]]) -> String { fatalError("TODO E3b") }
}

public protocol ExporterFactory {
    func makeExporter() -> any Exporter
}

public struct CSVExporterFactory: ExporterFactory {
    public init() {}
    public func makeExporter() -> any Exporter { fatalError("TODO E3c") }
}

public struct TSVExporterFactory: ExporterFactory {
    public init() {}
    public func makeExporter() -> any Exporter { fatalError("TODO E3c") }
}

/// Knows nothing about CSV or TSV — it only knows the factory protocol.
public struct ReportWriter {
    private let factory: any ExporterFactory
    public init(factory: any ExporterFactory) { fatalError("TODO E3d") }
    /// Returns "report.<ext>" and the exported body.
    public func write(_ rows: [[String]]) -> (filename: String, body: String) { fatalError("TODO E3e") }
}

// MARK: - E4 Abstract Factory (families that must stay consistent)

public protocol Button5   { func render() -> String }
public protocol Checkbox5 { func render() -> String }

public struct LightButton: Button5     { public init() {}; public func render() -> String { fatalError("TODO E4a") } }
public struct LightCheckbox: Checkbox5 { public init() {}; public func render() -> String { fatalError("TODO E4a") } }
public struct DarkButton: Button5      { public init() {}; public func render() -> String { fatalError("TODO E4b") } }
public struct DarkCheckbox: Checkbox5  { public init() {}; public func render() -> String { fatalError("TODO E4b") } }

public protocol ThemeFactory {
    var themeName: String { get }
    func makeButton() -> any Button5
    func makeCheckbox() -> any Checkbox5
}

public struct LightTheme: ThemeFactory {
    public init() {}
    public var themeName: String { fatalError("TODO E4c") }          // "light"
    public func makeButton() -> any Button5 { fatalError("TODO E4c") }
    public func makeCheckbox() -> any Checkbox5 { fatalError("TODO E4c") }
}

public struct DarkTheme: ThemeFactory {
    public init() {}
    public var themeName: String { fatalError("TODO E4d") }          // "dark"
    public func makeButton() -> any Button5 { fatalError("TODO E4d") }
    public func makeCheckbox() -> any Checkbox5 { fatalError("TODO E4d") }
}

public struct SettingsScreen {
    private let theme: any ThemeFactory
    public init(theme: any ThemeFactory) { fatalError("TODO E4e") }
    /// [button render, checkbox render] — always from the same family.
    public func render() -> [String] { fatalError("TODO E4f") }
}

// MARK: - E5 Builder (incremental construction + cross-field validation)

public struct HTTPRequest5: Equatable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let retries: Int
}

public enum BuildError: Error, Equatable {
    case bodyOnGET
    case negativeRetries
    case missingContentTypeForBody
}

public final class HTTPRequestBuilder {
    private let url: String
    private var method = "GET"
    private var headers: [String: String] = [:]
    private var body: String?
    private var retries = 0

    public init(url: String) { fatalError("TODO E5a") }

    @discardableResult public func method(_ m: String) -> Self { fatalError("TODO E5b") }
    @discardableResult public func header(_ key: String, _ value: String) -> Self { fatalError("TODO E5b") }
    @discardableResult public func body(_ b: String) -> Self { fatalError("TODO E5b") }
    @discardableResult public func retries(_ n: Int) -> Self { fatalError("TODO E5b") }

    /// Validation happens HERE, once, across fields:
    ///  - GET with a body           → .bodyOnGET
    ///  - retries < 0               → .negativeRetries
    ///  - body without Content-Type → .missingContentTypeForBody
    public func build() throws -> HTTPRequest5 { fatalError("TODO E5c") }
}

// MARK: - E6 Prototype (deep vs shallow copy)

public final class TreeNode {
    public var value: String
    public var children: [TreeNode]
    public init(value: String, children: [TreeNode] = []) { self.value = value; self.children = children }

    /// Copies this node and the WHOLE subtree. Mutating the copy must never affect the original.
    public func deepCopy() -> TreeNode { fatalError("TODO E6a") }

    /// Copies only this node; children are shared with the original. (Kept to contrast with deepCopy.)
    public func shallowCopy() -> TreeNode { fatalError("TODO E6b") }

    /// Depth-first values: self, then each child's preorder, in order.
    public func preorderValues() -> [String] { fatalError("TODO E6c") }
}

// MARK: - E7 Object Pool

public final class PooledConnection {
    public private(set) var id: Int
    public private(set) var scratch: String = ""
    public init(id: Int) { self.id = id }
    public func use(_ text: String) { scratch = text }
    /// Wipes per-client state. Called on release.
    public func reset() { fatalError("TODO E7a") }
}

public enum PoolError: Error, Equatable { case exhausted, foreignObject }

public final class ConnectionPool {
    private var available: [PooledConnection] = []
    private var inUseIDs: Set<Int> = []
    private var created = 0
    private let maxSize: Int

    public init(maxSize: Int) { fatalError("TODO E7b") }

    /// Reuses an available connection if there is one, otherwise creates a new one
    /// with id = (number created so far) + 1. Throws .exhausted at maxSize.
    public func acquire() throws -> PooledConnection { fatalError("TODO E7c") }

    /// Resets the connection and returns it to the pool.
    /// Throws .foreignObject if this connection isn't currently checked out.
    public func release(_ c: PooledConnection) throws { fatalError("TODO E7d") }

    public var availableCount: Int { fatalError("TODO E7e") }
    public var inUseCount: Int { fatalError("TODO E7e") }
}
