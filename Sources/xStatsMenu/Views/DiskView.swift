import SwiftUI

struct DiskView: View {
    let stats: SystemStats

    var body: some View {
        StatCard(icon: "internaldrive", title: "Disk", color: Theme.accentPurple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(stats.disk.usagePercentage))%")
                            .font(Theme.valueFont)
                            .foregroundColor(Theme.textPrimary)

                        Text("\(Double(stats.disk.used).formattedBytes()) of \(Double(stats.disk.total).formattedBytes())")
                            .font(Theme.labelFont)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    CircularProgress(
                        percentage: stats.disk.usagePercentage / 100,
                        color: colorForUsage(stats.disk.usagePercentage)
                    )
                    .frame(width: 60, height: 60)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.cardBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForUsage(stats.disk.usagePercentage))
                            .frame(width: max(0, CGFloat(stats.disk.usagePercentage) / 100 * 300), height: 8)
                    }
                    .frame(width: 300)

                    Text("\(Double(stats.disk.free).formattedBytes()) free")
                        .font(Theme.detailFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Activity indicator
                if stats.disk.readBytes > 0 || stats.disk.writeBytes > 0 {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(Theme.accentBlue)

                        Text("R: \(Double(stats.disk.readBytes).formattedBytes())")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(Theme.accentGreen)

                        Text("W: \(Double(stats.disk.writeBytes).formattedBytes())")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 90 {
            return Theme.accentRed
        } else if usage > 75 {
            return Theme.accentYellow
        } else {
            return Theme.accentPurple
        }
    }
}
