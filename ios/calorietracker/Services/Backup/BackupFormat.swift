import Foundation

/// The on-disk shape of a backup file.
///
/// A backup is one UTF-8 text file with one JSON record per line, so it can be
/// written and read as a stream. Photos are base64 inside their own lines, which
/// keeps a two-year library from ever sitting in memory at once.
///
///     {"t":"header","r":{...}}      always first
///     {"t":"food","r":{...}}        one line per row, any order
///     {"t":"image","r":{...}}       one line per photo
///     {"t":"manifest","r":{...}}    always last, carries counts and a SHA-256
///
/// The SHA-256 covers every byte before the manifest line, so a truncated or
/// altered file is rejected before anything is written. Record types a reader
/// does not know are skipped, which lets later versions add types additively.
/// Dates use `JSONEncoder`'s default (seconds since 2001-01-01) for exact values.
nonisolated enum BackupFormat {
    static let name = "bulkai-backup"
    static let schemaVersion = 1
    static let fileExtension = "bulkaibackup"
}

// MARK: - Data types

/// Every kind of thing a backup counts. Raw values are the manifest's count keys
/// and must never change.
nonisolated enum BackupDataType: String, Codable, CaseIterable, Identifiable, Sendable {
    case foodEntries
    case weightEntries
    case bodyFatEntries
    case favorites
    case profile
    case periods
    case recipes
    case measurements
    case chatMessages
    case savedFoods
    case progressPhotos
    case aiFoodCache
    case settings
    case foodImageFiles
    case progressPhotoFiles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foodEntries: "Food log entries"
        case .weightEntries: "Weight entries"
        case .bodyFatEntries: "Body fat entries"
        case .favorites: "Favorite foods"
        case .profile: "Profile"
        case .periods: "Cycle entries"
        case .recipes: "Recipes"
        case .measurements: "Body measurements"
        case .chatMessages: "Coach messages"
        case .savedFoods: "Saved food log favorites"
        case .progressPhotos: "Progress photo details"
        case .aiFoodCache: "Remembered foods"
        case .settings: "Settings"
        case .foodImageFiles: "Food photos"
        case .progressPhotoFiles: "Progress photos"
        }
    }
}

// MARK: - Header and manifest

nonisolated struct BackupHeader: Codable, Equatable, Sendable {
    var format: String
    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var appBuild: String

    static func current(createdAt: Date = .now, bundle: Bundle = .main) -> BackupHeader {
        BackupHeader(
            format: BackupFormat.name,
            schemaVersion: BackupFormat.schemaVersion,
            createdAt: createdAt,
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        )
    }
}

nonisolated struct BackupManifest: Codable, Equatable, Sendable {
    /// Keyed by `BackupDataType.rawValue`. Later versions may add keys.
    var counts: [String: Int]
    /// Photos a row points at whose file was already gone on this device.
    var missingImages: [String]
    /// Rows that could not be read per storage key. They survive verbatim in the
    /// file's raw copies.
    var undecodableRows: [String: Int]
    /// Rows found only in the pre-SwiftData copies per storage key. Usually
    /// things the user deleted, so they stay in the raw copies and are not restored.
    var legacyOnlyRows: [String: Int]
    /// Lowercase hex SHA-256 of every byte before this manifest's line.
    var sha256: String

    func count(of type: BackupDataType) -> Int { counts[type.rawValue] ?? 0 }
}

// MARK: - Progress

nonisolated struct BackupProgress: Sendable, Equatable {
    var message: String
    /// 0...1, or nil while the amount of work is unknown.
    var fraction: Double?
}

// MARK: - Errors

nonisolated enum BackupError: LocalizedError, Equatable, Sendable {
    case notABackup
    case newerVersion(Int)
    case incomplete
    case damaged(String)
    case unsafeFilename(String)
    case countMismatch(BackupDataType, expected: Int, found: Int)
    case imageUnreadable(String)
    case storeUnreadable(String)
    case notEnoughSpace(neededBytes: Int64, availableBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .notABackup:
            "This file is not a Bulk AI backup."
        case .newerVersion(let version):
            "This backup uses format \(version), which this version of the app cannot read. Update the app and try again."
        case .incomplete:
            "This backup file is incomplete. It may not have finished saving or copying."
        case .damaged(let detail):
            "This backup file is damaged (\(detail))."
        case .unsafeFilename(let name):
            "This backup contains an invalid file name: \(name)."
        case .countMismatch(let type, let expected, let found):
            "\(type.displayName): the file lists \(expected) but contains \(found)."
        case .imageUnreadable(let name):
            "Could not read the photo \(name). Keep the phone unlocked during a backup and try again."
        case .storeUnreadable(let detail):
            "Could not read your data (\(detail))."
        case .notEnoughSpace(let needed, let available):
            "Not enough free space. Needed: \(Self.size(needed)). Available: \(Self.size(available))."
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Filenames

nonisolated enum BackupFilename {
    /// A stored photo name must be a bare filename. Anything that could walk out
    /// of the photo folder is rejected, because backup files come from outside the app.
    static func isSafe(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= 255
            && !name.hasPrefix(".")
            && !name.contains("/")
            && !name.contains("\\")
            && !name.contains("\0")
    }
}
