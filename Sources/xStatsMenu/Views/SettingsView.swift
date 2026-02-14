import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var settings = MenuBarSettings.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Menu Bar").tag(0)
                Text("General").tag(1)
                Text("About").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            Divider()
                .background(Theme.textSecondary.opacity(0.2))
            
            // Content
            ScrollView {
                switch selectedTab {
                case 0:
                    MenuBarSettingsTab(settings: settings)
                case 1:
                    GeneralSettingsTab()
                case 2:
                    AboutTab()
                default:
                    EmptyView()
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 400)
        .background(EffectMaterialView())
    }
}

// MARK: - Menu Bar Settings Tab
struct MenuBarSettingsTab: View {
    @ObservedObject var settings: MenuBarSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure what appears in your menu bar")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 20)
            
            // Menu bar items list
            VStack(spacing: 8) {
                ForEach(settings.items.indices, id: \.self) { index in
                    MenuBarItemRow(
                        config: $settings.items[index],
                        onToggle: { settings.save() },
                        onStyleChange: { settings.save() }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Divider()
                .background(Theme.textSecondary.opacity(0.2))
                .padding(.horizontal, 20)
            
            // Preview section
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 10) {
                    ForEach(settings.enabledItems) { config in
                        PreviewItem(config: config)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Menu Bar Item Row
struct MenuBarItemRow: View {
    @Binding var config: MenuBarItemConfig
    let onToggle: () -> Void
    let onStyleChange: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: config.customIcon)
                    .font(.system(size: 14))
                    .foregroundColor(config.enabled ? .cyan : .gray)
                    .frame(width: 24)
                
                // Name
                Text(config.type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(config.enabled ? Theme.textPrimary : Theme.textSecondary)
                    .frame(width: 90, alignment: .leading)
                
                Spacer()
                
                // Style picker with context-aware display names - aligned right
                Picker("", selection: $config.style) {
                    ForEach(availableStyles, id: \.self) { style in
                        Text(style.displayName(for: config.type)).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120, alignment: .trailing)
                .disabled(!config.enabled)
                .onChange(of: config.style) { _ in onStyleChange() }
                
                // Enable toggle
                Toggle("", isOn: $config.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: config.enabled) { _ in onToggle() }
            }
            
            // Icon picker - show only when iconWithText style is selected
            if config.style == .iconWithText && config.enabled {
                HStack(spacing: 6) {
                    Text("Icon:")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    
                    ForEach(IconOptions.icons(for: config.type), id: \.self) { iconName in
                        Button(action: {
                            config.customIcon = iconName
                            onStyleChange()
                        }) {
                            Image(systemName: iconName)
                                .font(.system(size: 12))
                                .foregroundColor(config.customIcon == iconName ? .cyan : .gray)
                                .frame(width: 24, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(config.customIcon == iconName ? Color.cyan.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 36)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(config.enabled ? Theme.cardBackground : Color.clear)
        )
    }
    
    private var availableStyles: [MenuBarItemStyle] {
        MenuBarSettings.shared.availableStyles(for: config.type)
    }
}

// MARK: - Preview Item
struct PreviewItem: View {
    let config: MenuBarItemConfig
    
    var body: some View {
        if config.style == .iconWithText {
            // Icon + Text preview
            HStack(spacing: 3) {
                Image(systemName: config.customIcon)
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text(previewValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(4)
        } else {
            VStack(spacing: 2) {
                // Label at top
                Text(labelText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                // Content based on style
                previewContent
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(4)
        }
    }
    
    private var previewValue: String {
        switch config.type {
        case .cpu, .memory, .disk, .gpu: return "45%"
        case .network: return "↑1.2M"
        case .battery: return "85%"
        case .temperature: return "45°"
        }
    }

    private var labelText: String {
        switch config.type {
        case .cpu: return "CPU"
        case .memory: return "MEM"
        case .disk: return "SSD"
        case .network: return "NET"
        case .battery: return "2:30"
        case .temperature: return "TMP"
        case .gpu: return "GPU"
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch config.type {
        case .cpu, .memory, .disk, .gpu:
            if config.style == .percentage {
                Text("45%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            } else {
                // Bar style
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 28, height: 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            }
        case .network:
            if config.style == .indicator {
                // Vertical indicator
                VStack(spacing: 2) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("↑ 1.2M")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text("↓ 5.8M")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            }
        case .battery:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green)
                .frame(width: 28, height: 7)
        case .temperature:
            Text("45°C")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showOnAllSpaces") private var showOnAllSpaces: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Refresh interval
            VStack(alignment: .leading, spacing: 8) {
                Text("Update Interval")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                HStack {
                    Slider(value: $refreshInterval, in: 1...10, step: 0.5)
                        .frame(width: 200)
                    Text("\(refreshInterval, specifier: "%.1f")s")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 40)
                }
            }

            Divider()
                .background(Theme.textSecondary.opacity(0.2))

            // Toggles
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show on all Spaces/Desktops", isOn: $showOnAllSpaces)
                    .toggleStyle(.checkbox)

                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                    }
                ))
                .toggleStyle(.checkbox)
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.textPrimary)

            Spacer()
        }
        .padding(20)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the setting on failure
            launchAtLogin = !enabled
        }
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("xStats Menu")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text("Version 1.0.0")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            
            Text("A modern system monitoring tool for macOS")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("© 2024 xStats Menu")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
        .padding(20)
    }
}
