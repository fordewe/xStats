import SwiftUI

struct GPUPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    private var gpu: GPUStats? {
        collector.currentStats.gpu
    }

    private var usage: Double {
        min(max(gpu?.usage ?? 0, 0), 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentCyan)

                Text("GPU")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                if let temp = gpu?.temperature, temp > 0 {
                    Text("\(Int(temp))°")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(tempColor(temp))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tempColor(temp).opacity(0.15))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Theme.background.opacity(0.5), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: usage / 100)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.accentCyan, Theme.accentBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(usage))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 6) {
                    infoRow(label: "Utilization", value: "\(Int(usage))%")
                    infoRow(label: "Temp", value: formattedTemp)
                    infoRow(label: "Memory", value: formattedMemory)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Theme.divider)

            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(Theme.detailFont)
                    .foregroundColor(Theme.textSecondary)

                GradientGraph(data: collector.getGpuHistory(), color: Theme.accentCyan)
                    .frame(height: 70)
                    .background(Theme.background.opacity(0.35))
                    .cornerRadius(5)
            }

            Spacer()
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.detailFont)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var formattedTemp: String {
        guard let temp = gpu?.temperature, temp > 0 else { return "--" }
        return "\(Int(temp))°C"
    }

    private var formattedMemory: String {
        guard let used = gpu?.memoryUsed else { return "--" }
        if let total = gpu?.memoryTotal, total > 0 {
            return "\(used.formattedBytes()) / \(total.formattedBytes())"
        }
        return used.formattedBytes()
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return Theme.accentRed }
        if temp > 75 { return Theme.accentOrange }
        if temp > 60 { return Theme.accentYellow }
        return Theme.accentGreen
    }
}

#Preview {
    GPUPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
