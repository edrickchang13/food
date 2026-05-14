import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?
    var message: String = "Analyzing your food..."

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            } else {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(BulkAITheme.Color.accent)
                    .frame(maxWidth: 250, maxHeight: 250)
            }

            ProgressView()
                .controlSize(.large)
                .tint(BulkAITheme.Color.accent)

            Text(message)
                .font(.headline)
                .foregroundStyle(BulkAITheme.Color.accent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
