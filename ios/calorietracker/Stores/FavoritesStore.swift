import Foundation

extension Notification.Name {
    static let favoritesDidChange = Notification.Name("favoritesDidChange")
}

/// Persists the user's favorited food item IDs across sessions.
///
/// Internally maintains two parallel structures:
/// - A `Set<String>` for O(1) `contains` checks
/// - An `Array<String>` for insertion-order tracking (newest first)
///
/// The ordered array is persisted to `UserDefaults` as a JSON-encoded array of
/// `FoodDatabaseItem.id` strings. Observers subscribe to
/// `Notification.Name.favoritesDidChange` to react to mutations.
@Observable
final class FavoritesStore {

    // MARK: - Stored properties

    /// O(1) membership test; derived from `_orderedIDs` on load, kept in sync on mutation.
    /// Tracked by Observation so SwiftUI views auto-re-render on toggle.
    private var _favoriteSet: Set<String> = []

    /// Insertion-order list, newest first. Persisted to UserDefaults.
    /// Tracked by Observation so SwiftUI views auto-re-render on toggle.
    private var _orderedIDs: [String] = []

    @ObservationIgnored private let storageKey = "foodFavorites"
    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDisk()
    }

    // MARK: - Public API

    /// The set of favorited IDs. Read-only external access; backed by `_favoriteSet`.
    var favorites: Set<String> { _favoriteSet }

    /// Returns `true` when `id` is currently favorited.
    func contains(_ id: String) -> Bool {
        _favoriteSet.contains(id)
    }

    /// Adds `id` if absent; removes it if already present.
    func toggle(_ id: String) {
        if _favoriteSet.contains(id) {
            remove(id)
        } else {
            add(id)
        }
    }

    /// Adds `id` to the favorites list. No-op if already present.
    func add(_ id: String) {
        guard !_favoriteSet.contains(id) else { return }
        _favoriteSet.insert(id)
        _orderedIDs.insert(id, at: 0)   // prepend — newest first
        saveToDisk()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    /// Removes `id` from the favorites list. No-op if absent.
    func remove(_ id: String) {
        guard _favoriteSet.contains(id) else { return }
        _favoriteSet.remove(id)
        _orderedIDs.removeAll { $0 == id }
        saveToDisk()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    /// Favorite IDs in most-recent-first order.
    var sortedIDs: [String] { _orderedIDs }

    // MARK: - Persistence

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(_orderedIDs) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func loadFromDisk() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        _orderedIDs = decoded
        _favoriteSet = Set(decoded)
    }
}
