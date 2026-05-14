import ActivityKit
import Foundation

struct CalorieActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let calories: Int
        public let calorieGoal: Int
        public let protein: Int
        public let proteinGoal: Int
        public let updatedAt: Date

        public init(
            calories: Int,
            calorieGoal: Int,
            protein: Int,
            proteinGoal: Int,
            updatedAt: Date = .now
        ) {
            self.calories = calories
            self.calorieGoal = calorieGoal
            self.protein = protein
            self.proteinGoal = proteinGoal
            self.updatedAt = updatedAt
        }
    }

    /// Static label for the activity — the user sees this in the banner header.
    /// Empty string is acceptable when we just want the dynamic content visible.
    public let title: String

    public init(title: String = "Today's intake") {
        self.title = title
    }
}
