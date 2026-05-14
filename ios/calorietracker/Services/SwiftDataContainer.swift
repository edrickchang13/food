import Foundation
import SwiftData

// MARK: - SwiftDataContainer

/// Factory for the app's `ModelContainer`. Call `makeContainer()` once at app
/// startup (from `calorietrackerApp.swift`) and inject the result via
/// `.modelContainer(_:)`. Do not create additional containers — SwiftData
/// serialises writes through a single container context.
///
/// CloudKit note: the container uses `.automatic` database selection, which
/// maps to the first `com.apple.developer.icloud-container-identifiers` entry
/// in the entitlements file. Ensure that entitlement is provisioned in the
/// Apple Developer console before enabling CloudKit sync in TestFlight. Until
/// then, the fallback local-only container is used transparently.
enum SwiftDataContainer {

    // MARK: - Production container

    /// Returns a CloudKit-synced `ModelContainer`. Falls back to a local-only
    /// container when:
    ///   - the user is signed out of iCloud,
    ///   - the CloudKit container ID isn't provisioned yet, or
    ///   - the entitlement is missing from the build.
    ///
    /// The fallback stores data in the same SQLite file path as the CloudKit
    /// variant, so switching between the two (e.g. the user later signs into
    /// iCloud) does not orphan existing records.
    ///
    /// - Returns: A fully initialised `ModelContainer` backed by either
    ///   CloudKit or local persistent storage.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(BulkAISchemaV1.models)

        // Attempt CloudKit-backed storage first.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: BulkAIMigrationPlan.self,
            configurations: cloudConfig
        ) {
            return container
        }

        // Local-only fallback — functionally identical to the CloudKit path
        // minus cross-device sync. Used when CloudKit is unavailable or not
        // yet provisioned. Data is durable and will sync once the entitlement
        // is activated and the user signs into iCloud.
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        // Intentional force-try: if even the local configuration fails the
        // model schema itself is broken, which is a compile-time / developer
        // error and not a recoverable runtime condition. Crashing here gives
        // an immediate, actionable signal during development.
        // swiftlint:disable:next force_try
        return try! ModelContainer(
            for: schema,
            migrationPlan: BulkAIMigrationPlan.self,
            configurations: localConfig
        )
    }

    // MARK: - Preview / test container

    /// In-memory container for SwiftUI Previews and unit tests.
    ///
    /// No migration plan is applied — the schema is always treated as fresh.
    /// Data is discarded when the process exits.
    ///
    /// Usage:
    /// ```swift
    /// #Preview {
    ///     MyView()
    ///         .modelContainer(SwiftDataContainer.makePreviewContainer())
    /// }
    /// ```
    static func makePreviewContainer() -> ModelContainer {
        let schema = Schema(BulkAISchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: config)
    }
}
