//  Module 08 — 30 pattern-selection drills.
//
//  BEFORE YOU ANSWER EACH DRILL, do this in your head, in order:
//    1. Say the sentence: "The ______ varies by ______."  If you cannot complete
//       it, the answer is probably .noPatternNeeded.
//    2. Is the set of variants CLOSED or OPEN? That picks the mechanism.
//    3. Walk the ladder from the cheap end and stop at the first rung that works:
//         a parameter -> a closure -> an enum + switch -> a protocol + 2 types ->
//         a full pattern
//    4. Name what you are DECLINING and why.
//
//  Several drills differ from each other by a single clause. The pattern follows
//  the constraint, not the subject matter — find the deciding clause.
//
//  Read the scenarios in EXERCISES.md first, then fill in `answer(for:)`.

import Foundation

public enum Pattern8: String, Equatable, CaseIterable {
    // Creational
    case singleton, factoryMethod, abstractFactory, builder, prototype, objectPool, dependencyInjection
    // Structural
    case adapter, bridge, composite, decorator, facade, flyweight, proxy
    // Behavioral
    case chainOfResponsibility, command, iterator, mediator, memento, observer, state, strategy
    case templateMethod, visitor, nullObject
    /// The right answer is a plain function, an enum, a struct, or default arguments.
    case noPatternNeeded
}

public enum Drill: String, Equatable, CaseIterable {
    case d01_shippingCostVariesByCarrier
    case d02_orderStatusChangesWhatEveryMethodDoes
    case d03_threeDashboardsMustRefreshOnPriceChange
    case d04_supportUndoInADrawingApp
    case d05_wrapAnSDKWithDifferentMethodNames
    case d06_addLoggingAndRetryAroundARepository
    case d07_eightInitParametersSixOptionalAllKnownUpFront
    case d08_eightInitParametersBuiltAcrossThreeFunctionsWithValidation
    case d09_oneSharedImmutableConfigLoadedAtLaunch
    case d10_menuContainsItemsAndSubmenus
    case d11_expenseApprovalByLimitUpTheHierarchy
    case d12_twoHundredThousandMapPinsSharingTwelveIcons
    case d13_denyDocumentReadsUnlessTheUserIsAnAdmin
    case d14_tenFormControlsThatEnableAndDisableEachOther
    case d15_exportAnASTToThreeFormatsTypesAreFixed
    case d16_theAnalyticsDependencyIsOptional
    case d17_databaseConnectionsAreExpensiveAndReusable
    case d18_sortAListOfUsersByNameThenByAge
    case d19_snapshotAGameBeforeEachTurn
    case d20_darkAndLightWidgetsMustNeverBeMixed
    case d21_serviceHardcodesItsOwnNetworkClient
    case d22_walkATreeInPreorderAndLevelOrder
    case d23_fourStepCheckoutWhereOnlyTaxDiffersByCountry
    case d24_hideFourSubsystemCallsBehindOneMethod
    case d25_shapesTimesRenderersWouldBeTwentyClasses
    case d26_copyAConfiguredTemplateObjectRepeatedly
    case d27_pickAParserImplementationFromAFileExtension
    case d28_convertCelsiusToFahrenheitInOnePlace
    case d29_middlewarePipelineAuthThenRateLimitThenLog
    case d30_aValueObjectThatMustNeverBeInvalid
}

public func answer(for drill: Drill) -> Pattern8 { fatalError("TODO — one case per drill") }
