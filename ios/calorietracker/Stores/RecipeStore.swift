import Foundation
import SwiftUI

@Observable
final class RecipeStore {
    private(set) var recipes: [Recipe] = []
    private let storageKey = "userRecipes"

    init() {
        load()
    }

    var sortedRecipes: [Recipe] {
        recipes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func add(_ recipe: Recipe) {
        recipes.append(recipe)
        save()
    }

    func update(_ recipe: Recipe) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[idx] = recipe
        save()
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data)
        else { return }
        recipes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
