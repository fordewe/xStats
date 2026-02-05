import SwiftUI

struct MemoryPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentPurple)

                Text("Memory")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // Total memory badge
                Text(collector.currentStats.memory.total.formattedBytes())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }

            // Dual circular gauges
            HStack(spacing: 14) {
                // Usage gauge
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .stroke(Theme.background.opacity(0.5), lineWidth: 5)

                        Circle()
                            .trim(from: 0, to: collector.currentStats.memory.usagePercentage / 100)
                            .stroke(
                                AngularGradient(
                                    colors: [Theme.accentPurple, Theme.accentPink],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Theme.accentPurple.opacity(0.4), radius: 3)

                        Text("\(Int(collector.currentStats.memory.usagePercentage))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .frame(width: 54, height: 54)

                    Text("Used")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Pressure gauge
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .stroke(Theme.background.opacity(0.5), lineWidth: 5)

                        Circle()
                            .trim(from: 0, to: pressurePercentage / 100)
                            .stroke(
                                pressureColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: pressureColor.opacity(0.4), radius: 3)

                        Text(pressureLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(pressureColor)
                    }
                    .frame(width: 54, height: 54)

                    Text("Pressure")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().background(Theme.divider)

            // Memory breakdown - compact list without progress bars
            VStack(alignment: .leading, spacing: 4) {
                MemoryBreakdownItemCompact(
                    label: "App Memory",
                    value: collector.currentStats.memory.active,
                    color: Theme.accentBlue
                )

                MemoryBreakdownItemCompact(
                    label: "Wired",
                    value: collector.currentStats.memory.wired,
                    color: Theme.accentRed
                )

                MemoryBreakdownItemCompact(
                    label: "Compressed",
                    value: collector.currentStats.memory.compression,
                    color: Theme.accentYellow
                )

                MemoryBreakdownItemCompact(
                    label: "Free",
                    value: collector.currentStats.memory.free,
                    color: Theme.accentGreen
                )

                // Swap inline
                if collector.currentStats.memory.swapUsed > 0 {
                    MemoryBreakdownItemCompact(
                        label: "Swap",
                        value: collector.currentStats.memory.swapUsed,
                        color: Theme.accentOrange
                    )
                }
            }

            Spacer()

            // History graph
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(Theme.detailFont)
                    .foregroundColor(Theme.textSecondary)

                MemoryHistoryGraph(values: collector.getMemoryHistory())
            }
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }

    private var pressureColor: Color {
        switch collector.currentStats.memory.pressure {
        case .critical: return Theme.accentRed
        case .warning: return Theme.accentYellow
        case .normal: return Theme.accentGreen
        }
    }

    private var pressurePercentage: Double {
        switch collector.currentStats.memory.pressure {
        case .critical: return 95
        case .warning: return 65
        case .normal: return 25
        }
    }

    private var pressureLabel: String {
        switch collector.currentStats.memory.pressure {
        case .critical: return "High"
        case .warning: return "Med"
        case .normal: return "Low"
        }
    }
}

// Compact version without progress bar
struct MemoryBreakdownItemCompact: View {
    let label: String
    let value: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(Theme.detailFont)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value.formattedBytes())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// Memory History graph with gradient fill
struct MemoryHistoryGraph: View {
    let values: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxVal: Double = 100 // Memory is always 0-100%
            
            ZStack {
                // Fill
                Path { path in
                    guard !values.isEmpty else { return }
                    let stepX = width / CGFloat(max(values.count - 1, 1))
                    
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(value) / CGFloat(maxVal) * height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(Theme.memoryGradient)
                
                // Line
                Path { path in
                    guard !values.isEmpty else { return }
                    let stepX = width / CGFloat(max(values.count - 1, 1))

                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(value) / CGFloat(maxVal) * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(colors: [Theme.accentPurple, Theme.accentPink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }
        }
        .frame(height: 45)
        .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius)
                .fill(Theme.background.opacity(0.3))
        )
    }
}

#Preview {
    MemoryPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
