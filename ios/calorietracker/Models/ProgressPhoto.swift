import Foundation

enum ProgressPhotoSide: String, Codable, CaseIterable, Identifiable {
    case front, back, sideLeft, sideRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .front: "Front"
        case .back: "Back"
        case .sideLeft: "Left side"
        case .sideRight: "Right side"
        }
    }
}

struct ProgressPhoto: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let side: ProgressPhotoSide
    /// Filename within the per-user photos directory. The directory itself is
    /// managed by ProgressPhotoStore so the file can move between devices via
    /// CloudKit sync without breaking the path.
    let filename: String
    let weightKgAtTime: Double?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        side: ProgressPhotoSide,
        filename: String,
        weightKgAtTime: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.side = side
        self.filename = filename
        self.weightKgAtTime = weightKgAtTime
        self.notes = notes
    }
}
