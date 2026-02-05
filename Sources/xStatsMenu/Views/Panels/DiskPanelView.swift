import SwiftUI

struct DiskPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentCyan)
                
                Text("Disk")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Free space badge
                Text(collector.currentStats.disk.free.formattedBytes() + " free")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }

            // Usage visualization
            VStack(alignment: .leading, spacing: 6) {
                // Usage bar with gradient
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.background)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [usageColor, usageColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (collector.currentStats.disk.usagePercentage / 100))
                            .shadow(color: usageColor.opacity(0.3), radius: 2, x: 0, y: 0)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(Int(collector.currentStats.disk.usagePercentage))% used")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text(collector.currentStats.disk.total.formattedBytes())
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textTertiary)
                }
            }

            Divider().background(Theme.divider)

            // Read/Write speeds with icons
            VStack(spacing: 12) {
                // Read speed
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentCyan.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.accentCyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Read")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(formatSpeed(collector.currentStats.disk.readSpeed))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                }
                
                // Write speed
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentPink.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.accentPink)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Write")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(formatSpeed(collector.currentStats.disk.writeSpeed))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                }
            }

            Spacer()

            // Activity graph
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Activity")
                        .font(Theme.detailFont)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(Theme.accentCyan).frame(width: 5, height: 5)
                            Text("R").font(Theme.smallFont).foregroundColor(Theme.textTertiary)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Theme.accentPink).frame(width: 5, height: 5)
                            Text("W").font(Theme.smallFont).foregroundColor(Theme.textTertiary)
                        }
                    }
                }

                DualLineGraph(
                    primaryValues: collector.getDiskReadHistory(),
                    secondaryValues: collector.getDiskWriteHistory(),
                    primaryColor: Theme.accentCyan,
                    secondaryColor: Theme.accentPink
                )
            }
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }

    private var usageColor: Color {
        let usage = collector.currentStats.disk.usagePercentage
        if usage > 90 { return Theme.accentRed }
        if usage > 75 { return Theme.accentOrange }
        return Theme.accentCyan
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB/s", speed / (1024 * 1024 * 1024))
        } else if speed >= 1024 * 1024 {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        } else if speed >= 1024 {
            return String(format: "%.1f KB/s", speed / 1024)
        } else if speed > 0 {
            return String(format: "%.0f B/s", speed)
        }
        return "0 B/s"
    }
}

#Preview {
    DiskPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
