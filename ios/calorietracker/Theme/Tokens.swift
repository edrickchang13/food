import SwiftUI

/// Design tokens for the MacroFactor-parity Bulk AI UI.
///
/// Colors are derived from the MacroFactor screenshots in `~/Downloads/macrofactor-screens/`,
/// with the Bulk AI coral accent preserved on top. Typography uses SF Rounded for the
/// numeric-forward feel of the reference design. Spacing/radius follow a small fixed scale
/// so layouts stay rhythmic across surfaces.
enum BulkAITheme {

    // MARK: Color

    enum Color {
        // Surfaces
        static let background = SwiftUI.Color(hex: "0F0F10")
        static let surface = SwiftUI.Color(hex: "1A1A1C")
        static let surfaceElevated = SwiftUI.Color(hex: "232326")

        // Domain accents (MacroFactor convention preserved)
        static let macroCalories = SwiftUI.Color(hex: "4C9AFF")   // blue
        static let macroProtein = SwiftUI.Color(hex: "E36B5E")    // coral / red-orange
        static let macroFat = SwiftUI.Color(hex: "E8C547")        // mustard yellow
        static let macroCarbs = SwiftUI.Color(hex: "5BC98B")      // mint green

        // Pink/rose accent for expenditure visuals — matches the MacroFactor
        // semantic palette where Expenditure (TDEE) is rose, distinct from
        // calorie blue, weight purple, and the macro family. Replaces the
        // earlier brown sparkline that read too close to the macro yellow.
        static let expenditure = SwiftUI.Color(hex: "EC4899")     // pink/rose
        static let weightTrend = SwiftUI.Color(hex: "9D7BD8")     // purple
        static let bodyMetrics = SwiftUI.Color(hex: "5BC98B")     // green
        static let activity = SwiftUI.Color(hex: "F4A07A")        // coral steps

        // Bulk AI accent stays
        static let accent = SwiftUI.Color(hex: "FF6B6B")
    }

    // MARK: Typography
    //
    // SF Rounded family. Sizes match the seven-step scale called out in PHASE_A.md:
    // 11 / 13 / 15 / 17 / 20 / 28 / 40.

    enum Typography {
        static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let display = Font.system(size: 40, weight: .bold, design: .rounded)
    }

    // MARK: Spacing
    //
    // 4 / 8 / 12 / 16 / 20 / 24 / 32. Use named constants so layouts stay snappable.

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radius

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
    }
}

// MARK: - Color(hex: String)
//
// The project already ships a `Color(hex: UInt)` initializer in `Views/Theme.swift`.
// We add a string-based variant here so the token table reads naturally as hex literals
// matching the MacroFactor design system. Distinct label keeps both initializers callable.
extension Color {
    /// Initializes a color from a hex string. Accepts 6-digit (RGB) or 8-digit (RGBA)
    /// hex, with or without a leading `#`. Returns transparent black on malformed input
    /// rather than trapping, so a typo in a token table never crashes the app at launch.
    init(hex: String, opacity: Double = 1.0) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgbValue) else {
            self.init(red: 0, green: 0, blue: 0, opacity: 0)
            return
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 6:
            red = Double((rgbValue >> 16) & 0xFF) / 255.0
            green = Double((rgbValue >> 8) & 0xFF) / 255.0
            blue = Double(rgbValue & 0xFF) / 255.0
            alpha = opacity
        case 8:
            red = Double((rgbValue >> 24) & 0xFF) / 255.0
            green = Double((rgbValue >> 16) & 0xFF) / 255.0
            blue = Double((rgbValue >> 8) & 0xFF) / 255.0
            alpha = Double(rgbValue & 0xFF) / 255.0 * opacity
        default:
            self.init(red: 0, green: 0, blue: 0, opacity: 0)
            return
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

#Preview("BulkAITheme tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.lg) {
            Text("Bulk AI Theme")
                .font(BulkAITheme.Typography.title)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.sm) {
                Text("Colors")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white.opacity(0.8))

                swatchRow(name: "background", color: BulkAITheme.Color.background)
                swatchRow(name: "surface", color: BulkAITheme.Color.surface)
                swatchRow(name: "surfaceElevated", color: BulkAITheme.Color.surfaceElevated)
                swatchRow(name: "macroCalories", color: BulkAITheme.Color.macroCalories)
                swatchRow(name: "macroProtein", color: BulkAITheme.Color.macroProtein)
                swatchRow(name: "macroFat", color: BulkAITheme.Color.macroFat)
                swatchRow(name: "macroCarbs", color: BulkAITheme.Color.macroCarbs)
                swatchRow(name: "expenditure", color: BulkAITheme.Color.expenditure)
                swatchRow(name: "weightTrend", color: BulkAITheme.Color.weightTrend)
                swatchRow(name: "bodyMetrics", color: BulkAITheme.Color.bodyMetrics)
                swatchRow(name: "activity", color: BulkAITheme.Color.activity)
                swatchRow(name: "accent", color: BulkAITheme.Color.accent)
            }

            VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
                Text("Typography")
                    .font(BulkAITheme.Typography.headline)
                    .foregroundStyle(.white.opacity(0.8))

                Text("Display 40").font(BulkAITheme.Typography.display).foregroundStyle(.white)
                Text("Title 28").font(BulkAITheme.Typography.title).foregroundStyle(.white)
                Text("Title3 20").font(BulkAITheme.Typography.title3).foregroundStyle(.white)
                Text("Headline 17").font(BulkAITheme.Typography.headline).foregroundStyle(.white)
                Text("Body 15").font(BulkAITheme.Typography.body).foregroundStyle(.white)
                Text("Caption 13").font(BulkAITheme.Typography.caption).foregroundStyle(.white)
                Text("Caption2 11").font(BulkAITheme.Typography.caption2).foregroundStyle(.white)
            }
        }
        .padding(BulkAITheme.Spacing.lg)
    }
    .background(BulkAITheme.Color.background)
}

@ViewBuilder
private func swatchRow(name: String, color: Color) -> some View {
    HStack(spacing: BulkAITheme.Spacing.sm) {
        RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm)
            .fill(color)
            .frame(width: 36, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: BulkAITheme.Radius.sm)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            )
        Text(name)
            .font(BulkAITheme.Typography.body)
            .foregroundStyle(.white.opacity(0.9))
    }
}
