import Testing
import SwiftUI
import UIKit
@testable import calorietracker

/// One-shot export helper for the Bulk AI app icon.
///
/// Run via:
///
///     xcodebuild test \
///       -project ios/calorietracker.xcodeproj \
///       -scheme calorietracker \
///       -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
///       -only-testing:calorietrackerTests/AppIconExportTests/exportAppIcon
///
/// The test writes `BulkAI-AppIcon.png` to the app container's documents
/// directory. Retrieve the path via `xcrun simctl get_app_container booted
/// com.edrickchang.calorietracker data`, or read the printed path in the
/// test output.
///
/// Copy the output file to:
///
///     ios/calorietracker/Assets.xcassets/AppIcon.appiconset/appicon.png
///
/// The test is disabled by default so normal CI runs skip it. Remove
/// `.disabled(...)` once when you want a fresh export, then restore it.
struct AppIconExportTests {

    @Test(
        "Export AppIconArt to PNG",
        .disabled("On-demand only — remove .disabled to bake a fresh icon")
    )
    @MainActor
    func exportAppIcon() throws {
        let renderer = ImageRenderer(content: AppIconArt())
        // Canvas is already 1024×1024 pts; scale 1 renders at exactly 1024×1024 px.
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(
            width: AppIconArt.canvasSize,
            height: AppIconArt.canvasSize
        )

        guard let uiImage = renderer.uiImage else {
            Issue.record("ImageRenderer produced no UIImage — check that AppIconArt compiles and has a non-empty body")
            return
        }

        guard let pngData = uiImage.pngData() else {
            Issue.record("UIImage.pngData() returned nil")
            return
        }

        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let outputURL = documentsURL.appendingPathComponent("BulkAI-AppIcon.png")
        try pngData.write(to: outputURL, options: .atomic)

        print("BulkAI app icon exported to:", outputURL.path)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }
}
