import Foundation
import SwiftUI

// Types of menu bar items that can be displayed
enum MenuBarItemType: String, CaseIterable, Codable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case battery = "Battery"
    case temperature = "Temperature"
    case gpu = "GPU"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100percent"
        case .temperature: return "thermometer.medium"
        case .gpu: return "cpu.fill"  // Using CPU icon as placeholder for GPU
        }
    }

    var defaultStyle: MenuBarItemStyle {
        switch self {
        case .cpu: return .percentage
        case .memory: return .bar
        case .disk: return .bar
        case .network: return .speed
        case .battery: return .bar
        case .temperature: return .text
        case .gpu: return .percentage
        }
    }
}

// Display styles for menu bar items
enum MenuBarItemStyle: String, CaseIterable, Codable, Identifiable {
    case text = "Text"                     // "45%" or "45°"
    case bar = "Bar"                       // [████░░]
    case graph = "Graph"                   // Mini sparkline
    case iconWithPercentage = "Icon + %"   // Icon + 45%
    case iconWithText = "Icon + Text"      // Custom icon + text value
    case speed = "Speed"                   // ↑ 1.2 MB/s ↓ 5.4 MB/s
    case percentage = "Percentage"         // 45%
    case pieChart = "Pie Chart"            // Mini pie
    case indicator = "Indicator"           // Dot indicator (for network)
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    // Context-aware display name for temperature
    func displayName(for type: MenuBarItemType) -> String {
        if type == .temperature {
            switch self {
            case .text: return "Degree (°C)"
            case .percentage: return "Degree (°C)"
            case .iconWithText: return "Icon + °C"
            default: return rawValue
            }
        }
        return rawValue
    }
}

// Available SF Symbol icons for customization
struct IconOptions {
    static let cpu = ["cpu", "cpu.fill", "bolt.circle", "flame", "waveform.path.ecg"]
    static let memory = ["memorychip", "memorychip.fill", "rectangle.stack", "square.stack.3d.up"]
    static let disk = ["internaldrive", "internaldrive.fill", "externaldrive", "opticaldiscdrive"]
    static let network = ["network", "wifi", "antenna.radiowaves.left.and.right", "arrow.up.arrow.down.circle"]
    static let battery = ["battery.100percent", "bolt.fill", "powerplug", "bolt.batteryblock"]
    static let temperature = ["thermometer.medium", "thermometer.sun", "flame", "snowflake"]
    static let gpu = ["cpu.fill", "flame.fill", "gearshape.2", "square.stack.3d.up.fill"]

    static func icons(for type: MenuBarItemType) -> [String] {
        switch type {
        case .cpu: return cpu
        case .memory: return memory
        case .disk: return disk
        case .network: return network
        case .battery: return battery
        case .temperature: return temperature
        case .gpu: return gpu
        }
    }
}

// Configuration for a single menu bar item
struct MenuBarItemConfig: Codable, Identifiable, Equatable {
    var id: String { type.rawValue }
    var type: MenuBarItemType
    var enabled: Bool
    var style: MenuBarItemStyle
    var order: Int
    var showLabel: Bool
    var customIcon: String  // SF Symbol name for custom icon
    
    init(type: MenuBarItemType, enabled: Bool = false, style: MenuBarItemStyle? = nil, order: Int = 0, showLabel: Bool = false, customIcon: String? = nil) {
        self.type = type
        self.enabled = enabled
        self.style = style ?? type.defaultStyle
        self.order = order
        self.showLabel = showLabel
        self.customIcon = customIcon ?? type.icon
    }
}

// Main settings model
class MenuBarSettings: ObservableObject {
    static let shared = MenuBarSettings()
    
    @Published var items: [MenuBarItemConfig] {
        didSet {
            save()
        }
    }
    
    @Published var itemSpacing: CGFloat = 4 {  // Ultra-compact layout
        didSet {
            save()
        }
    }
    
    @Published var useColoredIcons: Bool = true {
        didSet {
            save()
        }
    }
    
    private let userDefaultsKey = "MenuBarSettings"
    
    init() {
        // Default configuration - enable CPU, GPU, Memory, Network, Battery, and Temperature by default
        let defaultItems = [
            MenuBarItemConfig(type: .cpu, enabled: true, style: .percentage, order: 0),
            MenuBarItemConfig(type: .gpu, enabled: true, style: .percentage, order: 1),
            MenuBarItemConfig(type: .memory, enabled: true, style: .bar, order: 2),
            MenuBarItemConfig(type: .disk, enabled: false, style: .bar, order: 3),
            MenuBarItemConfig(type: .network, enabled: true, style: .speed, order: 4),
            MenuBarItemConfig(type: .battery, enabled: true, style: .bar, order: 5),
            MenuBarItemConfig(type: .temperature, enabled: true, style: .text, order: 6),
        ]

        // Try to load saved settings
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoded = try JSONDecoder().decode(SavedSettings.self, from: data)
                self.itemSpacing = decoded.itemSpacing
                self.useColoredIcons = decoded.useColoredIcons

                // Merge saved items with default items to ensure all item types exist
                var mergedItems: [MenuBarItemConfig] = []
                for defaultItem in defaultItems {
                    // Find saved item for this type
                    if let savedItem = decoded.items.first(where: { $0.type == defaultItem.type }) {
                        // Use saved item but ensure order matches default
                        var item = savedItem
                        item.order = defaultItem.order
                        mergedItems.append(item)
                    } else {
                        // New item type (like GPU) - use default
                        mergedItems.append(defaultItem)
                    }
                }
                self.items = mergedItems
                return
            } catch {
                NSLog("Failed to decode settings: \(error)")
            }
        }

        self.items = defaultItems
    }
    
    // Computed property for enabled items
    var enabledItems: [MenuBarItemConfig] {
        items.filter { $0.enabled }.sorted { $0.order < $1.order }
    }
    
    // Property for menu bar item display name
    var displayName: String {
        MenuBarItemStyle.text.rawValue
    }
    
    func save() {
        let settings = SavedSettings(items: items, itemSpacing: itemSpacing, useColoredIcons: useColoredIcons)
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            NSLog("Failed to save settings: \(error)")
        }
    }
    
    func getEnabledItems() -> [MenuBarItemConfig] {
        return items.filter { $0.enabled }.sorted { $0.order < $1.order }
    }

    func setEnabledItems(_ items: [MenuBarItemConfig]) {
        self.items = items
        save()
        NotificationCenter.default.post(name: .menuBarSettingsChanged, object: self)
    }

    func toggleItem(_ type: MenuBarItemType) {
        if let index = items.firstIndex(where: { $0.type == type }) {
            items[index].enabled.toggle()
        }
    }
    
    func updateStyle(for type: MenuBarItemType, style: MenuBarItemStyle) {
        if let index = items.firstIndex(where: { $0.type == type }) {
            items[index].style = style
        }
    }
    
    // Available styles for each item type
    func availableStyles(for type: MenuBarItemType) -> [MenuBarItemStyle] {
        switch type {
        case .cpu:
            return [.percentage, .bar, .iconWithText]
        case .memory:
            return [.bar, .percentage, .iconWithText]
        case .disk:
            return [.bar, .percentage, .iconWithText]
        case .network:
            return [.speed, .indicator, .iconWithText]
        case .battery:
            return [.bar, .percentage, .iconWithText]
        case .temperature:
            return [.text, .iconWithText]
        case .gpu:
            return [.percentage, .bar, .iconWithText]
        }
    }
}

// Codable wrapper for saving
private struct SavedSettings: Codable {
    var items: [MenuBarItemConfig]
    var itemSpacing: CGFloat
    var useColoredIcons: Bool
}

// MARK: - Notifications
extension Notification.Name {
    static let menuBarSettingsChanged = Notification.Name("com.xstats.menuBarSettingsChanged")
}
