import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let statsCollector = StatsCollector.shared
    let menuBarSettings = MenuBarSettings.shared

    // Cached fonts and attributes for menu bar rendering
    private let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

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

        // Start blink timer for low battery warning
        startBlinkTimer()
    }

    // MARK: - Battery Blink Timer

    private func startBlinkTimer() {
        // Toggle visibility every 1 second for low battery warning
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.isBatteryVisible.toggle()
            // Trigger update to refresh menu bar
            if let self = self {
                self.updateDisplay(with: self.statsCollector.currentStats)
            }
        }
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
        let barWidth: CGFloat = 34
        let barHeight: CGFloat = 7
        let spacing: CGFloat = 10  // Comfortable spacing between items
        let leftPadding: CGFloat = 6
        let rightPadding: CGFloat = 6

        // Calculate total width
        var totalWidth: CGFloat = leftPadding + rightPadding

        for (index, config) in configs.enumerated() {
            let trailingSpacing: CGFloat = index < configs.count - 1 ? spacing : 0
            switch config.type {
            case .cpu, .memory, .disk, .gpu:
                if config.style == .iconWithText {
                    totalWidth += 44 + trailingSpacing
                } else if config.style == .percentage {
                    totalWidth += 40 + trailingSpacing
                } else {
                    totalWidth += barWidth + trailingSpacing  // Bar with label (vertical)
                }
            case .network:
                if config.style == .iconWithText {
                    totalWidth += 94 + trailingSpacing  // Icon + speed text (with units like KB/s, MB/s)
                } else if config.style == .indicator {
                    totalWidth += 14 + trailingSpacing  // Two stacked dots
                } else {
                    totalWidth += 76 + trailingSpacing  // Speed text (download + upload stacked vertically with units)
                }
            case .battery:
                if config.style == .iconWithText {
                    totalWidth += 52 + trailingSpacing  // Icon + percentage + AC text
                } else if config.style == .percentage {
                    totalWidth += 40 + trailingSpacing  // BATT label + percentage (like CPU)
                } else {
                    totalWidth += barWidth + trailingSpacing  // Bar with time estimate label
                }
            case .temperature:
                if config.style == .iconWithText {
                    totalWidth += 48 + trailingSpacing
                } else {
                    totalWidth += 40 + trailingSpacing  // TEMP label + value (like CPU)
                }
            }
        }

        // Debug: print calculated width
        print("🔧 MenuBar calculated width: \(totalWidth)px")

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
                    _ = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: "\(Int(itemPercentage))%",
                        color: itemColor,
                        height: itemHeight
                    )
                    xOffset += 44 + trailingSpacing
                } else if config.style == .percentage {
                    drawPercentageText(
                        at: xOffset,
                        label: itemLabel,
                        percentage: itemPercentage,
                        color: itemColor,
                        labelFont: labelFont,
                        valueFont: valueFont,
                        height: itemHeight
                    )
                    xOffset += 40 + trailingSpacing
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
                    let uploadSpeed = stats.network.uploadSpeed
                    let downloadSpeed = stats.network.downloadSpeed

                    var speedText = ""
                    if uploadSpeed > 0 || downloadSpeed > 0 {
                        if uploadSpeed > 1024 && downloadSpeed > 1024 {
                            speedText = String(format: "%.1f↑ %.1f↓", uploadSpeed / 1024, downloadSpeed / 1024)
                        } else if uploadSpeed > 1024 {
                            speedText = String(format: "%.1f↑", uploadSpeed / 1024)
                        } else if downloadSpeed > 1024 {
                            speedText = String(format: "%.1f↓", downloadSpeed / 1024)
                        } else {
                            speedText = formatSpeed(uploadSpeed + downloadSpeed)
                        }
                    } else {
                        speedText = "0K"
                    }

                    _ = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: speedText,
                        color: NSColor.systemGreen,
                        height: itemHeight
                    )
                    xOffset += 94 + trailingSpacing
                } else if config.style == .indicator {
                    // Show two stacked dots: green (download) on top, red (upload) below
                    // No blinking - solid colors when active
                    let dotSize: CGFloat = 7
                    let dotSpacing: CGFloat = 2

                    // Calculate positions for two stacked dots
                    let totalDotsHeight = (dotSize * 2) + dotSpacing
                    let startY = (itemHeight - totalDotsHeight) / 2

                    // Check if there's traffic
                    let downloadActive = stats.network.downloadSpeed > 0
                    let uploadActive = stats.network.uploadSpeed > 0

                    // Download dot (green) - top
                    let downloadDotRect = NSRect(x: xOffset + 3, y: startY, width: dotSize, height: dotSize)
                    let downloadColor = downloadActive ? NSColor.systemGreen : NSColor.darkGray
                    downloadColor.setFill()
                    NSBezierPath(ovalIn: downloadDotRect).fill()

                    // Upload dot (red) - bottom
                    let uploadDotRect = NSRect(x: xOffset + 3, y: startY + dotSize + dotSpacing, width: dotSize, height: dotSize)
                    let uploadColor = uploadActive ? NSColor.systemRed : NSColor.darkGray
                    uploadColor.setFill()
                    NSBezierPath(ovalIn: uploadDotRect).fill()

                    xOffset += 14 + trailingSpacing
                } else {
                    // Speed style: show download (green) and upload (red) speeds stacked vertically
                    // Add two small dots on the LEFT side, text RIGHT-aligned
                    let downloadSpeed = stats.network.downloadSpeed
                    let uploadSpeed = stats.network.uploadSpeed

                    let downloadText = formatSpeed(downloadSpeed)
                    let uploadText = formatSpeed(uploadSpeed)

                    // Check if there's traffic (no blinking)
                    let downloadActive = downloadSpeed > 0
                    let uploadActive = uploadSpeed > 0

                    // Draw dots first (on the left)
                    let dotSize: CGFloat = 4
                    let dotOffset: CGFloat = 7  // Space for dots + padding
                    let textAreaWidth: CGFloat = 69  // Remaining width for text (76 - 7)

                    // Calculate text positions
                    let downloadY = itemHeight - 11
                    let uploadY: CGFloat = 2

                    // For dot positioning: text Y is baseline, we need to center dot with text visual center
                    let visualCenterOffset: CGFloat = 3  // Offset to center dot with text visually

                    // Download dot (green) - centered with download text
                    let downloadDotY = downloadY + visualCenterOffset
                    let downloadDotColor = downloadActive ? NSColor.systemGreen : NSColor.darkGray
                    downloadDotColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: xOffset + 1, y: downloadDotY, width: dotSize, height: dotSize)).fill()

                    // Upload dot (red) - centered with upload text
                    let uploadDotY = uploadY + visualCenterOffset
                    let uploadDotColor = uploadActive ? NSColor.systemRed : NSColor.darkGray
                    uploadDotColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: xOffset + 1, y: uploadDotY, width: dotSize, height: dotSize)).fill()

                    // Prepare font and attributes for text measurement
                    let downloadFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
                    let uploadFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)

                    let downloadAttr: [NSAttributedString.Key: Any] = [
                        .font: downloadFont,
                        .foregroundColor: NSColor.systemGreen
                    ]
                    let uploadAttr: [NSAttributedString.Key: Any] = [
                        .font: uploadFont,
                        .foregroundColor: NSColor.systemRed
                    ]

                    // Calculate text widths for right alignment
                    let downloadTextWidth = (downloadText as NSString).size(withAttributes: downloadAttr).width
                    let uploadTextWidth = (uploadText as NSString).size(withAttributes: uploadAttr).width

                    // Draw download speed (green) - RIGHT-aligned
                    let downloadX = xOffset + dotOffset + (textAreaWidth - downloadTextWidth)
                    (downloadText as NSString).draw(at: NSPoint(x: downloadX, y: downloadY), withAttributes: downloadAttr)

                    // Draw upload speed (red) - RIGHT-aligned
                    let uploadX = xOffset + dotOffset + (textAreaWidth - uploadTextWidth)
                    (uploadText as NSString).draw(at: NSPoint(x: uploadX, y: uploadY), withAttributes: uploadAttr)

                    xOffset += 76 + trailingSpacing
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
                        _ = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: batteryText,
                            color: batteryColor,
                            height: itemHeight
                        )
                        xOffset += 52 + trailingSpacing
                    } else if config.style == .percentage {
                        // BATT label on top, percentage below (like CPU)
                        drawPercentageText(
                            at: xOffset,
                            label: "BATT",
                            percentage: Double(battery.level),
                            color: batteryColor,
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += 40 + trailingSpacing
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
                        _ = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: "--%",
                            color: NSColor.secondaryLabelColor,
                            height: itemHeight
                        )
                        xOffset += 52 + trailingSpacing
                    } else if config.style == .percentage {
                        drawPercentageText(
                            at: xOffset,
                            label: "BATT",
                            percentage: 0,
                            color: NSColor.secondaryLabelColor,
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += 40 + trailingSpacing
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
                    _ = drawIconWithText(
                        at: xOffset,
                        iconName: config.customIcon,
                        text: tempText,
                        color: tempColor,
                        height: itemHeight
                    )
                    xOffset += 48 + trailingSpacing
                } else {
                    // TEMP label on top, value below (like CPU percentage style)
                    // Draw label at top
                    let labelAttr: [NSAttributedString.Key: Any] = [
                        .font: labelFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let labelY = itemHeight - 11
                    ("TEMP" as NSString).draw(at: NSPoint(x: xOffset, y: labelY), withAttributes: labelAttr)

                    // Draw value below
                    let tempStr = hasCpuTemp ? "\(Int(cpuTemp))°" : "--°"
                    let valueAttr: [NSAttributedString.Key: Any] = [
                        .font: valueFont,
                        .foregroundColor: tempColor
                    ]
                    let valueY: CGFloat = 2
                    (tempStr as NSString).draw(at: NSPoint(x: xOffset, y: valueY), withAttributes: valueAttr)

                    xOffset += 40 + trailingSpacing
                }

            case .gpu:
                if let gpu = stats.gpu {
                    if config.style == .iconWithText {
                        _ = drawIconWithText(
                            at: xOffset,
                            iconName: config.customIcon,
                            text: "\(Int(gpu.usage))%",
                            color: gpuNSColor(gpu.usage),
                            height: itemHeight
                        )
                        xOffset += 44 + trailingSpacing
                    } else if config.style == .percentage {
                        drawPercentageText(
                            at: xOffset,
                            label: "GPU",
                            percentage: gpu.usage,
                            color: gpuNSColor(gpu.usage),
                            labelFont: labelFont,
                            valueFont: valueFont,
                            height: itemHeight
                        )
                        xOffset += 40 + trailingSpacing
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
                    // GPU not available - show placeholder with 2-row layout (compact)
                    // Label at top
                    let labelAttr: [NSAttributedString.Key: Any] = [
                        .font: labelFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let labelY = itemHeight - 11
                    ("GPU" as NSString).draw(at: NSPoint(x: xOffset, y: labelY), withAttributes: labelAttr)

                    // Value at bottom
                    let attr: [NSAttributedString.Key: Any] = [
                        .font: valueFont,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                    let valueY: CGFloat = 2
                    ("--%" as NSString).draw(at: NSPoint(x: xOffset, y: valueY), withAttributes: attr)
                    xOffset += 40 + trailingSpacing
                }
            }
        }

        image.unlockFocus()

        return image
    }

    // MARK: - Drawing Helpers

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
        let valueY: CGFloat = 2
        (valueStr as NSString).draw(at: NSPoint(x: x, y: valueY), withAttributes: valueAttr)
    }

    // Draw SF Symbol icon with text (Icon + Text style) - horizontal layout
    private func drawIconWithText(at x: CGFloat, iconName: String, text: String, color: NSColor, height: CGFloat) -> CGFloat {
        let iconSize: CGFloat = 12
        let iconTextSpacing: CGFloat = 3

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

        // Draw icon on the left - centered vertically
        // SF Symbols have optical center that's slightly higher than geometric center
        let iconY = centerY - (iconSize / 2) - 0.5  // -0.5 for optical correction

        if let iconImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            if let configuredIcon = iconImage.withSymbolConfiguration(config) {
                let tintedImage = NSImage(size: NSSize(width: iconSize, height: iconSize))
                tintedImage.lockFocus()
                color.set()
                let rect = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
                configuredIcon.draw(in: rect)
                rect.fill(using: .sourceAtop)
                tintedImage.unlockFocus()

                tintedImage.draw(in: NSRect(x: x, y: iconY, width: iconSize, height: iconSize),
                              from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }

        // Draw text on the right - use font baseline for proper alignment
        // Text needs to be positioned from baseline, not bottom
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let baselineOffset = font.descender  // Distance from baseline to bottom of text
        let textY = centerY - (textSize.height / 2) + baselineOffset + 1  // +1 for visual centering

        textStr.draw(at: NSPoint(x: x + iconSize + iconTextSpacing, y: textY), withAttributes: attr)

        return totalWidth
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
