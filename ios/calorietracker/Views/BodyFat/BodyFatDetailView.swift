import SwiftUI

/// Full-screen body-fat history screen, sibling of the weight detail view.
///
/// Layout: sparkline trend card, 3-column stats row (current %, 30-day delta,
/// lean mass), descending history list with swipe-to-delete + confirmation
/// dialog, and a pinned "Log body fat" pill CTA. All data comes from the
/// environment — no init arguments required.
///
/// Route: pushed from the BodyMetrics card body-fat tile in the Dashboard.
@MainActor
struct BodyFatDetailView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(BodyFatStore.self) var bodyFatStore
    @Environment(ProfileStore.self) var profileStore

    @State private var showLogBodyFat: Bool = false
    @State private var pendingDelete: BodyFatEntry?

    @AppStorage("useMetric") private var useMetric = false

    // MARK: - Derived

    private var sortedEntries: [BodyFatEntry] {
        bodyFatStore.entries.sorted { $0.date > $1.date }
    }

    private var currentFraction: Double {
        bodyFatStore.latestEntry?.bodyFatFraction
            ?? profileStore.profile.bodyFatPercentage
            ?? 0
    }

    private var thirtyDayDelta: Double? {
        let asc = bodyFatStore.entries.sorted { $0.date < $1.date }
        guard let latest = asc.last else { return nil }
        let cutoff = Date.now.addingTimeInterval(-30 * 86400)
        let baseline = asc.first(where: { $0.date >= cutoff }) ?? asc.first
        guard let baseline, baseline.id != latest.id else { return nil }
        return latest.bodyFatFraction - baseline.bodyFatFraction
    }

    private var leanMassText: String {
        let leanKg = profileStore.profile.weightKg * (1 - currentFraction)
        return useMetric
            ? String(format: "%.1f kg", leanKg)
            : String(format: "%.1f lb", leanKg * 2.20462)
    }

    private var logSeed: Double {
        bodyFatStore.latestEntry?.bodyFatFraction
            ?? profileStore.profile.bodyFatPercentage
            ?? 0.20
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                logPill
                    .padding(.horizontal, BulkAITheme.Spacing.lg)
                    .padding(.bottom, BulkAITheme.Spacing.md)
            }
            .background(BulkAITheme.Color.background.ignoresSafeArea())
            .navigationTitle("Body fat history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showLogBodyFat = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showLogBodyFat) {
                LogBodyFatSheet(currentFraction: logSeed) { fraction in
                    bodyFatStore.addEntry(BodyFatEntry(bodyFatFraction: fraction))
                }
            }
            .confirmationDialog(
                "Delete this reading?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = pendingDelete { bodyFatStore.deleteEntry(entry) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.md) {
                chartCard
                statsRow
                historySection
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, BulkAITheme.Spacing.md)
            .padding(.top, BulkAITheme.Spacing.sm)
        }
    }

    // MARK: - Chart card

    private var chartCard: some View {
        Group {
            if sortedEntries.isEmpty {
                Text("Log a body-fat reading\nto see your trend here.")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            } else {
                BodyFatSparkline(
                    fractions: sortedEntries.reversed().map(\.bodyFatFraction),
                    color: BulkAITheme.Color.bodyMetrics
                )
                .frame(height: 80)
            }
        }
        .surfaceCard(padding: BulkAITheme.Spacing.lg)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell("CURRENT", String(format: "%.1f%%", currentFraction * 100))
            statDivider
            statCell("30-DAY Δ", thirtyDayDelta.map { String(format: "%+.1fpp", $0 * 100) } ?? "--")
            statDivider
            statCell(useMetric ? "LEAN (KG)" : "LEAN (LB)", leanMassText)
        }
        .surfaceCard(padding: BulkAITheme.Spacing.md)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 0.5, height: 40)
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: BulkAITheme.Spacing.xxs) {
            Text(label)
                .font(BulkAITheme.Typography.caption2)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(BulkAITheme.Typography.title3)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text("ALL ENTRIES")
                .font(BulkAITheme.Typography.caption2)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, BulkAITheme.Spacing.xxs)

            if sortedEntries.isEmpty {
                Text("No body-fat readings yet.\nTap + to log your first.")
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BulkAITheme.Spacing.xl)
                    .surfaceCard()
            } else {
                // List gives us swipeActions; .plain + insets for custom card look.
                List {
                    ForEach(sortedEntries) { entry in
                        historyRow(entry)
                            .listRowBackground(BulkAITheme.Color.surface)
                            .listRowSeparatorTint(.white.opacity(0.08))
                            .listRowInsets(EdgeInsets(
                                top: 0, leading: BulkAITheme.Spacing.md,
                                bottom: 0, trailing: BulkAITheme.Spacing.md
                            ))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BulkAITheme.Radius.md, style: .continuous)
                        .stroke(BulkAITheme.Color.surfaceElevated, lineWidth: 0.5)
                )
                .frame(height: min(CGFloat(sortedEntries.count) * 68, 400))
            }
        }
    }

    private func historyRow(_ entry: BodyFatEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(BulkAITheme.Typography.body)
                    .foregroundStyle(.white)
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
            Text(String(format: "%.1f%%", entry.bodyFatFraction * 100))
                .font(BulkAITheme.Typography.title3)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.vertical, BulkAITheme.Spacing.sm)
    }

    // MARK: - Log pill

    private var logPill: some View {
        Button { showLogBodyFat = true } label: {
            Text("Log body fat")
                .font(BulkAITheme.Typography.headline)
                .foregroundStyle(BulkAITheme.Color.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BulkAITheme.Spacing.md)
                .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Body Fat Sparkline

/// Hand-drawn sparkline mirroring the `SparklineShape` pattern in InsightCard.
/// 2pt rounded line + small ring dots at every data point, in `bodyMetrics` green.
private struct BodyFatSparkline: View {
    let fractions: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let pts = plotPoints(in: proxy.size)
            ZStack {
                if pts.count >= 2 {
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                    Circle()
                        .fill(BulkAITheme.Color.surface)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().stroke(color, lineWidth: 1.5))
                        .position(pt)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func plotPoints(in size: CGSize) -> [CGPoint] {
        guard fractions.count >= 2 else {
            return fractions.isEmpty ? [] : [CGPoint(x: size.width / 2, y: size.height / 2)]
        }
        let lo = fractions.min() ?? 0
        let hi = fractions.max() ?? 0
        let range = max(hi - lo, 0.0001)
        let stepX = size.width / CGFloat(fractions.count - 1)
        return fractions.enumerated().map { i, v in
            CGPoint(x: stepX * CGFloat(i), y: size.height - CGFloat((v - lo) / range) * size.height)
        }
    }
}

// MARK: - Preview

#Preview("Body Fat Detail — seeded") {
    @MainActor
    struct Host: View {
        @State private var bfStore = BodyFatStore()
        @State private var profStore = ProfileStore()
        @State private var seeded = false

        var body: some View {
            BodyFatDetailView()
                .environment(bfStore)
                .environment(profStore)
                .onAppear {
                    guard !seeded else { return }
                    seeded = true
                    let fractions: [Double] = [0.20, 0.19, 0.195, 0.185, 0.19, 0.182, 0.18, 0.178]
                    fractions.enumerated().forEach { offset, fraction in
                        let date = Date.now.addingTimeInterval(Double(offset - fractions.count + 1) * 86400 * 4)
                        bfStore.addEntry(BodyFatEntry(date: date, bodyFatFraction: fraction))
                    }
                }
        }
    }
    return Host()
}
