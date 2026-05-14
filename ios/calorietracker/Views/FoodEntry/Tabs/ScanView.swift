import SwiftUI

/// Distinguishes the two sub-modes of the Scan tab. Barcode targets a UPC/EAN
/// scan path; Label targets the nutrition-label OCR analyzer. Carrying the
/// mode through `onCapture` lets the parent route the captured image to the
/// correct Gemini analyzer without ScanView owning that logic itself.
enum ScanMode: String, CaseIterable, Hashable, Sendable {
    case barcode
    case label
}

/// The result produced when the user captures an image in the Scan tab.
///
/// - `label(UIImage)`: The user captured in Label mode. The parent should
///   route the image to the nutrition-label OCR analyzer.
/// - `barcodeUnavailable`: The user captured in Barcode mode. The image is
///   intentionally not consumed — the parent should show the
///   `BarcodeUnavailableSheet` instead of feeding the image to any analyzer.
enum ScanResult {
    case label(UIImage)
    case barcodeUnavailable
}

/// The Scan tab of the Food Entry sheet (`~/Downloads/macrofactor-screens/IMG_6467.PNG`).
///
/// Layout, top to bottom:
/// 1. A secondary segmented "Barcode / Label" pill row, with two trailing
///    icon affordances: flash toggle and a trash/discard button.
/// 2. A large dark camera-viewfinder placeholder that fills the rest of the
///    available area. Tapping it presents the project's `CameraView` (an
///    `UIImagePickerController` wrapper that lives in `ContentView.swift`)
///    inside a `fullScreenCover`, and the resulting `ScanResult` is forwarded
///    to `onCapture`.
///
/// `ScanView` deliberately holds no Gemini/database state of its own. The
/// parent `FoodEntrySheet` decides what to do with the captured image based
/// on the `ScanResult`. The parent owns `scanMode` so it can reset the
/// segment to `.label` from `BarcodeUnavailableSheet`'s "Try label scan" CTA.
struct ScanView: View {

    /// The active sub-mode (Barcode vs Label). Owned by the parent so the
    /// parent can reset it to `.label` via `BarcodeUnavailableSheet`.
    @Binding var scanMode: ScanMode

    /// Called when the user has captured an image. The result encodes whether
    /// the image is ready to analyze (`.label`) or whether the barcode path is
    /// unavailable (`.barcodeUnavailable`), so the caller never needs to
    /// inspect the internal segment state.
    let onCapture: (ScanResult) -> Void

    @State private var isFlashOn: Bool = false
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage?

    /// Drives `SegmentedToggle`'s `Int` binding while keeping `ScanMode` as
    /// the source of truth for the rest of the view.
    private var selectionIndex: Binding<Int> {
        Binding(
            get: { scanMode == .barcode ? 0 : 1 },
            set: { newValue in scanMode = (newValue == 0) ? .barcode : .label }
        )
    }

    var body: some View {
        VStack(spacing: BulkAITheme.Spacing.md) {
            controlRow
            viewfinder
        }
        .padding(.horizontal, BulkAITheme.Spacing.md)
        .padding(.top, BulkAITheme.Spacing.md)
        .padding(.bottom, BulkAITheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BulkAITheme.Color.background)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newValue in
            guard let image = newValue else { return }
            capturedImage = nil
            switch scanMode {
            case .barcode:
                onCapture(.barcodeUnavailable)
            case .label:
                onCapture(.label(image))
            }
        }
    }

    // MARK: - Top control row

    private var controlRow: some View {
        HStack(spacing: BulkAITheme.Spacing.md) {
            SegmentedToggle(
                options: ("Barcode", "Label"),
                selection: selectionIndex
            )
            .frame(maxWidth: 180)

            Spacer(minLength: BulkAITheme.Spacing.xs)

            iconButton(
                systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                accent: isFlashOn ? BulkAITheme.Color.macroFat : .white.opacity(0.8),
                label: isFlashOn ? "Turn flash off" : "Turn flash on"
            ) {
                isFlashOn.toggle()
            }

            iconButton(
                systemName: "trash",
                accent: .white.opacity(0.8),
                label: "Discard"
            ) {
                capturedImage = nil
            }
        }
    }

    private func iconButton(
        systemName: String,
        accent: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(BulkAITheme.Color.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        Button {
            showCamera = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )

                // Subtle inner frame hint: barcodes get a horizontal reticle,
                // labels get a wider rectangular reticle. Both are decorative,
                // and meant to be replaced by the live preview once the
                // capture session is wired up.
                reticle
                    .foregroundStyle(Color.white.opacity(0.18))
                    .padding(.horizontal, BulkAITheme.Spacing.xxl)
                    .padding(.vertical, BulkAITheme.Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scanMode == .barcode ? "Scan barcode" : "Scan nutrition label")
    }

    @ViewBuilder
    private var reticle: some View {
        switch scanMode {
        case .barcode:
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .center)
        case .label:
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview("ScanView") {
    ScanView(scanMode: .constant(.barcode)) { _ in }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BulkAITheme.Color.background)
}
