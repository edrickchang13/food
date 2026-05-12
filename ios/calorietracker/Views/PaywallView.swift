import SwiftUI

/// Stub left behind after the P5 strip removed Fud AI Plus. The original view
/// surfaced a RevenueCat paywall for the paid Gemini-proxy subscription; Bulk AI
/// doesn't have a paid tier (users supply their own free Gemini API key), so this
/// is a placeholder that explains the situation and dismisses.
///
/// Anywhere the app used to present `.sheet(isPresented: $showPaywall) { PaywallView() }`
/// still compiles. New code shouldn't reference this; remove the existing call
/// sites in a follow-up.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onPurchase: (() -> Void)?

    init(onPurchase: (() -> Void)? = nil) {
        self.onPurchase = onPurchase
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Bulk AI is free")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Add your own Google Gemini API key in Settings to start logging. Free keys are available at aistudio.google.com/apikey.")
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                Button("Got it") { dismiss() }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
