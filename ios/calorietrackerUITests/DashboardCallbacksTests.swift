import XCTest

/// Smoke-tests every interactive callback on `DashboardView`. Each test boots
/// the app with `--skip-onboarding`, taps a single dashboard surface, and
/// asserts that the expected destination (sheet / alert / detail view)
/// appears.
///
/// These tests catch the class of regression that motivated wiring the
/// dashboard in the first place: every callback used to be a `/* TODO */`
/// no-op, so tapping anything did nothing and the user couldn't tell whether
/// the app had hung. If a callback regresses back to a no-op, the matching
/// assertion below trips with a precise pointer to the offending surface.
final class DashboardCallbacksTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The app reads `--skip-onboarding` in `calorietrackerApp.swift` and
        // flips `hasCompletedOnboarding` so we don't sit in the onboarding
        // sheet for every test. (See the existing handler around the
        // hasCompletedOnboarding @AppStorage in calorietrackerApp.swift.)
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    // MARK: - Insights row

    @MainActor
    func testInsightSeeAllOpensTDEEExplainer() throws {
        // "See All" on the Insights & Analytics grid should open the
        // DynamicTDEEExplainer sheet. Identifier: button labeled "See All"
        // that's nearest the Insights heading.
        let seeAll = app.buttons["See All"].firstMatch
        XCTAssertTrue(seeAll.waitForExistence(timeout: 5), "Insights See All not found")
        seeAll.tap()

        let title = app.staticTexts["Your engine math, exposed."]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Tapping Insights See All should present DynamicTDEEExplainer")
    }

    @MainActor
    func testExpenditureInsightOpensTDEEExplainer() throws {
        let tile = app.staticTexts["Expenditure"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Expenditure insight tile not found")
        tile.tap()

        let title = app.staticTexts["Your engine math, exposed."]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Tapping Expenditure tile should present DynamicTDEEExplainer")
    }

    // MARK: - Body metrics

    @MainActor
    func testScaleWeightCardOpensLogWeight() throws {
        // The card row has accessibilityLabel "Scale Weight" per
        // BodyMetricsRow.swift. Tapping opens LogWeightSheet which exposes
        // a "Log Weight" navigation title.
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Scale")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Scale Weight card not found")
        card.tap()

        // LogWeightSheet renders a navigation title "Log Weight" or similar.
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 3),
            "Tapping Scale Weight should present a sheet with a nav bar"
        )
    }

    // MARK: - More section

    @MainActor
    func testNutritionDataManagerOpensFoodDatabase() throws {
        // The Nutrition Data Manager row in MoreSection should open
        // FoodDatabaseView. Scroll the dashboard down to find the row.
        app.swipeUp()
        app.swipeUp()
        let row = app.buttons["Nutrition Data Manager"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Nutrition Data Manager row not found")
        row.tap()

        // FoodDatabaseView's navigation title is "Food database".
        let title = app.navigationBars["Food database"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Nutrition Data Manager should present FoodDatabaseView")
    }

    @MainActor
    func testStrategyRowOpensStrategySheet() throws {
        app.swipeUp()
        app.swipeUp()
        let row = app.buttons["Strategy"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Strategy row not found")
        row.tap()

        // StrategyView shows the big "STRATEGY" wordmark.
        let title = app.staticTexts["STRATEGY"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Strategy row should present StrategyView")
    }

    @MainActor
    func testEditGoalRowOpensWizard() throws {
        app.swipeUp()
        app.swipeUp()
        let row = app.buttons["Edit Goal"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Edit Goal row not found")
        row.tap()

        // EditGoalFlow's navigation title is "Edit Goal".
        let title = app.navigationBars["Edit Goal"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Edit Goal row should present the wizard")
    }

    @MainActor
    func testSetProgramRowOpensWizard() throws {
        app.swipeUp()
        app.swipeUp()
        let row = app.buttons["Set New Program"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Set New Program row not found")
        row.tap()

        // SetProgramFlow shows "Pick a program style" as its step 1 heading.
        let title = app.staticTexts["Pick a program style"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Set New Program row should present the wizard")
    }

    // MARK: - Search bar

    @MainActor
    func testSearchBarBarcodeOpensScanTab() throws {
        // DashboardSearchBar's barcode button has accessibilityLabel
        // "Scan barcode" per the component's spec.
        let barcode = app.buttons["Scan barcode"]
        XCTAssertTrue(barcode.waitForExistence(timeout: 5), "Search bar barcode button not found")
        barcode.tap()

        // FoodEntrySheet's Scan tab shows a Barcode/Label segmented toggle.
        // SegmentedToggle wraps each option in a Button so we check either form.
        let barcodeSegment = app.buttons["Barcode"]
        let barcodeText = app.staticTexts["Barcode"]
        XCTAssertTrue(
            barcodeSegment.waitForExistence(timeout: 5) || barcodeText.waitForExistence(timeout: 1),
            "Barcode button should open FoodEntrySheet at Scan tab"
        )
    }

    @MainActor
    func testSearchBarAIOpensAITab() throws {
        let aiButton = app.buttons["Ask Bulk AI"]
        XCTAssertTrue(aiButton.waitForExistence(timeout: 5), "Search bar AI button not found")
        aiButton.tap()

        // FoodEntrySheet's AI tab shows a Snap/Describe segmented toggle.
        let snapSegment = app.buttons["Snap"]
        let snapText = app.staticTexts["Snap"]
        XCTAssertTrue(
            snapSegment.waitForExistence(timeout: 5) || snapText.waitForExistence(timeout: 1),
            "AI button should open FoodEntrySheet at AI tab"
        )
    }

    // MARK: - Habits row

    @MainActor
    func testHabitsWeighInOpensLogWeight() throws {
        // HabitsSection has two tappable rows: Weigh-Ins and Food Logging.
        // The weigh-in row should open LogWeightSheet.
        app.swipeUp()
        let weighRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Weigh")).firstMatch
        XCTAssertTrue(weighRow.waitForExistence(timeout: 5), "Weigh-in habit row not found")
        weighRow.tap()

        // LogWeightSheet presents a nav bar.
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 3),
            "Weigh-in row should present LogWeightSheet"
        )
    }
}
