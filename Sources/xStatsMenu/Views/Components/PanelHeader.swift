import SwiftUI

struct PanelHeader: View {
    let title: String
    let subtitle: String?
    let icon: String

    init(title: String, subtitle: String? = nil, icon: String) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text(title)
                .font(Theme.titleFont)
                .foregroundColor(Theme.textPrimary)

            if let subtitle = subtitle {
                Spacer()
                Text(subtitle)
                    .font(Theme.detailFont)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(height: 20)
    }
}

#Preview {
    VStack(spacing: 8) {
        PanelHeader(title: "CPU", subtitle: "3.62 GHz", icon: "cpu")
        PanelHeader(title: "Memory", icon: "memorychip")
        PanelHeader(title: "Network", subtitle: "1.2 MB/s", icon: "network")
    }
    .padding()
    .frame(width: 180)
    .background(Theme.cardBackground)
}
