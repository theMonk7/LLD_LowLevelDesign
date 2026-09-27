import XCTest
@testable import M05

struct StubConfig: ConfigProviding {
    let values: [String: String]
    func value(for key: String) -> String? { values[key] }
}

final class E1SingletonTests: XCTestCase {
    func test_sharedIsOneInstance() {
        XCTAssertTrue(AppConfig.shared === AppConfig.shared)
    }
    func test_sharedHasSeedValues() {
        XCTAssertEqual(AppConfig.shared.value(for: "env"), "prod")
        XCTAssertNil(AppConfig.shared.value(for: "nope"))
    }
    func test_gateDefaultsToSharedButAcceptsAStub() {
        let gate = FeatureGate(config: StubConfig(values: ["newCheckout": "on", "beta": "off"]))
        XCTAssertTrue(gate.isEnabled("newCheckout"))
        XCTAssertFalse(gate.isEnabled("beta"))
        XCTAssertFalse(gate.isEnabled("missing"))
    }
    func test_gateWorksWithTheRealSingleton() {
        XCTAssertFalse(FeatureGate().isEnabled("env"))     // "prod" is not "on"
    }
}

final class E2FactoryTests: XCTestCase {
    func test_simpleFactory() {
        XCTAssertEqual(SimpleShapeFactory.make(.circle, size: 2).kind, "circle")
        XCTAssertEqual(SimpleShapeFactory.make(.square, size: 3).area(), 9, accuracy: 0.0001)
        XCTAssertEqual(SimpleShapeFactory.make(.circle, size: 1).area(), Double.pi, accuracy: 0.0001)
    }
    func test_registryMakesRegisteredKinds() {
        let r = ShapeRegistry()
        r.register("circle") { Circle5(radius: $0) }
        r.register("square") { Square5(side: $0) }
        XCTAssertEqual(r.make("square", size: 4)?.area(), 16)
        XCTAssertEqual(r.registeredKeys, ["circle", "square"])
    }
    func test_registryReturnsNilForUnknown() {
        XCTAssertNil(ShapeRegistry().make("hexagon", size: 1))
    }
    /// A shape type the registry has never heard of, registered at runtime.
    func test_registryIsOpenForExtension() {
        struct Triangle5: Shape5 {
            let base: Double
            var kind: String { "triangle" }
            func area() -> Double { 0.5 * base * base }
        }
        let r = ShapeRegistry()
        r.register("triangle") { Triangle5(base: $0) }
        XCTAssertEqual(r.make("triangle", size: 4)?.area(), 8)
    }
}

final class E3FactoryMethodTests: XCTestCase {
    private let rows = [["a", "b"], ["c", "d"]]

    func test_csvExporter() {
        XCTAssertEqual(CSVExporter().export(rows), "a,b\nc,d")
        XCTAssertEqual(CSVExporter().fileExtension, "csv")
    }
    func test_tsvExporter() {
        XCTAssertEqual(TSVExporter().export(rows), "a\tb\nc\td")
        XCTAssertEqual(TSVExporter().fileExtension, "tsv")
    }
    func test_writerDelegatesToItsFactory() {
        let csv = ReportWriter(factory: CSVExporterFactory()).write(rows)
        XCTAssertEqual(csv.filename, "report.csv")
        XCTAssertEqual(csv.body, "a,b\nc,d")

        let tsv = ReportWriter(factory: TSVExporterFactory()).write(rows)
        XCTAssertEqual(tsv.filename, "report.tsv")
        XCTAssertEqual(tsv.body, "a\tb\nc\td")
    }
    /// A brand-new exporter family, defined in the test — the writer must not change.
    func test_writerIsOpenForNewFactories() {
        struct PipeExporter: Exporter {
            var fileExtension: String { "psv" }
            func export(_ rows: [[String]]) -> String { rows.map { $0.joined(separator: "|") }.joined(separator: "\n") }
        }
        struct PipeFactory: ExporterFactory { func makeExporter() -> any Exporter { PipeExporter() } }
        let out = ReportWriter(factory: PipeFactory()).write(rows)
        XCTAssertEqual(out.filename, "report.psv")
        XCTAssertEqual(out.body, "a|b\nc|d")
    }
}

final class E4AbstractFactoryTests: XCTestCase {
    func test_lightFamily() {
        XCTAssertEqual(SettingsScreen(theme: LightTheme()).render(), ["light-button", "light-checkbox"])
    }
    func test_darkFamily() {
        XCTAssertEqual(SettingsScreen(theme: DarkTheme()).render(), ["dark-button", "dark-checkbox"])
    }
    func test_familyIsNeverMixed() {
        for theme in [LightTheme() as any ThemeFactory, DarkTheme()] {
            let rendered = SettingsScreen(theme: theme).render()
            XCTAssertTrue(rendered.allSatisfy { $0.hasPrefix(theme.themeName) },
                          "products must all come from the \(theme.themeName) family")
        }
    }
    func test_newFamilyNeedsNoChangeToTheScreen() {
        struct HCButton: Button5 { func render() -> String { "hc-button" } }
        struct HCCheckbox: Checkbox5 { func render() -> String { "hc-checkbox" } }
        struct HighContrast: ThemeFactory {
            var themeName: String { "hc" }
            func makeButton() -> any Button5 { HCButton() }
            func makeCheckbox() -> any Checkbox5 { HCCheckbox() }
        }
        XCTAssertEqual(SettingsScreen(theme: HighContrast()).render(), ["hc-button", "hc-checkbox"])
    }
}

final class E5BuilderTests: XCTestCase {
    func test_defaults() throws {
        let r = try HTTPRequestBuilder(url: "https://x.com").build()
        XCTAssertEqual(r.method, "GET")
        XCTAssertEqual(r.retries, 0)
        XCTAssertNil(r.body)
        XCTAssertEqual(r.headers, [:])
    }
    func test_fluentChaining() throws {
        let r = try HTTPRequestBuilder(url: "https://x.com")
            .method("POST")
            .header("Content-Type", "application/json")
            .body("{}")
            .retries(3)
            .build()
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(r.body, "{}")
        XCTAssertEqual(r.retries, 3)
        XCTAssertEqual(r.headers["Content-Type"], "application/json")
    }
    func test_crossFieldValidation_bodyOnGET() {
        XCTAssertThrowsError(try HTTPRequestBuilder(url: "u").body("{}").header("Content-Type", "j").build()) {
            XCTAssertEqual($0 as? BuildError, .bodyOnGET)
        }
    }
    func test_crossFieldValidation_negativeRetries() {
        XCTAssertThrowsError(try HTTPRequestBuilder(url: "u").retries(-1).build()) {
            XCTAssertEqual($0 as? BuildError, .negativeRetries)
        }
    }
    func test_crossFieldValidation_bodyWithoutContentType() {
        XCTAssertThrowsError(try HTTPRequestBuilder(url: "u").method("POST").body("{}").build()) {
            XCTAssertEqual($0 as? BuildError, .missingContentTypeForBody)
        }
    }
    func test_incrementalConstructionAcrossFunctions() throws {
        let b = HTTPRequestBuilder(url: "https://x.com").method("PUT")
        func addAuth(_ b: HTTPRequestBuilder) { b.header("Authorization", "Bearer t") }
        func addPayload(_ b: HTTPRequestBuilder) { b.header("Content-Type", "application/json").body("{}") }
        addAuth(b); addPayload(b)
        let r = try b.build()
        XCTAssertEqual(r.headers.count, 2)
        XCTAssertEqual(r.method, "PUT")
    }
}

final class E6PrototypeTests: XCTestCase {
    private func sample() -> TreeNode {
        TreeNode(value: "root", children: [
            TreeNode(value: "a", children: [TreeNode(value: "a1")]),
            TreeNode(value: "b"),
        ])
    }
    func test_preorder() {
        XCTAssertEqual(sample().preorderValues(), ["root", "a", "a1", "b"])
    }
    func test_deepCopyIsIndependent() {
        let original = sample()
        let copy = original.deepCopy()
        copy.children[0].children[0].value = "CHANGED"
        copy.value = "NEWROOT"
        XCTAssertEqual(original.preorderValues(), ["root", "a", "a1", "b"])
        XCTAssertEqual(copy.preorderValues(), ["NEWROOT", "a", "CHANGED", "b"])
        XCTAssertFalse(original.children[0] === copy.children[0])
    }
    func test_shallowCopySharesChildren() {
        let original = sample()
        let copy = original.shallowCopy()
        XCTAssertTrue(original.children[0] === copy.children[0], "shallow copy shares child references")
        copy.children[0].value = "MUTATED"
        XCTAssertEqual(original.children[0].value, "MUTATED", "…which is exactly the hazard")
    }
}

final class E7PoolTests: XCTestCase {
    func test_createsUpToMax() throws {
        let pool = ConnectionPool(maxSize: 2)
        let a = try pool.acquire(), b = try pool.acquire()
        XCTAssertEqual([a.id, b.id], [1, 2])
        XCTAssertEqual(pool.inUseCount, 2)
        XCTAssertThrowsError(try pool.acquire()) { XCTAssertEqual($0 as? PoolError, .exhausted) }
    }
    func test_releaseMakesItReusable() throws {
        let pool = ConnectionPool(maxSize: 1)
        let a = try pool.acquire()
        a.use("secret")
        try pool.release(a)
        XCTAssertEqual(pool.availableCount, 1)
        XCTAssertEqual(pool.inUseCount, 0)
        let b = try pool.acquire()
        XCTAssertTrue(a === b, "the same instance is reused")
        XCTAssertEqual(b.scratch, "", "release must reset per-client state")
    }
    func test_releasingAForeignObjectThrows() {
        let pool = ConnectionPool(maxSize: 1)
        XCTAssertThrowsError(try pool.release(PooledConnection(id: 99))) {
            XCTAssertEqual($0 as? PoolError, .foreignObject)
        }
    }
    func test_doubleReleaseThrows() throws {
        let pool = ConnectionPool(maxSize: 1)
        let a = try pool.acquire()
        try pool.release(a)
        XCTAssertThrowsError(try pool.release(a)) { XCTAssertEqual($0 as? PoolError, .foreignObject) }
        XCTAssertEqual(pool.availableCount, 1, "a double release must not duplicate the connection")
    }
}
