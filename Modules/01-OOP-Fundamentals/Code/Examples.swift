//  Examples.swift — Module 01 worked examples.
//
//  HOW TO READ THIS FILE
//  Eight numbered examples, each isolating ONE idea so you can see it without
//  noise. Run `Examples.runAll()` and read the output next to the code — several
//  of them exist specifically because their output surprises people:
//
//    1. value vs reference  — the copy-then-mutate result is the bug behind half
//                             of all "my change did not stick" machine-coding
//                             failures
//    2. encapsulation       — a failed withdrawal leaves the object untouched
//    3. abstraction         — TWO genuinely different implementations, which is
//                             the test of whether an abstraction is real
//    4. inheritance         — a fixed skeleton calling an overridable step
//    5. polymorphism        — existential vs generic, and why LLD wants the former
//    6. dispatch trap       — prints "LOUD hello | protocol bye". Understand why.
//    7. composition         — new combination, zero new types
//    8. coupling            — the same checkout, hardcoded then injected
//
//  Everything is namespaced inside `Examples` so it never collides with your
//  exercise answers.

import Foundation

public enum Examples {

    // MARK: 1. Value vs reference semantics — the #1 machine-coding bug

    public struct SeatValue { public var isBooked = false }
    public final class SeatRef { public var isBooked = false }

    public static func valueVsReference() -> String {
        var rows = [SeatValue(), SeatValue()]
        var copy = rows[0]          // COPY
        copy.isBooked = true
        let valueResult = rows[0].isBooked        // false — the booking was lost

        rows[1].isBooked = true                   // in-place subscript mutation does stick
        let inPlaceResult = rows[1].isBooked      // true

        let refs = [SeatRef(), SeatRef()]
        let alias = refs[0]                       // SHARED
        alias.isBooked = true
        let refResult = refs[0].isBooked          // true

        return "copy-then-mutate=\(valueResult), in-place=\(inPlaceResult), reference=\(refResult)"
    }

    // MARK: 2. Encapsulation — invariants that cannot be broken from outside

    public enum VaultError: Error { case negative, insufficient }

    public final class Vault {
        public private(set) var grams: Int          // read-only to the world
        public init(grams: Int) { self.grams = max(0, grams) }

        public func deposit(_ g: Int) throws {
            guard g > 0 else { throw VaultError.negative }
            grams += g
        }
        public func withdraw(_ g: Int) throws {
            guard g > 0 else { throw VaultError.negative }
            guard g <= grams else { throw VaultError.insufficient }   // invariant lives HERE
            grams -= g
        }
    }

    // MARK: 3. Abstraction — the contract hides the mechanism

    public protocol Storage {
        func write(_ data: String, key: String)
        func read(key: String) -> String?
    }

    public final class InMemoryStorage: Storage {
        private var store: [String: String] = [:]
        public init() {}
        public func write(_ data: String, key: String) { store[key] = data }
        public func read(key: String) -> String? { store[key] }
    }

    public final class LoggingStorage: Storage {         // a second, genuinely different impl
        private let wrapped: any Storage
        public private(set) var log: [String] = []
        public init(wrapping: any Storage) { self.wrapped = wrapping }
        public func write(_ data: String, key: String) { log.append("write \(key)"); wrapped.write(data, key: key) }
        public func read(key: String) -> String? { log.append("read \(key)"); return wrapped.read(key: key) }
    }

    // MARK: 4. Inheritance + the template-method shape

    public class Report {
        public let title: String
        public init(title: String) { self.title = title }
        public func body() -> String { fatalError("subclass must override body()") }  // "abstract"
        public final func render() -> String { "# \(title)\n\(body())" }              // fixed skeleton
    }

    public final class SalesReport: Report {
        private let total: Int
        public init(total: Int) { self.total = total; super.init(title: "Sales") }
        public override func body() -> String { "Total: \(total)" }
    }

    // MARK: 5. Polymorphism — existential vs generic

    public protocol Animal { func speak() -> String }
    public struct Dog: Animal { public init() {}; public func speak() -> String { "woof" } }
    public struct Cat: Animal { public init() {}; public func speak() -> String { "meow" } }

    /// Heterogeneous: dynamic dispatch through an existential box. This is what LLD usually needs.
    public static func chorus(_ animals: [any Animal]) -> [String] { animals.map { $0.speak() } }

    /// Homogeneous: static dispatch, specialised per concrete type. Faster, but one type only.
    public static func chorus<A: Animal>(_ animals: [A]) -> [String] { animals.map { $0.speak() } }

    // MARK: 6. Protocol extension dispatch trap

    // (ExGreeter / ExLoud live at file scope below — Swift allows protocol extensions
    //  only at file scope, which is itself worth knowing.)

    public static func dispatchTrap() -> String {
        let g: any ExGreeter = ExLoud()
        return "\(g.hello()) | \(g.bye())"     // "LOUD hello | protocol bye"
    }

    // MARK: 7. Inheritance explosion → composition

    public protocol Channel2 { func deliver(_ m: String) -> String }
    public struct EmailCh: Channel2 { public init() {}; public func deliver(_ m: String) -> String { "email:\(m)" } }
    public struct SMSCh:   Channel2 { public init() {}; public func deliver(_ m: String) -> String { "sms:\(m)" } }
    public struct SlackCh: Channel2 { public init() {}; public func deliver(_ m: String) -> String { "slack:\(m)" } }

    public struct ComposedNotifier {
        private let channels: [any Channel2]
        public init(_ channels: [any Channel2]) { self.channels = channels }
        public func send(_ m: String) -> [String] { channels.map { $0.deliver(m) } }
    }

    // MARK: 8. Coupling: concrete dependency vs injected abstraction

    public struct HardCodedCheckout {                 // ❌ untestable, unswappable
        public init() {}
        public func total(_ items: [Int]) -> Int { items.reduce(0, +) + 50 }   // 50 = shipping, buried
    }

    public protocol ShippingPolicy { func fee(for subtotal: Int) -> Int }
    public struct FlatShipping: ShippingPolicy {
        public let amount: Int
        public init(amount: Int) { self.amount = amount }
        public func fee(for subtotal: Int) -> Int { amount }
    }
    public struct FreeOver: ShippingPolicy {
        public let threshold: Int, otherwise: Int
        public init(threshold: Int, otherwise: Int) { self.threshold = threshold; self.otherwise = otherwise }
        public func fee(for subtotal: Int) -> Int { subtotal >= threshold ? 0 : otherwise }
    }
    public struct Checkout {                          // ✅ policy injected
        private let shipping: any ShippingPolicy
        public init(shipping: any ShippingPolicy) { self.shipping = shipping }
        public func total(_ items: [Int]) -> Int {
            let subtotal = items.reduce(0, +)
            return subtotal + shipping.fee(for: subtotal)
        }
    }

    // MARK: Runner

    public static func runAll() {
        print("1 semantics:", valueVsReference())
        let v = Vault(grams: 10); try? v.deposit(5); try? v.withdraw(100)
        print("2 vault grams:", v.grams, "(failed withdrawal left it untouched)")
        let s = LoggingStorage(wrapping: InMemoryStorage())
        s.write("hi", key: "k"); _ = s.read(key: "k")
        print("3 storage log:", s.log)
        print("4 report:\n" + SalesReport(total: 42).render())
        print("5 chorus:", chorus([Dog(), Cat()] as [any Animal]))
        print("6 dispatch:", dispatchTrap())
        print("7 composed:", ComposedNotifier([EmailCh(), SlackCh()]).send("deploy done"))
        print("8 checkout flat:", Checkout(shipping: FlatShipping(amount: 50)).total([100, 200]))
        print("8 checkout freeOver:", Checkout(shipping: FreeOver(threshold: 250, otherwise: 50)).total([100, 200]))
    }
}

// MARK: - Example 6 support (must be at file scope)

public protocol ExGreeter { func hello() -> String }     // declared in the protocol → DYNAMIC
public extension ExGreeter {
    func hello() -> String { "protocol hello" }
    func bye() -> String { "protocol bye" }              // extension only → STATIC dispatch
}
public struct ExLoud: ExGreeter {
    public init() {}
    public func hello() -> String { "LOUD hello" }
    public func bye() -> String { "LOUD bye" }
}
