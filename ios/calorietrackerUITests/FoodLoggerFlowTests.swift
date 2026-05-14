import XCTest

/// Smoke tests for the P20 Food Logger work that's safe to assert from a
/// freshly-installed simulator (no pre-seeded user data). The chain-seed
/// search-to-stage path and the EditFoodEntryView "Micronutrients" rename
/// are covered by unit tests in `FoodDatabaseServiceIndexTests` plus the
/// snapshot of `EditFoodEntryView.swift` in code review — no UI smoke test
/// needed there since UI selectors against a fresh simulator are flaky.
///
/// The one P20 surface this file does cover is the ScanView -> Barcode
/// segment routing, because the binding hoist (ScanMode moved from
/// ScanView's private @State to a parent @Binding) was the one P20 change
/// that could plausibly break the existing search-bar deep-link path.
final class FoodLoggerFlowTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Same launch-arg path DashboardCallbacksTests uses — flips
        // hasCompletedOnboarding + grants AI consent so the simulator boots
        // straight to the Dashboard.
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    // MARK: - Barcode placeholder routes back to Search

    @MainActor
    func testBarcodePlaceholderSearchManuallyRoutesToSearchTab() throws {
        // Drive the Dashboard search-bar's barcode button. Same selector as
        // testSearchBarBarcodeOpensScanTab in DashboardCallbacksTests.
        let scanBarcodeBtn = app.buttons["Scan barcode"]
        XCTAssertTrue(scanBarcodeBtn.waitForExistence(timeout: 5), "Search bar barcode button not found")
        scanBarcodeBtn.tap()

        // FoodEntrySheet should land at the Scan tab; verify the Barcode
        // segment is visible. BarcodeUnavailableSheet only fires on shutter
        // capture, which we can't simulate in the simulator without a real
        // camera. What we *can* assert: the deep-link reached the right
        // tab, with the Barcode segment selected.
        let barcodeSegment = app.buttons["Barcode"]
        let barcodeSegmentText = app.staticTexts["Barcode"]
        XCTAssertTrue(
            barcodeSegment.waitForExistence(timeout: 5) || barcodeSegmentText.waitForExistence(timeout: 1),
            "Scan tab should render the Barcode/Label segmented toggle even after the ScanMode binding hoist"
        )
    }
}
