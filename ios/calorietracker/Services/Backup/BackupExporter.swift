import Foundation
import SwiftData

nonisolated struct BackupExportResult: Equatable, Sendable {
    var fileURL: URL
    var contents: BackupContents
    var fileSizeBytes: Int64
}

/// Produces one verified backup file.
///
/// The file only counts as finished after it has been read back in full through
/// the same validation a restore uses and its counts match what was collected.
/// If that fails the file is deleted, so a bad backup can never reach the share sheet.
@MainActor
struct BackupExporter {
    let container: ModelContainer
    var environment: BackupEnvironment = .live

    func export(
        now: Date = .now,
        progress: @escaping @Sendable (BackupProgress) -> Void = { _ in }
    ) async throws -> BackupExportResult {
        progress(BackupProgress(message: "Reading your data", fraction: nil))
        let payload = try await BackupCollector(container: container, environment: environment).collect()

        let environment = environment
        let url = environment.outputDirectory.appendingPathComponent(Self.filename(for: now))
        let header = BackupHeader.current(createdAt: now)

        return try await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(
                    at: environment.outputDirectory,
                    withIntermediateDirectories: true
                )
                try? FileManager.default.removeItem(at: url)
                _ = try BackupFileComposer.write(
                    payload: payload,
                    header: header,
                    environment: environment,
                    to: url,
                    progress: progress
                )
                progress(BackupProgress(message: "Checking the file", fraction: nil))
                let contents = try BackupFileReader.validate(url: url)
                for type in BackupDataType.allCases where type != .foodImageFiles && type != .progressPhotoFiles {
                    guard contents.count(of: type) == payload.rowCount(of: type) else {
                        throw BackupError.countMismatch(
                            type,
                            expected: payload.rowCount(of: type),
                            found: contents.count(of: type)
                        )
                    }
                }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                return BackupExportResult(fileURL: url, contents: contents, fileSizeBytes: Int64(size))
            } catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }.value
    }

    /// Temp copies hold private data, so screens clear them on the way out. Tied
    /// to the screen, not a Form row, whose `onDisappear` fires on scroll.
    nonisolated static func removeTemporaryFiles(in directory: URL = FileManager.default.temporaryDirectory) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == BackupFormat.fileExtension {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "BulkAI-Backup-\(formatter.string(from: date)).\(BackupFormat.fileExtension)"
    }
}
