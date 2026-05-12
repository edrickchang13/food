import Foundation
import SwiftUI
import UIKit

/// Stores progress photo image data on disk under Documents/ProgressPhotos/ with
/// FileProtectionType.complete, so the files are encrypted at rest when the device
/// is locked. Metadata (date, side, weight at time, notes) lives in UserDefaults.
@Observable
final class ProgressPhotoStore {
    private(set) var photos: [ProgressPhoto] = []
    private let metadataKey = "progressPhotos"
    private let photosDirectoryName = "ProgressPhotos"

    init() {
        ensureDirectoryExists()
        load()
    }

    var sortedNewestFirst: [ProgressPhoto] {
        photos.sorted { $0.date > $1.date }
    }

    func photos(for side: ProgressPhotoSide) -> [ProgressPhoto] {
        sortedNewestFirst.filter { $0.side == side }
    }

    /// Reads the image bytes off disk. Returns nil if the file is missing or unreadable.
    func loadImage(for photo: ProgressPhoto) -> UIImage? {
        let url = fileURL(for: photo.filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Writes the JPEG-encoded data to disk with at-rest encryption, then appends
    /// the metadata entry. Returns the stored photo or nil if the write failed.
    @discardableResult
    func add(
        imageData: Data,
        side: ProgressPhotoSide,
        date: Date = .now,
        weightKgAtTime: Double? = nil,
        notes: String? = nil
    ) -> ProgressPhoto? {
        let filename = "\(UUID().uuidString).jpg"
        let url = fileURL(for: filename)
        do {
            try imageData.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            return nil
        }
        let photo = ProgressPhoto(
            date: date,
            side: side,
            filename: filename,
            weightKgAtTime: weightKgAtTime,
            notes: notes
        )
        photos.append(photo)
        save()
        return photo
    }

    func delete(_ photo: ProgressPhoto) {
        let url = fileURL(for: photo.filename)
        try? FileManager.default.removeItem(at: url)
        photos.removeAll { $0.id == photo.id }
        save()
    }

    // MARK: - Disk

    private var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(photosDirectoryName, isDirectory: true)
    }

    private func fileURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    private func ensureDirectoryExists() {
        let dir = photosDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let decoded = try? JSONDecoder().decode([ProgressPhoto].self, from: data)
        else { return }
        photos = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }
}
