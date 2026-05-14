import SwiftUI

/// Explains AltStore free-signing to users who are confused about periodic
/// re-trust prompts or "app expired" banners on their iPhone.
///
/// The view derives a "last refreshed" timestamp from the binary modification
/// date written by AltStore during each re-sign, then projects the 7-day
/// expiry window and colour-codes urgency. No network calls, no store
/// dependencies — all data comes from `Bundle.main` and `FileManager`.
struct FreeSigningStatusView: View {
    @Environment(\.dismiss) var dismiss

    @State private var lastRefreshDate: Date? = nil

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xl) {
                    heroSection
                    statusCard
                    explainerSection
                    helpLink
                }
                .padding(.horizontal, BulkAITheme.Spacing.lg)
                .padding(.vertical, BulkAITheme.Spacing.xl)
            }
            .background(BulkAITheme.Color.background.ignoresSafeArea())
            .navigationTitle("Free Signing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BulkAITheme.Typography.headline)
                        .foregroundStyle(BulkAITheme.Color.accent)
                }
            }
        }
        .task { lastRefreshDate = Self.loadBinaryModDate() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: BulkAITheme.Spacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(BulkAITheme.Color.macroCarbs)
                .accessibilityHidden(true)

            Text("Free, signed by you.")
                .font(BulkAITheme.Typography.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Bulk AI runs from your own Apple ID via AltStore. No subscription, no developer account, no tracking — just a 7-day cert refresh.")
                .font(BulkAITheme.Typography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 0) {
            statusRow(
                label: "BUILD",
                value: buildVersionString,
                valueColor: .white,
                monospacedDigits: true
            )

            cardDivider

            statusRow(
                label: "LAST REFRESHED",
                value: relativeRefreshString,
                valueColor: .white,
                monospacedDigits: false
            )

            cardDivider

            statusRow(
                label: "EXPIRES",
                value: expiryDateString,
                valueColor: expiryColor,
                monospacedDigits: false
            )
        }
        .padding(BulkAITheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BulkAITheme.Radius.lg)
                .fill(BulkAITheme.Color.surface)
        )
    }

    private var cardDivider: some View {
        Color.white.opacity(0.06)
            .frame(height: 0.5)
            .padding(.vertical, BulkAITheme.Spacing.sm)
    }

    private func statusRow(
        label: String,
        value: String,
        valueColor: Color,
        monospacedDigits: Bool
    ) -> some View {
        HStack {
            Text(label)
                .font(BulkAITheme.Typography.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(
                    monospacedDigits
                        ? BulkAITheme.Typography.headline.monospacedDigit()
                        : BulkAITheme.Typography.headline
                )
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Explainer

    private var explainerSection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
            Text("HOW IT WORKS")
                .font(BulkAITheme.Typography.caption2)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))

            stepRow(
                number: 1,
                title: "Install via AltStore",
                body: "AltStore is a free sideloading bridge that lives on your Mac. It uses your personal Apple ID to sign the build that runs on your iPhone."
            )

            stepRow(
                number: 2,
                title: "Cert refreshes every 7 days",
                body: "Apple's free developer cert is short-lived by design. AltStore re-signs the app silently as long as your phone and Mac are on the same Wi-Fi at least once a week."
            )

            stepRow(
                number: 3,
                title: "Stay on the same Wi-Fi at home",
                body: "If you're traveling away from your home Wi-Fi for more than 7 days, open AltStore on your Mac and manually refresh. The app keeps your data on-device either way."
            )
        }
    }

    private func stepRow(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BulkAITheme.Spacing.md) {
            Text("\(number)")
                .font(BulkAITheme.Typography.title3)
                .foregroundStyle(BulkAITheme.Color.accent)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
                Text(title)
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white)

                Text(body)
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Help Link

    private var helpLink: some View {
        Link(destination: URL(string: "https://altstore.io")!) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(BulkAITheme.Color.accent)
                Text("Learn more about AltStore")
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(BulkAITheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.md)
                    .fill(BulkAITheme.Color.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived State

    private var buildVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    private var relativeRefreshString: String {
        guard let date = lastRefreshDate else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var expiryDate: Date? {
        lastRefreshDate.map { $0.addingTimeInterval(7 * 24 * 3600) }
    }

    private var expiryDateString: String {
        guard let date = expiryDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var expiryColor: Color {
        guard let date = expiryDate else { return .white }
        let now = Date()
        let secondsRemaining = date.timeIntervalSince(now)
        if secondsRemaining < 24 * 3600 {
            return BulkAITheme.Color.macroProtein   // coral — urgent
        } else if secondsRemaining < 2 * 24 * 3600 {
            return BulkAITheme.Color.macroFat       // yellow — caution
        }
        return .white
    }

    // MARK: - Binary Modification Date

    /// Reads the filesystem modification date of the app binary.
    ///
    /// AltStore overwrites the binary on every re-sign, so this date is a
    /// reasonable proxy for "last refreshed." Returns `nil` if the path is
    /// unavailable or the attribute read fails — callers display "—" in
    /// that case.
    private static func loadBinaryModDate() -> Date? {
        guard let path = Bundle.main.executablePath else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date
    }
}

// MARK: - Preview

#Preview {
    FreeSigningStatusView()
        .preferredColorScheme(.dark)
}
