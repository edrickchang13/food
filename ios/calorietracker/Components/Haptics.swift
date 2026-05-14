import UIKit
import SwiftUI

/// Tiny façade over `UIImpactFeedbackGenerator` so SwiftUI views don't have to
/// import UIKit or worry about generator lifetime. Each call fires once; the
/// generator is short-lived (constructed-and-discarded inside the call) which
/// is the documented pattern for one-shot taps in Apple's HIG.
///
/// Use:
/// ```swift
/// Haptics.light()
/// Haptics.medium()
/// Haptics.success()
/// ```
///
/// All three are `@MainActor` because `UIImpactFeedbackGenerator` is documented
/// to be called on the main thread.
@MainActor
enum Haptics {

    /// Subtle tap — good for affirming a toggle or small state change.
    static func light() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Medium tap — primary CTA confirmations like committing a staged log
    /// or accepting an engine proposal.
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Notification-style success chime — paired with the check-in accept so
    /// the user feels the commit beyond the medium impact.
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
