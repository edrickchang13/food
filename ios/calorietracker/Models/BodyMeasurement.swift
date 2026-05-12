import Foundation

/// One axis of body measurement (e.g., biceps_left, waist). PRD specifies up to 24
/// distinct measurements; we ship a curated default set and let users add custom names.
enum BodyMeasurementSite: String, Codable, CaseIterable, Identifiable {
    case neck
    case shoulders
    case chest
    case upperArmLeft
    case upperArmRight
    case forearmLeft
    case forearmRight
    case waist
    case hips
    case thighLeft
    case thighRight
    case calfLeft
    case calfRight
    case wrist
    case ankle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neck: "Neck"
        case .shoulders: "Shoulders"
        case .chest: "Chest"
        case .upperArmLeft: "Left upper arm"
        case .upperArmRight: "Right upper arm"
        case .forearmLeft: "Left forearm"
        case .forearmRight: "Right forearm"
        case .waist: "Waist"
        case .hips: "Hips"
        case .thighLeft: "Left thigh"
        case .thighRight: "Right thigh"
        case .calfLeft: "Left calf"
        case .calfRight: "Right calf"
        case .wrist: "Wrist"
        case .ankle: "Ankle"
        }
    }

    var icon: String {
        switch self {
        case .neck, .shoulders, .chest: "figure.arms.open"
        case .upperArmLeft, .upperArmRight, .forearmLeft, .forearmRight, .wrist:
            "figure.strengthtraining.traditional"
        case .waist, .hips: "figure.stand"
        case .thighLeft, .thighRight, .calfLeft, .calfRight, .ankle: "figure.walk"
        }
    }
}

struct BodyMeasurementEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let site: BodyMeasurementSite
    /// Always stored in centimeters; converted at display time.
    var valueCm: Double
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        site: BodyMeasurementSite,
        valueCm: Double,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.site = site
        self.valueCm = valueCm
        self.note = note
    }

    var valueInches: Double { valueCm / 2.54 }
}
