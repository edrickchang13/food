import SwiftUI
import UIKit

enum AppThemeColor: String, CaseIterable, Identifiable {
    case fudPink
    case red
    case orange
    case green
    case mint
    case teal
    case blue
    case purple

    static let storageKey = "appThemeColor"
    static let defaultColor: AppThemeColor = .fudPink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fudPink: return "Bulk Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .green: return "Green"
        case .mint: return "Mint"
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }

    var color: Color {
        Color(hex: startHex)
    }

    var gradientColors: [Color] {
        [Color(hex: startHex), Color(hex: endHex)]
    }

    var alternateIconName: String? {
        switch self {
        case .fudPink: return nil
        case .red: return "AppIconRed"
        case .orange: return "AppIconOrange"
        case .green: return "AppIconGreen"
        case .mint: return "AppIconMint"
        case .teal: return "AppIconTeal"
        case .blue: return "AppIconBlue"
        case .purple: return "AppIconPurple"
        }
    }

    static var current: AppThemeColor {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let themeColor = AppThemeColor(rawValue: rawValue) else {
            return defaultColor
        }
        return themeColor
    }

    static func color(for rawValue: String) -> AppThemeColor {
        AppThemeColor(rawValue: rawValue) ?? defaultColor
    }

    @MainActor
    static func applyAppIconIfNeeded(for themeColor: AppThemeColor) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons,
              application.alternateIconName != themeColor.alternateIconName else {
            return
        }

        application.setAlternateIconName(themeColor.alternateIconName)
    }

    private var startHex: UInt {
        switch self {
        case .fudPink: return 0xFF375F
        case .red: return 0xFF3B30
        case .orange: return 0xFF9500
        case .green: return 0x34C759
        case .mint: return 0x00C7BE
        case .teal: return 0x30B0C7
        case .blue: return 0x0A84FF
        case .purple: return 0xAF52DE
        }
    }

    private var endHex: UInt {
        switch self {
        case .fudPink: return 0xFF6B8A
        case .red: return 0xFF6961
        case .orange: return 0xFFB340
        case .green: return 0x62D46F
        case .mint: return 0x66D4CF
        case .teal: return 0x64D2FF
        case .blue: return 0x5EAEFF
        case .purple: return 0xBF5AF2
        }
    }
}

enum AppColors {
    // Calorie: Red → Pink
    static var calorieGradient: [Color] { AppThemeColor.current.gradientColors }
    static var calorie: Color { AppThemeColor.current.color }

    // Protein
    static var proteinGradient: [Color] { calorieGradient }
    static var protein: Color { calorie }

    // Carbs
    static var carbsGradient: [Color] { calorieGradient }
    static var carbs: Color { calorie }

    // Fat
    static var fatGradient: [Color] { calorieGradient }
    static var fat: Color { calorie }

    // Background: warm cream in light, system dark in dark
    static let appBackground = Color("appBackground")
    static let appCard = Color("appCard")
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
