import Foundation
import HealthKit

/// Reads daily step counts from HealthKit. Stateless — each call creates a local
/// HKHealthStore and executes an independent query. The caller owns caching.
struct StepReader {

    /// Returns step counts for the last 7 calendar days including today, oldest
    /// first, or `nil` if HealthKit is unavailable or stepCount authorization
    /// is not granted.
    static func last7Days() async -> [Int]? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)

        guard
            let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
            let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: .strictStartDate
        )
        var interval = DateComponents()
        interval.day = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: todayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                guard let collection else {
                    continuation.resume(returning: nil)
                    return
                }
                // Walk each day via statistics(for:) so no mutable local is captured
                // by a nested escaping block — Swift 6 clean.
                let cal = Calendar.current
                var counts: [Int] = []
                for dayOffset in 0..<7 {
                    let day = cal.date(byAdding: .day, value: dayOffset, to: windowStart)
                        ?? windowStart
                    let steps = collection.statistics(for: day)
                        .flatMap { $0.sumQuantity() }
                        .map { Int($0.doubleValue(for: .count())) } ?? 0
                    counts.append(steps)
                }
                continuation.resume(returning: counts.isEmpty ? nil : counts)
            }
            store.execute(query)
        }
    }

    /// Returns today's cumulative step count, or `nil` if HealthKit is
    /// unavailable or stepCount authorization is not granted.
    static func today() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfToday,
            end: .now,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }
            store.execute(query)
        }
    }
}
