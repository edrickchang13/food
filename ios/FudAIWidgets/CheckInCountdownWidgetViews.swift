import SwiftUI
import WidgetKit

// MARK: - Entry view

struct CheckInCountdownWidgetEntryView: View {
    let entry: CheckInCountdownEntry

    var body: some View {
        CheckInCountdownSmallView(
            daysRemaining: entry.daysRemaining,
            progress: entry.progress
        )
    }
}

// MARK: - Small home-screen view

private struct CheckInCountdownSmallView: View {
    let daysRemaining: Int
    let progress: Double

    /// "DAYS" / "DAY" / "CHECK-IN TODAY"
    private var caption: String {
        switch daysRemaining {
        case 0:  return "CHECK-IN TODAY"
        case 1:  return "DAY"
        default: return "DAYS"
        }
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 10)

            // Progress arc — starts at 12 o'clock
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(hex: "5BC98B"),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(daysRemaining)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(caption)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
    }
}

// MARK: - Color(hex:) helper

/// Fileprivate to avoid duplicate-symbol collisions if other widget files
/// in this target define the same extension.
fileprivate extension Color {
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8)  & 0xFF) / 255.0,
            blue:  Double( v        & 0xFF) / 255.0
        )
    }
}
