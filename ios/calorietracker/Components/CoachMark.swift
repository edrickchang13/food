import SwiftUI

/// One-time on-screen tooltip pointing at an anchor element.
///
/// Renders a small rounded card with a title + body + dismiss button. The
/// card appears with a soft scale+fade in animation when `isPresented`
/// becomes true. Tapping the card or its dismiss button hides it.
///
/// Designed to be attached as an `.overlay` on the anchored view:
///
/// ```swift
/// myButton.overlay(
///     CoachMark(
///         isPresented: $showHint,
///         title: "Tap to log food",
///         message: "The plus button opens the food entry sheet."
///     ),
///     alignment: .top
/// )
/// ```
///
/// Auto-shows once per `seenKey` if you use the `.coachMark(...)` modifier.
/// The seen flag is persisted in `UserDefaults` via `@AppStorage` so the mark
/// disappears for good after first dismissal.
struct CoachMark: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String

    var body: some View {
        if isPresented {
            cardContent
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(1)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text(title)
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(Color.black)
            Text(message)
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(Color.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Got it") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(BulkAITheme.Color.accent)
                .padding(.top, BulkAITheme.Spacing.xxs)
            }
        }
        .padding(BulkAITheme.Spacing.md)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
        }
    }
}

// MARK: - View modifier

/// Convenience modifier that wires up an `@AppStorage`-backed seen flag for
/// one-time presentation. The flag is set to `true` after the user dismisses
/// the mark, so subsequent launches skip it.
extension View {
    func coachMark(
        seenKey: String,
        title: String,
        message: String,
        alignment: Alignment = .top
    ) -> some View {
        modifier(CoachMarkModifier(
            seenKey: seenKey,
            title: title,
            message: message,
            alignment: alignment
        ))
    }
}

// MARK: - CoachMarkModifier

private struct CoachMarkModifier: ViewModifier {
    let seenKey: String
    let title: String
    let message: String
    let alignment: Alignment

    @State private var isPresented = false
    @AppStorage private var hasSeen: Bool

    init(seenKey: String, title: String, message: String, alignment: Alignment) {
        self.seenKey = seenKey
        self.title = title
        self.message = message
        self.alignment = alignment
        _hasSeen = AppStorage(wrappedValue: false, seenKey)
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                CoachMark(
                    isPresented: $isPresented,
                    title: title,
                    message: message
                )
                .offset(y: alignment == .top ? -88 : 88),
                alignment: alignment
            )
            .onAppear {
                guard !hasSeen else { return }
                // Slight delay so the user sees the underlying surface first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.25)) { isPresented = true }
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if !newValue { hasSeen = true }
            }
    }
}

// MARK: - Preview

#Preview("CoachMark") {
    VStack(spacing: 64) {
        Rectangle()
            .fill(BulkAITheme.Color.surfaceElevated)
            .frame(width: 56, height: 56)
            .overlay(Text("FAB").foregroundStyle(.white))
            .coachMark(
                seenKey: "coachmark.preview.fab",
                title: "Tap to log food",
                message: "The plus button opens the food entry sheet.",
                alignment: .top
            )

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
