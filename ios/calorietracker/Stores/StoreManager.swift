import Foundation
import SwiftUI

/// Stub left behind after the P5 strip removed Fud AI Plus (RevenueCat-backed
/// paid Gemini-proxy subscription). The original StoreManager handled subscription
/// state, entitlements, and purchase flows; Bulk AI doesn't need any of that
/// since it's BYOK Gemini only.
///
/// Kept as an @Observable shell so legacy `@Environment(StoreManager.self)`
/// declarations and `.environment(storeManager)` calls keep compiling. Any code
/// reading `isSubscribed` or similar gets `false`. Once every callsite that
/// references this is removed, this file can go.
@Observable
final class StoreManager {
    var isSubscribed: Bool { false }
    var hasActivePlusEntitlement: Bool { false }
    /// Returned for the legacy "current plan name" label. Bulk AI doesn't have plans.
    var currentPlanName: String { "" }

    init() {}

    func refreshSubscriptionStatus() async { /* no-op */ }
    func checkEntitlements() async { /* no-op */ }
    func purchase() async throws { /* no-op */ }
    func restorePurchases() async throws { /* no-op */ }
}
