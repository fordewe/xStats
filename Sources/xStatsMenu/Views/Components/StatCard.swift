import SwiftUI

struct StatCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content

    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 24)

                Text(title)
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            content
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cardRadius)
    }
}
