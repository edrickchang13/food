import Foundation
import SwiftData

extension Notification.Name {
    static let favoritesDidChange = Notification.Name("favoritesDidChange")
}

/// Persists the user's favorited food item IDs across sessions.
///
/// Backend: SwiftData (`FavoriteModel` via `BulkAISchemaV1`). Migrated from
/// the legacy `"foodFavorites"` UserDefaults JSON blob on first launch by
/// `SwiftDataMigration.runIfNeeded(into:)`.
///
/// Maintains an in-memory `sortedIDs` array (newest-first) for O(n) iteration
/// and a private `Set` for O(1) `contains` checks. Both stay in sync with the
/// SwiftData store via `rebuild()` after every mutation.
///
/// Public API is byte-for-byte identical to the prior UserDefaults
/// implementation so all callers need zero changes.
@Observable
@MainActor
final class FavoritesStore {

    // MARK: - Private storage

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// O(1) membership test; derived from SwiftData on load, kept in sync on mutation.
    private var _favoriteSet: Set<String> = []

    // MARK: - Public API

    /// Favorite IDs in most-recent-first order. Observed by SwiftUI views.
    private(set) var sortedIDs: [String] = []

    /// The set of favorited IDs. Read-only external access.
    var favorites: Set<String> { _favoriteSet }

    // MARK: - Init

    /// Creates the store backed by `container`. The default argument constructs
    /// a production CloudKit container — unit tests may pass an in-memory
    /// container via `SwiftDataContainer.makePreviewContainer()`.
    init(container: ModelContainer = SwiftDataContainer.makeContainer()) {
        self.container = container
        if SwiftDataMigration.hasMigrated == false {
            _ = SwiftDataMigration.runIfNeeded(into: container)
        }
        rebuild()
    }

    // MARK: - Public mutations

    /// Returns `true` when `id` is currently favorited.
    func contains(_ id: String) -> Bool {
        _favoriteSet.contains(id)
    }

    /// Adds `id` if absent; removes it if already present.
    func toggle(_ id: String) {
        contains(id) ? remove(id) : add(id)
    }

    /// Adds `id` to the favorites list. No-op if already present.
    func add(_ id: String) {
        guard !contains(id) else { return }
        let model = FavoriteModel(id: id, addedAt: .now)
        context.insert(model)
        try? context.save()
        rebuild()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    /// Removes `id` from the favorites list. No-op if absent.
    func remove(_ id: String) {
        guard contains(id) else { return }
        let descriptor = FetchDescriptor<FavoriteModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try? context.fetch(descriptor).first {
            context.delete(model)
            try? context.save()
        }
        rebuild()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    // MARK: - Private

    /// Reloads `sortedIDs` and `_favoriteSet` from SwiftData (newest first).
    private func rebuild() {
        var descriptor = FetchDescriptor<FavoriteModel>()
        descriptor.sortBy = [SortDescriptor(\.addedAt, order: .reverse)]
        let models = (try? context.fetch(descriptor)) ?? []
        sortedIDs = models.map(\.id)
        _favoriteSet = Set(sortedIDs)
    }
}
