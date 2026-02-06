import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var statsCollector: StatsCollector

    // Feature flag: Toggle between vertical and horizontal layout
    private let useHorizontalLayout = true

    var body: some View {
        if useHorizontalLayout {
            horizontalLayout
        } else {
            verticalLayout
        }
    }

    // NEW: Horizontal layout (wider, modern design)
    private var horizontalLayout: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: 1) {
                CPUPanelView()

                PanelDivider()

                GPUPanelView()

                PanelDivider()

                MemoryPanelView()

                PanelDivider()

                DiskPanelView()

                PanelDivider()

                NetworkPanelView()

                // Show sensors panel if we have any sensor data
                if hasSensorData {
                    PanelDivider()
                    SensorsPanelView()
                }
            }
            
            // Footer
            HStack {
                Spacer()

                // Activity Monitor button
                Button(action: { openActivityMonitor() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .medium))
                        Text("Activity Monitor")
                            .font(Theme.smallFont)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.background.opacity(0.5))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Settings button
                Button(action: { openSettings() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .medium))
                        Text("Settings")
                            .font(Theme.smallFont)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.background.opacity(0.5))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Quit button
                Button(action: { NSApp.terminate(nil) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .medium))
                        Text("Quit")
                            .font(Theme.smallFont)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.background.opacity(0.5))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 8)
            .background(Theme.background.opacity(0.5))
        }
        .frame(width: hasSensorData ? 1212 : 1010, height: 380)
        .background(EffectMaterialView())
    }
    
    private var hasSensorData: Bool {
        statsCollector.currentStats.battery != nil ||
        statsCollector.currentStats.temperature != nil ||
        statsCollector.currentStats.fan != nil
    }
    
    private static var settingsWindow: NSWindow?

    private func openSettings() {
        // If settings window already exists and is visible, just bring it to front
        if let existingWindow = PopoverView.settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "xStats Menu Settings"
        settingsWindow.center()
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Store reference to prevent multiple windows
        PopoverView.settingsWindow = settingsWindow
    }

    private func openActivityMonitor() {
        // Open Activity Monitor using its bundle ID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.open(url)
        }
    }

    // EXISTING: Vertical layout (400x600) - fallback
    private var verticalLayout: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("xStats Menu")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Circle()
                    .fill(statsCollector.currentStats.memory.pressure == .critical ? Theme.accentRed :
                          statsCollector.currentStats.memory.pressure == .warning ? Theme.accentYellow :
                            Theme.accentGreen)
                    .frame(width: 8, height: 8)
            }
            .padding(Theme.cardPadding)

            Divider()
                .background(Color.white.opacity(0.2))

            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    CPUView(stats: statsCollector.currentStats)
                    MemoryView(stats: statsCollector.currentStats)
                    DiskView(stats: statsCollector.currentStats)
                    NetworkView(stats: statsCollector.currentStats)

                    if let _ = statsCollector.currentStats.battery {
                        SensorsView(stats: statsCollector.currentStats)
                    }
                }
                .padding(Theme.cardPadding)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Footer
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Updating every second")
                        .font(Theme.detailFont)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accentBlue)
                .font(Theme.labelFont)
            }
            .padding(Theme.cardPadding)
        }
        .frame(width: 400, height: 600)
        .background(EffectMaterialView())
    }
}

// Panel divider with gradient
struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Theme.divider.opacity(0), Theme.divider, Theme.divider.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
    }
}

struct EffectMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
