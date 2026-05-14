import SwiftUI

/// Top-level Voice tab for the Food Entry sheet. Wraps the existing
/// `VoiceInputView` (record + transcribe via Apple Speech) and surfaces
/// a callback the parent uses to push the transcript through Gemini.
///
/// Reference layout: matches the AIView "Describe" sub-mode visually —
/// dark canvas, large transcription readout, a Send-to-AI CTA at the
/// bottom. The actual recording UI lives inside VoiceInputView.
struct VoiceView: View {

    /// Called when the user has a finalized transcription and taps "Send
    /// to AI". Parent passes the string through Gemini and stages the
    /// resulting FoodEntry like the AI tab's onDescribe path.
    let onTranscript: (String) -> Void

    var body: some View {
        // VoiceInputView already owns its own dismissal CTAs; we hide its
        // Cancel button by routing onCancel to a no-op so the tab body
        // doesn't try to dismiss the parent sheet from inside a tab.
        VoiceInputView(
            onCancel: { /* tab body — no dismissal */ },
            onSubmit: { transcript in onTranscript(transcript) }
        )
        .background(BulkAITheme.Color.background)
    }
}

#Preview("VoiceView") {
    VoiceView(onTranscript: { _ in })
        .preferredColorScheme(.dark)
        .background(BulkAITheme.Color.background)
}
