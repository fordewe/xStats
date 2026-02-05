import SwiftUI

struct CPUPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with frequency and temperature
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentCyan)
                
                Text("CPU")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Frequency badge
                if collector.currentStats.cpu.frequency > 0 {
                    Text(String(format: "%.2f GHz", Double(collector.currentStats.cpu.frequency) / 1_000_000_000))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.accentCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accentCyan.opacity(0.15))
                        .cornerRadius(4)
                }
                
                // Temperature badge
                if let temp = collector.currentStats.cpu.temperature, temp > 0 {
                    Text("\(Int(temp))°")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(tempColor(temp))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tempColor(temp).opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Main circular chart with legend
            HStack(spacing: 16) {
                UserSystemCircularChart(
                    userUsage: collector.currentStats.cpu.userUsage,
                    systemUsage: collector.currentStats.cpu.systemUsage
                )

                VStack(alignment: .leading, spacing: 6) {
                    // User usage
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.accentBlue, Theme.accentCyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 10, height: 4)
                        Text("Usr")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(collector.currentStats.cpu.userUsage))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // System usage
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.accentRed, Theme.accentOrange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 10, height: 4)
                        Text("Sys")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(collector.currentStats.cpu.systemUsage))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    // Idle
                    let idle = max(0, 100 - collector.currentStats.cpu.userUsage - collector.currentStats.cpu.systemUsage)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.textTertiary)
                            .frame(width: 10, height: 4)
                        Text("Idl")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(idle))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            Divider().background(Theme.divider)

            // E/P cores (if available on Apple Silicon)
            if let eCores = collector.currentStats.cpu.efficiencyCoreUsage,
               let pCores = collector.currentStats.cpu.performanceCoreUsage {
                VStack(spacing: 8) {
                    CoreBarView(label: "Efficiency", usage: eCores, color: Theme.accentGreen)
                    CoreBarView(label: "Performance", usage: pCores, color: Theme.accentPurple)
                }
            } else {
                // Show per-core mini bars
                if !collector.currentStats.cpu.perCoreUsage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cores")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
                            ForEach(0..<min(collector.currentStats.cpu.perCoreUsage.count, 8), id: \.self) { i in
                                CoreMiniBar(usage: collector.currentStats.cpu.perCoreUsage[i])
                            }
                        }
                    }
                }
            }

            Spacer()

            // History graph
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(Theme.detailFont)
                    .foregroundColor(Theme.textSecondary)
                
                CPUHistoryGraph(values: collector.getCpuHistory())
            }
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }
    
    private func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return Theme.accentRed }
        if temp > 70 { return Theme.accentOrange }
        if temp > 50 { return Theme.accentYellow }
        return Theme.accentGreen
    }
}

// Mini bar for individual core
struct CoreMiniBar: View {
    let usage: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.background)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: geo.size.height * (usage / 100))
            }
        }
        .frame(height: 20)
    }
    
    private var barColor: Color {
        if usage > 80 { return Theme.accentRed }
        if usage > 50 { return Theme.accentOrange }
        return Theme.accentCyan
    }
}

// CPU History graph with gradient fill
struct CPUHistoryGraph: View {
    let values: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxVal = max(values.max() ?? 1, 1)
            
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
                .fill(Theme.cpuGradient)
                
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
                    LinearGradient(colors: [Theme.accentCyan, Theme.accentBlue], startPoint: .leading, endPoint: .trailing),
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
    CPUPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
