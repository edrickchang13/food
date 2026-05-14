import SwiftUI

/// The AI tab of the Food Entry sheet (`~/Downloads/macrofactor-screens/IMG_6468.PNG`).
///
/// Layout, top to bottom:
/// 1. A secondary segmented "Snap / Describe" pill row, with two trailing
///    icon affordances: upload (gallery picker, future) and a trash/discard
///    button.
/// 2. A large dark canvas area. In Snap mode this is a camera-viewfinder
///    placeholder with a native-style circular shutter button anchored at
///    the bottom; tapping the shutter (or the canvas itself) presents the
///    project's `CameraView` and forwards the captured image to `onSnap`.
///    In Describe mode the canvas hosts a multiline `TextField` and a "Send
///    to AI" button that invokes `onDescribe`.
///
/// `AIView` deliberately holds no Gemini state of its own; the parent
/// `FoodEntrySheet` decides what to do with the captured image or typed
/// description.
struct AIView: View {

    /// Called when the user has captured an image in Snap mode.
    let onSnap: (UIImage) -> Void

    /// Called when the user submits a free-form description in Describe mode.
    /// The parent reads `description` via a separate path; here the callback
    /// is intentionally argument-less to keep `AIView` decoupled from the
    /// parent's Gemini parsing pipeline.
    /// Called with the trimmed description string when the user taps
    /// "Send to AI". Parent runs the Gemini analysis; the analyzing sheet
    /// it presents (`AnalyzingView`) is the loading state visible to the
    /// user. AIView intentionally stays out of the analysis path so the
    /// loading UX matches the camera + voice + scan flows exactly.
    let onDescribe: (String) -> Void

    @State private var mode: AIMode = .snap
    @State private var description: String = ""
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage?
    @FocusState private var descriptionFocused: Bool

    private enum AIMode: Hashable {
        case snap
        case describe
    }

    /// Drives `SegmentedToggle`'s `Int` binding while keeping `AIMode` as
    /// the source of truth.
    private var selectionIndex: Binding<Int> {
        Binding(
            get: { mode == .snap ? 0 : 1 },
            set: { newValue in
                mode = (newValue == 0) ? .snap : .describe
                if mode == .snap { descriptionFocused = false }
            }
        )
    }

    var body: some View {
        VStack(spacing: BulkAITheme.Spacing.md) {
            controlRow
            canvas
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
            onSnap(image)
            capturedImage = nil
        }
    }

    // MARK: - Top control row

    private var controlRow: some View {
        HStack(spacing: BulkAITheme.Spacing.md) {
            SegmentedToggle(
                options: ("Snap", "Describe"),
                selection: selectionIndex
            )
            .frame(maxWidth: 180)

            Spacer(minLength: BulkAITheme.Spacing.xs)

            iconButton(
                systemName: "square.and.arrow.up",
                label: "Upload from library"
            ) {
                // Upload path is handled by the parent sheet in a future
                // change; AIView only exposes the affordance here.
            }

            iconButton(
                systemName: "trash",
                label: "Discard"
            ) {
                capturedImage = nil
                description = ""
            }
        }
    }

    private func iconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(BulkAITheme.Color.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            switch mode {
            case .snap:
                snapContent
            case .describe:
                describeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Snap mode

    private var snapContent: some View {
        VStack {
            Spacer()
            shutterButton
                .padding(.bottom, BulkAITheme.Spacing.xl)
        }
    }

    /// Native iOS camera-style shutter button: white outer ring, dark gap,
    /// white inner disc. Sized to read clearly against the dark canvas.
    private var shutterButton: some View {
        Button {
            showCamera = true
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 74, height: 74)

                Circle()
                    .fill(Color.black)
                    .frame(width: 66, height: 66)

                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Snap photo for AI analysis")
    }

    // MARK: Describe mode

    private var describeContent: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Describe what you ate. e.g. two scrambled eggs and a slice of sourdough toast with butter")
                        .font(BulkAITheme.Typography.body)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextField("", text: $description, axis: .vertical)
                    .focused($descriptionFocused)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(Color.white)
                    .tint(BulkAITheme.Color.accent)
                    .lineLimit(6...12)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }

            Spacer()

            HStack {
                Spacer()
                Button {
                    descriptionFocused = false
                    let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onDescribe(trimmed)
                } label: {
                    HStack(spacing: BulkAITheme.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Send to AI")
                            .font(BulkAITheme.Typography.headline)
                    }
                    .foregroundStyle(description.isEmpty ? Color.white.opacity(0.4) : Color.black)
                    .padding(.horizontal, BulkAITheme.Spacing.lg)
                    .padding(.vertical, BulkAITheme.Spacing.sm)
                    .background(
                        Capsule().fill(
                            description.isEmpty
                                ? BulkAITheme.Color.surfaceElevated
                                : Color.white
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send description to AI")
            }
        }
        .padding(BulkAITheme.Spacing.md)
    }
}

#Preview("AIView") {
    AIView(
        onSnap: { _ in },
        onDescribe: { _ in }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
}
