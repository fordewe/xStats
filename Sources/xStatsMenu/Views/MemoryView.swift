import SwiftUI

struct MemoryView: View {
    let stats: SystemStats

    var body: some View {
        StatCard(icon: "memorychip", title: "Memory", color: Theme.accentPurple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(stats.memory.usagePercentage))%")
                            .font(Theme.valueFont)
                            .foregroundColor(Theme.textPrimary)

                        Text("\(Double(stats.memory.used).formattedBytes()) of \(Double(stats.memory.total).formattedBytes())")
                            .font(Theme.labelFont)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    CircularProgress(
                        percentage: stats.memory.usagePercentage / 100,
                        color: colorForPressure(stats.memory.pressure)
                    )
                    .frame(width: 60, height: 60)
                }

                // Memory breakdown
                VStack(alignment: .leading, spacing: 6) {
                    MemoryRow(label: "App", value: stats.memory.active, color: Theme.accentBlue)
                    MemoryRow(label: "Wired", value: stats.memory.wired, color: Theme.accentRed)
                    MemoryRow(label: "Compressed", value: stats.memory.compression, color: Theme.accentYellow)
                    MemoryRow(label: "Free", value: stats.memory.free, color: Theme.accentGreen)
                }

                // Swap info
                if stats.memory.swapTotal > 0 {
                    HStack {
                        Text("Swap Used:")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Text("\(Double(stats.memory.swapUsed).formattedBytes())")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private func colorForPressure(_ pressure: MemoryStats.MemoryPressure) -> Color {
        switch pressure {
        case .critical:
            return Theme.accentRed
        case .warning:
            return Theme.accentYellow
        case .normal:
            return Theme.accentGreen
        }
    }
}

struct MemoryRow: View {
    let label: String
    let value: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(Theme.detailFont)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(Double(value).formattedBytes())
                .font(Theme.detailFont)
                .foregroundColor(Theme.textPrimary)
        }
    }
}

