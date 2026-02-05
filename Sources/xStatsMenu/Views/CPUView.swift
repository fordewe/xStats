import SwiftUI

struct CPUView: View {
    let stats: SystemStats

    var body: some View {
        StatCard(icon: "cpu", title: "CPU", color: Theme.accentBlue) {
            VStack(alignment: .leading, spacing: 12) {
                // Total usage
                HStack {
                    Text("\(Int(stats.cpu.totalUsage))%")
                        .font(Theme.valueFont)
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("\(stats.cpu.frequency / 1_000_000) MHz")
                        .font(Theme.labelFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Per-core usage
                if !stats.cpu.perCoreUsage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Per Core")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                            ForEach(Array(stats.cpu.perCoreUsage.enumerated()), id: \.offset) { _, usage in
                                VStack(spacing: 2) {
                                    ZStack(alignment: .top) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.cardBackground)
                                            .frame(height: 40)

                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(colorForUsage(usage))
                                            .frame(height: CGFloat(usage) / 100 * 40)
                                    }
                                    .frame(width: 40)

                                    Text("\(Int(usage))%")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }

                // Mini graph
                GradientGraph(
                    data: generateGraphData(),
                    color: Theme.accentBlue
                )
                .frame(height: 60)
            }
        }
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 80 {
            return Theme.accentRed
        } else if usage > 60 {
            return Theme.accentYellow
        } else {
            return Theme.accentBlue
        }
    }

    private func generateGraphData() -> [Double] {
        // Generate synthetic data for visualization
        return (0..<30).map { _ in
            Double.random(in: 10...90)
        }
    }
}
