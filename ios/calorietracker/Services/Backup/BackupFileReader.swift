import CryptoKit
import Foundation

/// A fully validated backup file, minus photo bytes.
nonisolated struct BackupContents: Equatable, Sendable {
    var header: BackupHeader
    var manifest: BackupManifest
    var payload: BackupPayload
    var foodImageNames: Set<String>
    var progressImageNames: Set<String>

    func count(of type: BackupDataType) -> Int {
        switch type {
        case .foodImageFiles: foodImageNames.count
        case .progressPhotoFiles: progressImageNames.count
        default: payload.rowCount(of: type)
        }
    }
}

/// Reads a backup file as a stream and checks the whole thing.
///
/// Both export's self-check and restore go through `validate`, so a file that
/// passes on the old device passes the same code on the new one. Validation
/// writes nothing.
nonisolated enum BackupFileReader {
    private static let chunkSize = 1 << 20

    /// Reads every line, proving the structure and SHA-256 as it goes. Throws as
    /// soon as the file stops being valid.
    static func forEachRecord(in url: URL, _ body: (BackupRecord) throws -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let decoder = JSONDecoder()
        var hasher = SHA256()
        var buffer = Data()
        var lineNumber = 0
        var finished = false

        func consume(_ line: Data) throws {
            lineNumber += 1
            guard !finished else { throw BackupError.damaged("data after the end") }
            let record: BackupRecord
            do {
                record = try decoder.decode(BackupRecord.self, from: line)
            } catch {
                throw lineNumber == 1 ? BackupError.notABackup : BackupError.damaged("line \(lineNumber)")
            }
            if lineNumber == 1 {
                guard case .header(let header) = record, header.format == BackupFormat.name else {
                    throw BackupError.notABackup
                }
                guard header.schemaVersion <= BackupFormat.schemaVersion else {
                    throw BackupError.newerVersion(header.schemaVersion)
                }
            }
            if case .manifest(let manifest) = record {
                guard BackupFileWriter.hex(hasher.finalize()) == manifest.sha256 else {
                    throw BackupError.damaged("checksum does not match")
                }
                finished = true
            } else {
                hasher.update(data: line)
                hasher.update(data: Data([0x0A]))
            }
            try body(record)
        }

        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            buffer.append(chunk)
            var start = buffer.startIndex
            while let newline = buffer[start...].firstIndex(of: 0x0A) {
                let line = Data(buffer[start..<newline])
                try autoreleasepool { try consume(line) }
                start = buffer.index(after: newline)
            }
            buffer = Data(buffer[start...])
        }
        guard buffer.isEmpty, finished else {
            throw lineNumber == 0 && !buffer.isEmpty ? BackupError.notABackup : BackupError.incomplete
        }
    }

    /// Proves the whole file before anything acts on it: structure, checksum,
    /// every row, every photo's base64, every filename, and every count.
    static func validate(url: URL) throws -> BackupContents {
        var header: BackupHeader?
        var manifest: BackupManifest?
        var payload = BackupPayload()
        var foodImages = Set<String>()
        var progressImages = Set<String>()

        try forEachRecord(in: url) { record in
            switch record {
            case .header(let value): header = value
            case .manifest(let value): manifest = value
            case .food(let row): payload.foodEntries.append(row)
            case .weight(let row): payload.weightEntries.append(row)
            case .bodyFat(let row): payload.bodyFatEntries.append(row)
            case .favorite(let row): payload.favorites.append(row)
            case .profile(let row): payload.profile = row
            case .period(let row): payload.periods.append(row)
            case .recipe(let row): payload.recipes.append(row)
            case .measurement(let row): payload.measurements.append(row)
            case .chatMessage(let row): payload.chatMessages.append(row)
            case .savedFood(let row): payload.savedFoods.append(row)
            case .progressPhoto(let row): payload.progressPhotos.append(row)
            case .aiFood(let row): payload.aiFoodCache.append(row)
            case .setting(let row): payload.settings.append(row)
            case .rawBlob(let row): payload.rawBlobs.append(row)
            case .image(let image):
                guard BackupFilename.isSafe(image.filename) else {
                    throw BackupError.unsafeFilename(image.filename)
                }
                if image.kind == .food {
                    foodImages.insert(image.filename)
                } else {
                    progressImages.insert(image.filename)
                }
            case .unknown:
                break
            }
        }

        guard let header, let manifest else { throw BackupError.incomplete }
        payload.undecodableRows = manifest.undecodableRows
        payload.legacyOnlyRows = manifest.legacyOnlyRows
        let contents = BackupContents(
            header: header,
            manifest: manifest,
            payload: payload,
            foodImageNames: foodImages,
            progressImageNames: progressImages
        )
        for type in BackupDataType.allCases {
            guard let expected = manifest.counts[type.rawValue] else {
                throw BackupError.damaged("no count for \(type.rawValue)")
            }
            guard contents.count(of: type) == expected else {
                throw BackupError.countMismatch(type, expected: expected, found: contents.count(of: type))
            }
        }
        for reference in payload.referencedImages where !BackupFilename.isSafe(reference.filename) {
            throw BackupError.unsafeFilename(reference.filename)
        }
        return contents
    }
}
