import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let statsCollector = StatsCollector.shared
    let menuBarSettings = MenuBarSettings.shared

    // Cached fonts and attributes for menu bar rendering
    private let labelFont = NSFont.systemFont(ofSize: 9, weight: .medium)
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    private let networkFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)

    // Cache for tinted SF Symbol icons: [iconName: [colorHash: NSImage]]
    private var iconCache: [String: [Int: NSImage]] = [:]

    // Blink state for low battery warning (< 30%)
    private var isBatteryVisible = true
    private var blinkTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup status bar item
        setupStatusBar()

        // Setup popover
        setupPopover()

        // Set up callback for UI updates
        statsCollector.onUpdate = { [weak self] stats in
            self?.updateDisplay(with: stats)
        }

        // Start monitoring
        statsCollector.startMonitoring()
    }

    // MARK: - Battery Blink Timer

    private func startBlinkTimer() {
        guard blinkTimer == nil else { return }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.isBatteryVisible.toggle()
            if let self = self {
                self.updateDisplay(with: self.statsCollector.currentStats)
            }
        }
    }

    private func stopBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isBatteryVisible = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func setupStatusBar() {
        // Use variable length to auto-size based on content
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "xStats"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func setupPopover() {
        popover = NSPopover()

        // Create root view with environment objects
        let rootView = PopoverView()
            .environmentObject(statsCollector)
            .environmentObject(menuBarSettings)

        popover?.contentViewController = NSHostingController(rootView: rootView)

        popover?.contentSize = NSSize(width: 1212, height: 380)
        popover?.behavior = .transient
        popover?.animates = false
    }

    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                if let button = statusItem?.button {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }

    func updateDisplay(with stats: SystemStats) {
        guard let button = statusItem?.button else {
            return
        }

        // Manage blink timer: only run when battery < 30%
        let needsBlink = stats.battery.map { $0.level < 30 } ?? false
        if needsBlink && blinkTimer == nil {
            startBlinkTimer()
        } else if !needsBlink && blinkTimer != nil {
            stopBlinkTimer()
        }

        let enabledItems = menuBarSettings.enabledItems

        if enabledItems.isEmpty {
            button.title = "\(Int(stats.cpu.totalUsage))%"
            button.image = nil
            return
        }

        // Create menu bar image with labels and bars like iStat Menus
        let image = createMenuBarImage(stats: stats, configs: enabledItems)
        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly

        if let popover = popover, popover.isShown {
            let targetWidth = popoverWidth(for: stats)
            if popover.contentSize.width != targetWidth {
                popover.contentSize = NSSize(width: targetWidth, height: 380)
            }
        }
    }

    private func popoverWidth(for stats: SystemStats) -> CGFloat {
        let hasSensorData = stats.battery != nil || stats.temperature != nil || stats.fan != nil
        return hasSensorData ? 1212 : 1010
    }

    func applicationWillTerminate(_ notification: Notification) {
        statsCollector.stopMonitoring()
        blinkTimer?.invalidate()
    }

    // MARK: - Menu Bar Image Creation

    private func createMenuBarImage(stats: SystemStats, configs: [MenuBarItemConfig]) -> NSImage {
        let itemHeight: CGFloat = 24
        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 7
        let spacing: CGFloat = 12
        let leftPadding: CGFloat = 4
        let rightPadding: CGFloat = 4
        let indicatorWidth: CGFloat = 10
        let speedStyleWidth: CGFloat = 55

        // Pre-compute network speed texts (reused in width calc and drawing)
        let networkSpeedText: String = {
            let up = stats.network.uploadSpeed
            let down = stats.network.downloadSpeed
            if up > 0 || down > 0 {
                if up > 1024 && down > 1024 {
                    return String(format: "%.1f↑ %.1f↓", up / 1024, down / 1024)
                } else if up > 1024 {
                    return String(format: "%.1f↑", up / 1024)
                } else if down > 1024 {
                    return String(format: "%.1f↓", down / 1024)
                } else {
                    return formatSpeed(up + down)
                }
            }
            return "0K"
        }()
        let networkDownText = formatSpeed(stats.network.downloadSpeed)
        let networkUpText = formatSpeed(stats.network.uploadSpeed)

        // Calculate total width
        var totalWidth: CGFloat = leftPadding + rightPadding

        for (index, config) in configs.enumerated() {
            let trailingSpacing: CGFloat = index < configs.count - 1 ? spacing : 0
            switch config.type {
            case .cpu, .memory, .disk, .gpu:
                let (itemLabel, itemPercentage): (String, Double) = {
                    switch config.type {
                    case .cpu: return ("CPU", stats.cpu.totalUsage)
                    case .memory: return ("MEM", stats.memory.usagePercentage)
                    case .disk: return ("DSK", stats.disk.usagePercentage)
                    case .gpu: return ("GPU", stats.gpu?.usage ?? 0)
                    default: return ("", 0)
                    }
                }()
                let valueText = "\(Int(itemPercentage))%"

                if config.style == .iconWithText {
                    totalWidth += calculateIconWithTextWidth(text: valueText) + trailingSpacing
                } else if config.style == .percentage {
                    totalWidth += measurePercentageWidth(label: itemLabel, value: valueText) + trailingSpacing
                } else {
                    totalWidth += barWidth + trailingSpacing
                }
            case .network:
                if config.style == .iconWithText {
                    totalWidth += calculateIconWithTextWidth(text: networkSpeedText) + trailingSpacing
                } else if config.style == .indicator {
                    totalWidth += indicatorWidth + trailingSpacing
                } else {
                    totalWidth += speedStyleWidth + trailingSpacing
                }
            case .battery:
                if config.style == .iconWithText {
                    var batteryText = "--%"
                    if let battery = stats.battery {
                        var statusSuffix = ""
                        if battery.isCharging || battery.isPlugged {
                            statusSuffix = " AC"
                        }
                        batteryText = "\(battery.level)%\(statusSuffix)"
                    }
                    totalWidth += calculateIconWithTextWidth(text: batteryText) + trailingSpacing
                } else if config.style == .percentage {
                    let batteryLevel = stats.battery?.level ?? 0
                    totalWidth += measurePercentageWidth(label: "BATT", value: "\(batteryLevel)%") + trailingSpacing
                } else {
                    totalWidth += barWidth + trailingSpacing
                }
            case .temperature:
                let cpuTemp = stats.temperature?.cpu ?? 0
                let tempText = cpuTemp > 0 ? "\(Int(cpuTemp))°" : "--°"
                if config.style == .iconWithText {
                    totalWidth += calculateIconWithTextWidth(text: tempText) + trailingSpacing
                } else {
                    totalWidth += measurePercentageWidth(label: "TEMP", value: tempText) + trailingSpacing
                }
            }
        }

        #if DEBUG
        print("🔧 MenuBar calculated width: \(totalWidth)px")
        #endif

        let imageSize = NSSize(width: totalWidth, height: itemHeight)
        let image = NSImage(size: imageSize)

        image.lockFocus()

        var xOffset: CGFloat = leftPadding

        for (index, config) in configs.enumerated() {
            let trailingSpacing: CGFloat = index < configs.count - 1 ? spacing : 0
            switch config.type {
            case .cpu, .memory, .disk:
                let itemLabel: String
                let itemPercentage: Double
                let itemColor: NSColor
                switch config.type {
                case .cpu:
                    itemLabel = "CPU"
                    itemPercentage = stats.cpu.totalUsage
                    itemColor = cpuNSColor(stats.cpu.totalUsage)
                case .memory:
                    itemLabel = "MEM"
                    itemPercentage = stats.memory.usagePercentage
                    itemColor = memNSColor(stats.memory.usagePercentage)
                case .disk:
                    itemLabel = "DSK"
                    itemPercentage = stats.disk.usagePercentage
                    itemColor = diskNSColor(stats.disk.usagePercentage)
                default:
                    itemLabel = ""
                    itemPercentage = 0
                    itemColor = .secondaryLabelColor
                }

                if config.style == .iconWithText {
                    let actualWidth = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: "\(Int(itemPercentage))%",
                        color: itemColor,
                        height: itemHeight
                    )
                    xOffset += actualWidth + trailingSpacing
                } else if config.style == .percentage {
                    let pctWidth = measurePercentageWidth(label: itemLabel, value: "\(Int(itemPercentage))%")
                    drawPercentageText(
                        at: xOffset,
                        label: itemLabel,
                        percentage: itemPercentage,
                        color: itemColor,
                        labelFont: labelFont,
                        valueFont: valueFont,
                        height: itemHeight
                    )
                    xOffset += pctWidth + trailingSpacing
                } else {
                    drawLabeledBar(
                        at: xOffset,
                        label: itemLabel,
                        value: itemPercentage / 100,
                        color: itemColor,
                        barWidth: barWidth,
                        barHeight: barHeight,
                        labelFont: labelFont,
                        height: itemHeight
                    )
                    xOffset += barWidth + trailingSpacing
                }

            case .network:
                if config.style == .iconWithText {
                    let actualWidth = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: networkSpeedText,
                        color: NSColor.systemGreen,
                        height: itemHeight
                    )
                    xOffset += actualWidth + trailingSpacing
                } else if config.style == .indicator {
                    let dotSize: CGFloat = 7
                    let dotSpacing: CGFloat = 2
                    let dotX = xOffset + (indicatorWidth - dotSize) / 2

                    let totalDotsHeight = (dotSize * 2) + dotSpacing
                    let startY = (itemHeight - totalDotsHeight) / 2

                    let downloadActive = stats.network.downloadSpeed > 0
                    let uploadActive = stats.network.uploadSpeed > 0

                    // Download dot (green) - top
                    let downloadColor = downloadActive ? NSColor.systemGreen : NSColor.darkGray
                    downloadColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: dotX, y: startY, width: dotSize, height: dotSize)).fill()

                    // Upload dot (red) - bottom
                    let uploadColor = uploadActive ? NSColor.systemRed : NSColor.darkGray
                    uploadColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: dotX, y: startY + dotSize + dotSpacing, width: dotSize, height: dotSize)).fill()

                    xOffset += indicatorWidth + trailingSpacing
                } else {
                    // Speed style: dots on left, text right-aligned
                    let downloadActive = stats.network.downloadSpeed > 0
                    let uploadActive = stats.network.uploadSpeed > 0

                    let dotSize: CGFloat = 4
                    let dotOffset: CGFloat = 7

                    let downloadY = itemHeight - 11
                    let uploadY: CGFloat = 1
                    let visualCenterOffset: CGFloat = 3

                    // Download dot (green)
                    let downloadDotColor = downloadActive ? NSColor.systemGreen : NSColor.darkGray
                    downloadDotColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: xOffset + 1, y: downloadY + visualCenterOffset, width: dotSize, height: dotSize)).fill()

                    // Upload dot (red)
                    let uploadDotColor = uploadActive ? NSColor.systemRed : NSColor.darkGray
                    uploadDotColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: xOffset + 1, y: uploadY + visualCenterOffset, width: dotSize, height: dotSize)).fill()

                    let downloadAttr: [NSAttributedString.Key: Any] = [
                        .font: networkFont,
                        .foregroundColor: NSColor.systemGreen
                    ]
                    let uploadAttr: [NSAttributedString.Key: Any] = [
                        .font: networkFont,
                        .foregroundColor: NSColor.systemRed
                    ]

                    let textAreaWidth = speedStyleWidth - dotOffset
                    let downloadTextWidth = (networkDownText as NSString).size(withAttributes: downloadAttr).width
                    let uploadTextWidth = (networkUpText as NSString).size(withAttributes: uploadAttr).width

                    // Draw download speed (green) - RIGHT-aligned
                    let downloadX = xOffset + dotOffset + (textAreaWidth - downloadTextWidth)
                    (networkDownText as NSString).draw(at: NSPoint(x: downloadX, y: downloadY), withAttributes: downloadAttr)

                    // Draw upload speed (red) - RIGHT-aligned
                    let uploadX = xOffset + dotOffset + (textAreaWidth - uploadTextWidth)
                    (networkUpText as NSString).draw(at: NSPoint(x: uploadX, y: uploadY), withAttributes: uploadAttr)

                    xOffset += speedStyleWidth + trailingSpacing
                }

            case .battery:
                if let battery = stats.battery {
                    // Check if battery should be hidden (blink state) when < 30%
                    let shouldHide = battery.level < 30 && !isBatteryVisible

                    // Calculate battery color with alpha for blinking
                    let baseColor = batteryNSColor(battery.level)
                    let batteryColor = shouldHide ? NSColor(white: 1, alpha: 0.0) : baseColor

                    // Save graphics state and set opacity for blinking effect
                    NSGraphicsContext.saveGraphicsState()

                    if config.style == .iconWithText {
                        // Icon + percentage text (same style as CPU/GPU)
                        var statusSuffix = ""
                        if battery.isCharging || battery.isPlugged {
                            statusSuffix = " AC"
                        }
                        let batteryText = "\(battery.level)%\(statusSuffix)"
                        let actualWidth = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: batteryText,
                            color: batteryColor,
                            height: itemHeight
                        )
                        xOffset += actualWidth + trailingSpacing
                    } else if config.style == .percentage {
                        let pctWidth = measurePercentageWidth(label: "BATT", value: "\(battery.level)%")
                        drawPercentageText(
                            at: xOffset,
                            label: "BATT",
                            percentage: Double(battery.level),
                            color: batteryColor,
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += pctWidth + trailingSpacing
                    } else {
                        // Bar style: time estimate label on top, bar below
                        var timeLabel = ""
                        if battery.isCharging || battery.isPlugged {
                            timeLabel = "AC"
                        } else if let time = battery.timeRemaining, time > 0 {
                            let hours = time / 60
                            let mins = time % 60
                            if hours > 0 {
                                timeLabel = "\(hours):\(String(format: "%02d", mins))"
                            } else {
                                timeLabel = "\(mins)m"
                            }
                        } else {
                            timeLabel = "BATT"
                        }

                        drawLabeledBar(
                            at: xOffset,
                            label: timeLabel,
                            value: Double(battery.level) / 100,
                            color: batteryColor,
                            barWidth: barWidth,
                            barHeight: barHeight,
                            labelFont: labelFont,
                            height: itemHeight
                        )
                        xOffset += barWidth + trailingSpacing
                    }

                    // Restore graphics state after battery drawing
                    NSGraphicsContext.restoreGraphicsState()
                } else {
                    // Battery not available - show placeholder based on style
                    if config.style == .iconWithText {
                        let actualWidth = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: "--%",
                            color: NSColor.secondaryLabelColor,
                            height: itemHeight
                        )
                        xOffset += actualWidth + trailingSpacing
                    } else if config.style == .percentage {
                        let pctWidth = measurePercentageWidth(label: "BATT", value: "0%")
                        drawPercentageText(
                            at: xOffset,
                            label: "BATT",
                            percentage: 0,
                            color: NSColor.secondaryLabelColor,
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += pctWidth + trailingSpacing
                    } else {
                        drawLabeledBar(
                            at: xOffset,
                            label: "BATT",
                            value: 0,
                            color: NSColor.secondaryLabelColor,
                            barWidth: barWidth,
                            barHeight: barHeight,
                            labelFont: labelFont,
                            height: itemHeight
                        )
                        xOffset += barWidth + trailingSpacing
                    }
                }

            case .temperature:
                let cpuTemp = stats.temperature?.cpu ?? 0
                let hasCpuTemp = cpuTemp > 0
                let tempColor = hasCpuTemp ? tempNSColor(cpuTemp) : NSColor.secondaryLabelColor

                if config.style == .iconWithText {
                    let tempText = hasCpuTemp ? "\(Int(cpuTemp))°" : "--°"
                    let actualWidth = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: tempText,
                        color: tempColor,
                        height: itemHeight
                    )
                    xOffset += actualWidth + trailingSpacing
                } else {
                    let tempStr = hasCpuTemp ? "\(Int(cpuTemp))°" : "--°"
                    let tempWidth = measurePercentageWidth(label: "TEMP", value: tempStr)

                    // Draw label at top
                    let labelAttr: [NSAttributedString.Key: Any] = [
                        .font: labelFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let labelY = itemHeight - 11
                    ("TEMP" as NSString).draw(at: NSPoint(x: xOffset, y: labelY), withAttributes: labelAttr)

                    // Draw value below
                    let valueAttr: [NSAttributedString.Key: Any] = [
                        .font: valueFont,
                        .foregroundColor: tempColor
                    ]
                    let valueY: CGFloat = 1
                    (tempStr as NSString).draw(at: NSPoint(x: xOffset, y: valueY), withAttributes: valueAttr)

                    xOffset += tempWidth + trailingSpacing
                }

            case .gpu:
                if let gpu = stats.gpu {
                    if config.style == .iconWithText {
                        let actualWidth = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: "\(Int(gpu.usage))%",
                            color: gpuNSColor(gpu.usage),
                            height: itemHeight
                        )
                        xOffset += actualWidth + trailingSpacing
                    } else if config.style == .percentage {
                        let pctWidth = measurePercentageWidth(label: "GPU", value: "\(Int(gpu.usage))%")
                        drawPercentageText(
                            at: xOffset,
                            label: "GPU",
                            percentage: gpu.usage,
                            color: gpuNSColor(gpu.usage),
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += pctWidth + trailingSpacing
                    } else {
                        drawLabeledBar(
                            at: xOffset,
                            label: "GPU",
                            value: gpu.usage / 100,
                            color: gpuNSColor(gpu.usage),
                            barWidth: barWidth,
                            barHeight: barHeight,
                            labelFont: labelFont,
                            height: itemHeight
                        )
                        xOffset += barWidth + trailingSpacing
                    }
                } else {
                    // GPU not available - show placeholder
                    let placeholderWidth = measurePercentageWidth(label: "GPU", value: "--%")
                    let labelAttr: [NSAttributedString.Key: Any] = [
                        .font: labelFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let labelY = itemHeight - 11
                    ("GPU" as NSString).draw(at: NSPoint(x: xOffset, y: labelY), withAttributes: labelAttr)

                    let attr: [NSAttributedString.Key: Any] = [
                        .font: valueFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let valueY: CGFloat = 1
                    ("--%" as NSString).draw(at: NSPoint(x: xOffset, y: valueY), withAttributes: attr)
                    xOffset += placeholderWidth + trailingSpacing
                }
            }
        }

        image.unlockFocus()

        return image
    }

    // MARK: - Drawing Helpers

    // Measure width for percentage/text style (label on top, value on bottom)
    private func measurePercentageWidth(label: String, value: String) -> CGFloat {
        let labelWidth = (label as NSString).size(withAttributes: [.font: labelFont]).width
        let valueWidth = (value as NSString).size(withAttributes: [.font: valueFont]).width
        return ceil(max(labelWidth, valueWidth))
    }

    // Measure width for network speed style (dots + two stacked speed texts)
    private func measureSpeedStyleWidth(downloadText: String, uploadText: String) -> CGFloat {
        let dotOffset: CGFloat = 7
        let attr: [NSAttributedString.Key: Any] = [.font: networkFont]
        let downloadWidth = (downloadText as NSString).size(withAttributes: attr).width
        let uploadWidth = (uploadText as NSString).size(withAttributes: attr).width
        return dotOffset + ceil(max(downloadWidth, uploadWidth))
    }

    // Calculate width for iconWithText style without drawing
    private func calculateIconWithTextWidth(text: String) -> CGFloat {
        let iconSize: CGFloat = 10
        let iconTextSpacing: CGFloat = 5

        let attr: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: NSColor.labelColor
        ]
        let textStr = text as NSString
        let textSize = textStr.size(withAttributes: attr)

        return iconSize + iconTextSpacing + ceil(textSize.width)
    }

    private func drawLabeledBar(at x: CGFloat, label: String, value: Double, color: NSColor, barWidth: CGFloat, barHeight: CGFloat, labelFont: NSFont, height: CGFloat) {
        // Draw label at top
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let labelY = height - 11
        (label as NSString).draw(at: NSPoint(x: x, y: labelY), withAttributes: labelAttr)

        // Draw bar background at bottom
        let barY: CGFloat = 2
        let bgRect = NSRect(x: x, y: barY, width: barWidth, height: barHeight)
        NSColor.darkGray.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3).fill()

        // Draw bar fill
        let fillWidth = barWidth * min(max(value, 0), 1)
        let fillRect = NSRect(x: x, y: barY, width: fillWidth, height: barHeight)
        color.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3).fill()
    }

    private func drawPercentageText(at x: CGFloat, label: String, percentage: Double, color: NSColor, labelFont: NSFont, valueFont: NSFont, height: CGFloat) {
        // Draw label at top
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let labelY = height - 11
        (label as NSString).draw(at: NSPoint(x: x, y: labelY), withAttributes: labelAttr)

        // Draw percentage value below
        let valueStr = "\(Int(percentage))%"
        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: color
        ]
        let valueY: CGFloat = 1
        (valueStr as NSString).draw(at: NSPoint(x: x, y: valueY), withAttributes: valueAttr)
    }

    // Draw SF Symbol icon with text (Icon + Text style) - horizontal layout
    private func drawIconWithText(at x: CGFloat, iconName: String, text: String, color: NSColor, height: CGFloat) -> CGFloat {
        let iconSize: CGFloat = 10
        let iconTextSpacing: CGFloat = 5

        // Calculate text width and get proper text dimensions
        let attr: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: color
        ]
        let textStr = text as NSString
        let textSize = textStr.size(withAttributes: attr)

        // Total width: icon + spacing + text
        let totalWidth = iconSize + iconTextSpacing + ceil(textSize.width)

        // Use visual center alignment for both icon and text
        // Menu bar is ~24px tall, center both elements
        let centerY = height / 2

        // Draw icon on the left - vertically centered with text
        let textY = centerY - (textSize.height / 2)
        let iconY = centerY - (iconSize / 2)

        if let tintedImage = cachedIcon(name: iconName, color: color, size: iconSize) {
            tintedImage.draw(in: NSRect(x: x, y: iconY, width: iconSize, height: iconSize),
                          from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        textStr.draw(at: NSPoint(x: x + iconSize + iconTextSpacing, y: textY), withAttributes: attr)

        return totalWidth
    }

    // MARK: - Icon Cache

    private func cachedIcon(name: String, color: NSColor, size: CGFloat) -> NSImage? {
        let colorHash = color.hash
        if let cached = iconCache[name]?[colorHash] {
            return cached
        }

        guard let iconImage = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        guard let configuredIcon = iconImage.withSymbolConfiguration(config) else {
            return nil
        }

        let tintedImage = NSImage(size: NSSize(width: size, height: size))
        tintedImage.lockFocus()
        color.set()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        configuredIcon.draw(in: rect)
        rect.fill(using: .sourceAtop)
        tintedImage.unlockFocus()

        iconCache[name, default: [:]][colorHash] = tintedImage
        return tintedImage
    }

    // MARK: - Color Helpers

    private func cpuNSColor(_ usage: Double) -> NSColor {
        if usage > 80 { return .systemRed }
        if usage > 50 { return .systemOrange }
        return .systemCyan
    }

    private func memNSColor(_ usage: Double) -> NSColor {
        if usage > 90 { return .systemRed }
        if usage > 70 { return .systemOrange }
        return .systemGreen
    }

    private func diskNSColor(_ usage: Double) -> NSColor {
        if usage > 90 { return .systemRed }
        if usage > 75 { return .systemOrange }
        return .systemCyan
    }

    private func batteryNSColor(_ level: Int) -> NSColor {
        if level <= 20 { return .systemRed }
        if level <= 40 { return .systemOrange }
        return .systemGreen
    }

    private func tempNSColor(_ temp: Double) -> NSColor {
        if temp > 90 { return .systemRed }
        if temp > 70 { return .systemOrange }
        if temp > 50 { return .systemYellow }
        return .systemGreen
    }

    private func gpuNSColor(_ usage: Double) -> NSColor {
        if usage > 80 { return .systemRed }
        if usage > 50 { return .systemOrange }
        return .systemPurple
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1024 * 1024 {
            return String(format: "%.1fMB/s", speed / (1024 * 1024))
        } else if speed >= 1024 {
            return String(format: "%.0fKB/s", speed / 1024)
        }
        return "0KB/s"
    }
}
