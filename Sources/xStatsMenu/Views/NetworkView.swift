import SwiftUI

struct NetworkView: View {
    let stats: SystemStats

    var body: some View {
        StatCard(icon: "network", title: "Network", color: Theme.accentGreen) {
            VStack(alignment: .leading, spacing: 12) {
                // Upload
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(Theme.accentBlue)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upload")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Text(stats.network.uploadSpeed.formattedSpeed())
                            .font(Theme.valueFont)
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    Text(Double(stats.network.totalUpload).formattedBytes())
                        .font(Theme.labelFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Download
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(Theme.accentGreen)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Text(stats.network.downloadSpeed.formattedSpeed())
                            .font(Theme.valueFont)
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    Text(Double(stats.network.totalDownload).formattedBytes())
                        .font(Theme.labelFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Graph placeholder
                GradientGraph(
                    data: generateNetworkGraphData(),
                    color: Theme.accentGreen
                )
                .frame(height: 50)
            }
        }
    }

    private func generateNetworkGraphData() -> [Double] {
        // Generate synthetic data
        return (0..<20).map { _ in
            Double.random(in: 0...100)
        }
    }
}
