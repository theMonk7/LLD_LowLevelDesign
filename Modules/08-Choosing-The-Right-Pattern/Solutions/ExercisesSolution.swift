//  Module 08 reference solution — the 30 selection drills.
//
//  HOW TO READ THIS FILE
//  The code is a single switch; there is nothing to learn from it. The learning is
//  in SOLUTIONS.md, which gives the REASONING for each answer — specifically the
//  "what varies" sentence that produced it.
//
//  Two things to notice about the answer set itself:
//   1. Four of the thirty answers are `.noPatternNeeded`. In a real interview
//      roughly that proportion of "should I use a pattern here?" moments should
//      end in no. Candidates who never decline look insecure, not thorough.
//   2. Several drills differ by ONE CLAUSE (07 vs 08, 11 vs 29, 06 vs 13). The
//      pattern follows the CONSTRAINT, not the domain. Train yourself to hunt for
//      the deciding clause rather than pattern-matching on the subject matter.

import Foundation

public enum Pattern8: String, Equatable, CaseIterable {
    case singleton, factoryMethod, abstractFactory, builder, prototype, objectPool, dependencyInjection
    case adapter, bridge, composite, decorator, facade, flyweight, proxy
    case chainOfResponsibility, command, iterator, mediator, memento, observer, state, strategy
    case templateMethod, visitor, nullObject
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

public func answer(for drill: Drill) -> Pattern8 {
    switch drill {
    case .d01_shippingCostVariesByCarrier:                          .strategy
    case .d02_orderStatusChangesWhatEveryMethodDoes:                .state
    case .d03_threeDashboardsMustRefreshOnPriceChange:              .observer
    case .d04_supportUndoInADrawingApp:                             .command
    case .d05_wrapAnSDKWithDifferentMethodNames:                    .adapter
    case .d06_addLoggingAndRetryAroundARepository:                  .decorator
    case .d07_eightInitParametersSixOptionalAllKnownUpFront:        .noPatternNeeded
    case .d08_eightInitParametersBuiltAcrossThreeFunctionsWithValidation: .builder
    case .d09_oneSharedImmutableConfigLoadedAtLaunch:               .singleton
    case .d10_menuContainsItemsAndSubmenus:                         .composite
    case .d11_expenseApprovalByLimitUpTheHierarchy:                 .chainOfResponsibility
    case .d12_twoHundredThousandMapPinsSharingTwelveIcons:          .flyweight
    case .d13_denyDocumentReadsUnlessTheUserIsAnAdmin:              .proxy
    case .d14_tenFormControlsThatEnableAndDisableEachOther:         .mediator
    case .d15_exportAnASTToThreeFormatsTypesAreFixed:               .visitor
    case .d16_theAnalyticsDependencyIsOptional:                     .nullObject
    case .d17_databaseConnectionsAreExpensiveAndReusable:           .objectPool
    case .d18_sortAListOfUsersByNameThenByAge:                      .noPatternNeeded
    case .d19_snapshotAGameBeforeEachTurn:                          .memento
    case .d20_darkAndLightWidgetsMustNeverBeMixed:                  .abstractFactory
    case .d21_serviceHardcodesItsOwnNetworkClient:                  .dependencyInjection
    case .d22_walkATreeInPreorderAndLevelOrder:                     .iterator
    case .d23_fourStepCheckoutWhereOnlyTaxDiffersByCountry:         .templateMethod
    case .d24_hideFourSubsystemCallsBehindOneMethod:                .facade
    case .d25_shapesTimesRenderersWouldBeTwentyClasses:             .bridge
    case .d26_copyAConfiguredTemplateObjectRepeatedly:              .prototype
    case .d27_pickAParserImplementationFromAFileExtension:          .factoryMethod
    case .d28_convertCelsiusToFahrenheitInOnePlace:                 .noPatternNeeded
    case .d29_middlewarePipelineAuthThenRateLimitThenLog:           .chainOfResponsibility
    case .d30_aValueObjectThatMustNeverBeInvalid:                   .noPatternNeeded
    }
}
