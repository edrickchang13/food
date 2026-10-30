import SwiftData
import SwiftUI
import UIKit

/// The Export half of the backup screen, and on its own the whole UI of the
/// export-only bridge build. Share is offered only after the finished file has
/// passed its read-back check. The screen stays awake while working, because
/// progress photos cannot be read once the phone locks.
struct BackupExportSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isExporting = false
    @State private var progress = BackupProgress(message: "", fraction: nil)
    @State private var result: BackupExportResult?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if isExporting {
                progressRow
            } else {
                Button("Create Backup", systemImage: "externaldrive.badge.plus") {
                    Task { await runExport() }
                }
            }
            if let result, !isExporting {
                BackupExportSummary(result: result)
                ShareLink(item: result.fileURL) {
                    Label("Share Backup File", systemImage: "square.and.arrow.up")
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Creates one file with your logs, body data, recipes, photos, and settings. API keys are not included. The file is not password protected, so keep it somewhere private.")
        }
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xs) {
            Text(progress.message)
                .font(BulkAITheme.Typography.body)
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView()
            }
        }
    }

    private func runExport() async {
        if let url = result?.fileURL { try? FileManager.default.removeItem(at: url) }
        result = nil
        errorMessage = nil
        isExporting = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
            isExporting = false
        }
        do {
            let exporter = BackupExporter(container: modelContext.container)
            result = try await exporter.export { update in
                Task { @MainActor in progress = update }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The export-only screen used by the bridge build. The full app uses `BackupView`.
struct BackupExportScreen: View {
    var body: some View {
        Form {
            BackupExportSection()
        }
        .navigationTitle("Backup")
        .onDisappear { BackupExporter.removeTemporaryFiles() }
    }
}

/// Counts for a finished, verified export.
private struct BackupExportSummary: View {
    let result: BackupExportResult

    private var size: String {
        ByteCountFormatter.string(fromByteCount: result.fileSizeBytes, countStyle: .file)
    }

    private var notes: [String] {
        let manifest = result.contents.manifest
        var notes: [String] = []
        if !manifest.missingImages.isEmpty {
            notes.append("\(manifest.missingImages.count) photos were already missing on this device.")
        }
        let unread = manifest.undecodableRows.values.reduce(0, +)
        if unread > 0 {
            notes.append("\(unread) rows could not be read. Their original copies are stored in the file.")
        }
        let older = manifest.legacyOnlyRows.values.reduce(0, +)
        if older > 0 {
            notes.append("\(older) older rows from before a storage update are stored in the file but will not be restored.")
        }
        return notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BulkAITheme.Spacing.xxs) {
            Text("Backup checked, \(size)")
                .font(BulkAITheme.Typography.headline)
            ForEach(BackupDataType.allCases) { type in
                HStack {
                    Text(type.displayName)
                    Spacer()
                    Text(result.contents.count(of: type), format: .number)
                        .monospacedDigit()
                }
                .font(BulkAITheme.Typography.caption)
            }
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(BulkAITheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
