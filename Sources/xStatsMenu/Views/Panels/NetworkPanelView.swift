import SwiftUI

struct NetworkPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentGreen)
                
                Text("Network")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Connection status indicator
                Circle()
                    .fill(isActive ? Theme.accentGreen : Theme.textTertiary)
                    .frame(width: 6, height: 6)
            }

            if let ipAddress = collector.currentStats.network.ipAddress {
                HStack(spacing: 6) {
                    Text("IP")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textTertiary)

                    Text(ipAddress)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    if let interfaceName = collector.currentStats.network.interfaceName {
                        Text(interfaceName.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            // Upload/Download speeds
            VStack(spacing: 12) {
                // Upload
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentOrange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accentOrange)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Upload")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(formatSpeed(collector.currentStats.network.uploadSpeed))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                }
                
                // Download
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGreen.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accentGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Download")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(formatSpeed(collector.currentStats.network.downloadSpeed))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                }
            }

            Divider().background(Theme.divider)

            // Activity graph
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Activity")
                        .font(Theme.detailFont)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(Theme.accentOrange).frame(width: 5, height: 5)
                            Text("↑").font(Theme.smallFont).foregroundColor(Theme.textTertiary)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Theme.accentGreen).frame(width: 5, height: 5)
                            Text("↓").font(Theme.smallFont).foregroundColor(Theme.textTertiary)
                        }
                    }
                }

                DualLineGraph(
                    primaryValues: collector.getNetworkUpHistory(),
                    secondaryValues: collector.getNetworkDownHistory(),
                    primaryColor: Theme.accentOrange,
                    secondaryColor: Theme.accentGreen
                )
            }

            Spacer()

            // Total transferred
            VStack(spacing: 8) {
                Divider().background(Theme.divider)
                
                HStack(spacing: 0) {
                    // Sent
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.accentOrange.opacity(0.7))
                            Text("Sent")
                                .font(Theme.smallFont)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Text(collector.currentStats.network.totalUpload.formattedBytes())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    // Received
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Received")
                                .font(Theme.smallFont)
                                .foregroundColor(Theme.textSecondary)
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.accentGreen.opacity(0.7))
                        }
                        Text(collector.currentStats.network.totalDownload.formattedBytes())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }
    
    private var isActive: Bool {
        collector.currentStats.network.uploadSpeed > 0 || collector.currentStats.network.downloadSpeed > 0
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
    NetworkPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
