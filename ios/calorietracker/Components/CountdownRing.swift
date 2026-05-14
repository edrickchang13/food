import SwiftUI

/// A circular progress ring with a multi-line center label.
///
/// The progress arc starts at 12 o'clock and sweeps clockwise. The unfilled
/// portion of the track is drawn in `BulkAITheme.Color.surfaceElevated`, while
/// the active arc uses `accent`. The center shows a large title (e.g. "5") and
/// a small all-caps subtitle (e.g. "DAYS until check-in"), mirroring the
/// countdown card on the Strategy screen.
struct CountdownRing: View {
    let progress: Double
    let centerTitle: String
    let centerSubtitle: String
    var accent: Color = BulkAITheme.Color.macroCarbs
    var size: CGFloat = 200

    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    private var strokeWidth: CGFloat {
        // Roughly 8-10pt on a 200pt ring, scaled for other sizes.
        max(6, size * 0.045)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    BulkAITheme.Color.surfaceElevated,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: CGFloat(clampedProgress))
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: clampedProgress)

            centerLabel
                .padding(.horizontal, strokeWidth * 2)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(centerTitle) \(centerSubtitle)"))
        .accessibilityValue(Text("\(Int(clampedProgress * 100)) percent"))
    }

    private var centerLabel: some View {
        VStack(spacing: 4) {
            Text(centerTitle)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(centerSubtitle.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.08 * 11)
                .foregroundStyle(Color.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        CountdownRing(
            progress: 0.2,
            centerTitle: "9",
            centerSubtitle: "Days until check-in"
        )

        CountdownRing(
            progress: 0.6,
            centerTitle: "5",
            centerSubtitle: "Days until check-in"
        )

        CountdownRing(
            progress: 1.0,
            centerTitle: "0",
            centerSubtitle: "Check-in today"
        )
    }
    .padding(24)
    .background(BulkAITheme.Color.background)
    .preferredColorScheme(.dark)
}
