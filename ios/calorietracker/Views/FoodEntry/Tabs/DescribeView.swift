import SwiftUI

/// Free-form text description tab for the Food Entry sheet's "Describe" path.
///
/// The user types a natural-language description of what they ate and taps
/// "Parse with AI". The actual Gemini call lives in `GeminiService` and is
/// wired up by the parent (`FoodEntrySheet`); this view is intentionally
/// stateless beyond its text buffer and surfaces submission via `onSubmit`.
///
/// The multiline TextField reserves 3-5 visual lines via a minimum frame
/// height so the affordance reads as a paragraph input even when empty.
struct DescribeView: View {
    @State var text: String = ""
    let onSubmit: (String) -> Void

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmed.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
                textArea
                submitButton
                aiNote
            }
            .padding(.horizontal, BulkAITheme.Spacing.lg)
            .padding(.top, BulkAITheme.Spacing.md)
            .padding(.bottom, BulkAITheme.Spacing.xxl)
        }
        .background(BulkAITheme.Color.background)
    }

    // MARK: - Sections

    private var textArea: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder, shown only when the buffer is empty. SwiftUI's
            // native TextField placeholder doesn't render on multi-line
            // axis editors, so we overlay it ourselves.
            if text.isEmpty {
                Text("two scrambled eggs with cheddar, 100g rolled oats, ...")
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, BulkAITheme.Spacing.md)
                    .padding(.vertical, BulkAITheme.Spacing.md)
                    .allowsHitTesting(false)
            }

            TextField("", text: $text, axis: .vertical)
                .lineLimit(3...5)
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, BulkAITheme.Spacing.md)
                .padding(.vertical, BulkAITheme.Spacing.md)
        }
        .frame(minHeight: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                .fill(BulkAITheme.Color.surfaceElevated)
        )
    }

    private var submitButton: some View {
        Button {
            guard canSubmit else { return }
            onSubmit(trimmed)
        } label: {
            HStack(spacing: BulkAITheme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Parse with AI")
                    .font(BulkAITheme.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                    .fill(BulkAITheme.Color.accent.opacity(canSubmit ? 1.0 : 0.4))
            )
        }
        .disabled(!canSubmit)
    }

    private var aiNote: some View {
        HStack(spacing: BulkAITheme.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("Bulk AI uses Gemini to parse your text")
                .font(BulkAITheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

#Preview {
    DescribeView(
        text: "two scrambled eggs with cheddar, 100g rolled oats with almond butter, a banana",
        onSubmit: { _ in }
    )
    .preferredColorScheme(.dark)
}
