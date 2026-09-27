import XCTest
@testable import M08

final class M08DrillTests: XCTestCase {
    private let key: [Drill: Pattern8] = [
        .d01_shippingCostVariesByCarrier: .strategy,
        .d02_orderStatusChangesWhatEveryMethodDoes: .state,
        .d03_threeDashboardsMustRefreshOnPriceChange: .observer,
        .d04_supportUndoInADrawingApp: .command,
        .d05_wrapAnSDKWithDifferentMethodNames: .adapter,
        .d06_addLoggingAndRetryAroundARepository: .decorator,
        .d07_eightInitParametersSixOptionalAllKnownUpFront: .noPatternNeeded,
        .d08_eightInitParametersBuiltAcrossThreeFunctionsWithValidation: .builder,
        .d09_oneSharedImmutableConfigLoadedAtLaunch: .singleton,
        .d10_menuContainsItemsAndSubmenus: .composite,
        .d11_expenseApprovalByLimitUpTheHierarchy: .chainOfResponsibility,
        .d12_twoHundredThousandMapPinsSharingTwelveIcons: .flyweight,
        .d13_denyDocumentReadsUnlessTheUserIsAnAdmin: .proxy,
        .d14_tenFormControlsThatEnableAndDisableEachOther: .mediator,
        .d15_exportAnASTToThreeFormatsTypesAreFixed: .visitor,
        .d16_theAnalyticsDependencyIsOptional: .nullObject,
        .d17_databaseConnectionsAreExpensiveAndReusable: .objectPool,
        .d18_sortAListOfUsersByNameThenByAge: .noPatternNeeded,
        .d19_snapshotAGameBeforeEachTurn: .memento,
        .d20_darkAndLightWidgetsMustNeverBeMixed: .abstractFactory,
        .d21_serviceHardcodesItsOwnNetworkClient: .dependencyInjection,
        .d22_walkATreeInPreorderAndLevelOrder: .iterator,
        .d23_fourStepCheckoutWhereOnlyTaxDiffersByCountry: .templateMethod,
        .d24_hideFourSubsystemCallsBehindOneMethod: .facade,
        .d25_shapesTimesRenderersWouldBeTwentyClasses: .bridge,
        .d26_copyAConfiguredTemplateObjectRepeatedly: .prototype,
        .d27_pickAParserImplementationFromAFileExtension: .factoryMethod,
        .d28_convertCelsiusToFahrenheitInOnePlace: .noPatternNeeded,
        .d29_middlewarePipelineAuthThenRateLimitThenLog: .chainOfResponsibility,
        .d30_aValueObjectThatMustNeverBeInvalid: .noPatternNeeded,
    ]

    func test_allThirtyDrills() {
        var wrong: [String] = []
        for d in Drill.allCases where answer(for: d) != key[d] {
            wrong.append("\(d.rawValue): expected \(key[d]!.rawValue), got \(answer(for: d).rawValue)")
        }
        XCTAssertTrue(wrong.isEmpty, "\(wrong.count)/30 wrong:\n" + wrong.joined(separator: "\n"))
    }

    func test_scoreIsMeaningful() {
        let correct = Drill.allCases.filter { answer(for: $0) == key[$0] }.count
        XCTAssertGreaterThanOrEqual(correct, 30, "score \(correct)/30 — re-read the drills you missed in SOLUTIONS.md")
    }
}
