import CryptoKit
import Foundation

/// Streams records to a backup file while hashing everything it writes.
nonisolated final class BackupFileWriter {
    private let handle: FileHandle
    private let encoder = JSONEncoder()
    private var hasher = SHA256()

    /// `completeUnlessOpen` keeps the bytes encrypted at rest without failing the
    /// write if the phone locks partway through.
    init(url: URL) throws {
        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        guard created else { throw CocoaError(.fileWriteUnknown) }
        handle = try FileHandle(forWritingTo: url)
    }

    func write(_ record: BackupRecord) throws {
        let line = try encoder.encode(record) + [0x0A]
        hasher.update(data: line)
        try handle.write(contentsOf: line)
    }

    /// Writes the manifest as the final line, stamped with the hash of everything
    /// before it, and flushes to disk.
    func finish(_ manifest: BackupManifest) throws -> BackupManifest {
        var manifest = manifest
        manifest.sha256 = Self.hex(hasher.finalize())
        let line = try encoder.encode(BackupRecord.manifest(manifest)) + [0x0A]
        try handle.write(contentsOf: line)
        try handle.synchronize()
        try handle.close()
        return manifest
    }

    static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Lays out a whole backup file: header, rows, photos, raw copies, manifest.
nonisolated enum BackupFileComposer {

    /// Photos are read and written one at a time, so peak memory is one photo
    /// rather than the library. A photo that exists but cannot be read stops the
    /// export, since that means the phone locked rather than the photo being gone.
    static func write(
        payload: BackupPayload,
        header: BackupHeader,
        environment: BackupEnvironment,
        to url: URL,
        progress: @Sendable (BackupProgress) -> Void
    ) throws -> BackupManifest {
        let foodFiles = try environment.imageFiles(in: .food)
        let progressFiles = try environment.imageFiles(in: .progress)
        try checkFreeSpace(for: foodFiles + progressFiles, at: url)

        let writer = try BackupFileWriter(url: url)
        try writer.write(.header(header))
        try writeRows(payload, to: writer)

        let total = foodFiles.count + progressFiles.count
        var written = 0
        for (kind, files) in [(BackupImageKind.food, foodFiles), (.progress, progressFiles)] {
            for file in files {
                try autoreleasepool {
                    guard let data = try? Data(contentsOf: file) else {
                        throw BackupError.imageUnreadable(file.lastPathComponent)
                    }
                    try writer.write(.image(BackupImageV1(kind: kind, filename: file.lastPathComponent, data: data)))
                }
                written += 1
                progress(BackupProgress(message: "Adding photos", fraction: Double(written) / Double(max(total, 1))))
            }
        }
        for blob in payload.rawBlobs { try writer.write(.rawBlob(blob)) }

        var counts: [String: Int] = [:]
        for type in BackupDataType.allCases { counts[type.rawValue] = payload.rowCount(of: type) }
        counts[BackupDataType.foodImageFiles.rawValue] = foodFiles.count
        counts[BackupDataType.progressPhotoFiles.rawValue] = progressFiles.count

        return try writer.finish(BackupManifest(
            counts: counts,
            missingImages: missingImages(payload, foodFiles: foodFiles, progressFiles: progressFiles),
            undecodableRows: payload.undecodableRows,
            legacyOnlyRows: payload.legacyOnlyRows,
            sha256: ""
        ))
    }

    private static func writeRows(_ payload: BackupPayload, to writer: BackupFileWriter) throws {
        for row in payload.foodEntries { try writer.write(.food(row)) }
        for row in payload.weightEntries { try writer.write(.weight(row)) }
        for row in payload.bodyFatEntries { try writer.write(.bodyFat(row)) }
        for row in payload.favorites { try writer.write(.favorite(row)) }
        if let profile = payload.profile { try writer.write(.profile(profile)) }
        for row in payload.periods { try writer.write(.period(row)) }
        for row in payload.recipes { try writer.write(.recipe(row)) }
        for row in payload.measurements { try writer.write(.measurement(row)) }
        for row in payload.chatMessages { try writer.write(.chatMessage(row)) }
        for row in payload.savedFoods { try writer.write(.savedFood(row)) }
        for row in payload.progressPhotos { try writer.write(.progressPhoto(row)) }
        for row in payload.aiFoodCache { try writer.write(.aiFood(row)) }
        for row in payload.settings { try writer.write(.setting(row)) }
    }

    private static func missingImages(
        _ payload: BackupPayload,
        foodFiles: [URL],
        progressFiles: [URL]
    ) -> [String] {
        let food = Set(foodFiles.map(\.lastPathComponent))
        let progress = Set(progressFiles.map(\.lastPathComponent))
        return payload.referencedImages
            .filter { !($0.kind == .food ? food : progress).contains($0.filename) }
            .map(\.filename)
            .sorted()
    }

    /// Base64 adds a third to photo sizes. The cushion covers the rows.
    private static func checkFreeSpace(for files: [URL], at url: URL) throws {
        let photoBytes = try files.reduce(Int64(0)) { sum, file in
            sum + Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        let needed = photoBytes / 3 * 4 + 64 * 1024 * 1024
        let values = try? url.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values?.volumeAvailableCapacityForImportantUsage, available > 0, available < needed {
            throw BackupError.notEnoughSpace(neededBytes: needed, availableBytes: available)
        }
    }
}
