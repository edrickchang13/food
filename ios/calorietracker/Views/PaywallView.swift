import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: PlusProduct?
    @State private var didNotifySubscription = false

    var onSubscribed: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xFF375F), Color(hex: 0x8B2942)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("Unlock Premium")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("No API key needed.\nAI food scans, voice logging, and Coach run through Bulk AI Plus.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Plan cards
            VStack(spacing: 12) {
                if let yearly = storeManager.yearlyProduct {
                    paywallCard(
                        product: yearly,
                        title: "Yearly",
                        badge: "Best Value",
                        detail: yearly.detail
                    )
                }

                if let monthly = storeManager.monthlyProduct {
                    paywallCard(
                        product: monthly,
                        title: "Monthly",
                        badge: nil,
                        detail: monthly.detail
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    featureRow("Uses Bulk AI's Gemini models with automatic fallback")
                    featureRow("\(AIAccessSettings.paidFoodDailyRequestLimit) food logs, \(AIAccessSettings.paidSpeechDailyRequestLimit) voice transcriptions/day")
                    featureRow("\(AIAccessSettings.paidCoachDailyRequestLimit) Coach messages/day")
                    featureRow("Switch back to BYOK anytime")
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Subscribe button
            Button {
                guard let product = selectedProduct else { return }
                Task {
                    if await storeManager.purchase(product) {
                        handleSubscribed()
                    }
                }
            } label: {
                Group {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Text("Subscribe")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                }
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.primary, in: Capsule())
            }
            .padding(.horizontal, 24)
            .disabled(selectedProduct == nil || storeManager.isPurchasing)

            // Error
            if let error = storeManager.purchaseError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
            }

            // Restore + legal
            VStack(spacing: 8) {
                Button("Restore Purchases") {
                    Task {
                        if await storeManager.restorePurchases() {
                            handleSubscribed()
                        }
                    }
                }
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

                Text("No Commitment \u{2022} Cancel Anytime")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(AppColors.appBackground)
        .onAppear {
            selectDefaultProductIfNeeded()
        }
        .task {
            await storeManager.loadProducts()
            selectDefaultProductIfNeeded()
        }
        .onChange(of: storeManager.products.map(\.id)) { _, _ in
            selectDefaultProductIfNeeded()
        }
        .onChange(of: storeManager.isSubscribed) { _, isSubscribed in
            if isSubscribed { handleSubscribed() }
        }
    }

    private func handleSubscribed() {
        guard !didNotifySubscription else { return }
        didNotifySubscription = true
        onSubscribed?()
        dismiss()
    }

    private func selectDefaultProductIfNeeded() {
        if let selectedProduct,
           storeManager.products.contains(where: { $0.id == selectedProduct.id }) {
            return
        }
        selectedProduct = storeManager.yearlyProduct ?? storeManager.monthlyProduct
    }

    private func paywallCard(product: PlusProduct, title: String, badge: String?, detail: String) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button {
            withAnimation(.spring(response: 0.3)) { selectedProduct = product }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let badge {
                        Text(badge)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: AppColors.calorieGradient, startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.3))
                    .padding(.leading, 8)
            }
            .padding(16)
            .background(AppColors.appCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.calorie)
            Text(text)
            Spacer(minLength: 0)
        }
    }
}
