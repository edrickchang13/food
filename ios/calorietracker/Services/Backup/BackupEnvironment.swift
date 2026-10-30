import Foundation

/// Where backup code reads and writes outside SwiftData. Injected so tests run
/// against temporary folders and a private defaults suite. The paths mirror
/// `FoodImageStore` and `ProgressPhotoStore`, which keep theirs private.
nonisolated struct BackupEnvironment: @unchecked Sendable {
    var defaults: UserDefaults
    var foodImagesDirectory: URL
    var progressPhotosDirectory: URL
    var outputDirectory: URL

    static var live: BackupEnvironment {
        let manager = FileManager.default
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return BackupEnvironment(
            defaults: .standard,
            foodImagesDirectory: support.appendingPathComponent("fudai-food-images", isDirectory: true),
            progressPhotosDirectory: documents.appendingPathComponent("ProgressPhotos", isDirectory: true),
            outputDirectory: manager.temporaryDirectory
        )
    }

    func directory(for kind: BackupImageKind) -> URL {
        kind == .food ? foodImagesDirectory : progressPhotosDirectory
    }

    /// Visible regular files in a photo folder. A missing folder is an empty list.
    func imageFiles(in kind: BackupImageKind) throws -> [URL] {
        let directory = directory(for: kind)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return try files
            .filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
