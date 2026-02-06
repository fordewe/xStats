# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**xStats** is a native macOS menu bar application that displays real-time system statistics. It's built as an open-source alternative to iStat Menus, featuring a modern horizontal panel layout with real-time graphs and detailed system metrics.

**Tech Stack**: Swift 5.9+, SwiftUI, Swift Package Manager
**Target Platform**: macOS 13.0+ (Ventura and later)

## Build and Run Commands

```bash
# Build the project
swift build

# Run the application (development)
swift run

# Build for release
swift build -c release

# Clean build artifacts
swift build --clean-build

# Build DMG installer
./build-dmg.sh
```

**Note**: This is an accessory app with no dock icon. After running, it appears in the menu bar. Click the menu bar item to open the popover.

## Architecture

The codebase follows a clean SwiftUI architecture with clear separation of concerns:

### Data Flow
```
Monitor Services → StatsCollector → AppDelegate/Views
     (collect)      (conditional)      (display)
                   (lazy load)
```

1. **Monitor Services** (`Services/`) - Collect real-time system data using Mach API, IOKit, SMC, and Metal
2. **StatsCollector** - Singleton that aggregates data and manages history buffers (60 samples = 60 seconds)
3. **Views** - SwiftUI components displaying data with modern dark theme

### Key Components

| Directory | Purpose |
|-----------|---------|
| `App/` | AppDelegate manages NSStatusItem (menu bar) and NSPopover |
| `Models/` | SystemStats data structures, MenuBarSettings, HistoryBuffer (circular buffer) |
| `Services/` | Individual monitors (CPU, Memory, Disk, Network, Battery, Temperature, Fan, GPU) |
| `Views/Panels/` | Horizontal panel views (CPUPanelView, MemoryPanelView, etc.) |
| `Views/Components/` | Reusable UI components (graphs, gauges, charts) |
| `Utilities/` | SMCKit (System Management Controller access), Extensions, Theme |

### Critical Design Patterns

- **Singleton Services**: All monitors use `static let shared` pattern
- **ObservableObject**: `StatsCollector` is the main `@Published` data source
- **EnvironmentObject**: Views access `StatsCollector` via `@EnvironmentObject`
- **History Buffers**: `HistoryBuffer<T>` circular buffer for time-series graph data (60-second history)

## Menu Bar Configuration

The menu bar is highly customizable via `MenuBarSettings` (persisted to UserDefaults):

**Supported Item Types**: CPU, Memory, Disk, Network, Battery, Temperature
**Display Styles**: Percentage, Bar, Graph (sparkline), Icon + Text, Speed, Indicator

Default configuration (defined in `MenuBarSettings.swift:137-144`):
- CPU: percentage
- Memory: bar
- Network: speed
- Battery: iconWithPercentage
- Temperature: text

Menu bar rendering is done in `AppDelegate.swift:createMenuBarImage()` which draws a custom NSImage with labels, bars, and sparklines.

## Popover Layout

The popover uses a **horizontal panel layout**:

- **Size**: 1212x380px (expands to 1010px if no sensor data)
- **Panels**: CPU | Memory | Disk | Network | Sensors (optional)
- **Behavior**: `.transient` - closes when clicking outside

Each panel is ~200px wide with consistent styling via `Theme.swift`.

## System Monitoring Details

### CPU Monitoring (`CPUMonitor.swift`)
- Uses `host_processor_info()` (Mach API) for core-level stats
- Tracks User vs System usage separately
- Detects Apple Silicon E-cores vs P-cores via `sysctlbyname("hw.nperflevels")`
- Frequency from `sysctlbyname("hw.cpufrequency")`

### Memory Monitoring (`MemoryMonitor.swift`)
- Uses `host_statistics64()` for physical memory breakdown
- Tracks: App, Wired, Compressed, Free, Swap
- Calculates memory pressure (normal/warning/critical)

### Disk Monitoring (`DiskMonitor.swift`)
- Usage from `statfs()` system call
- I/O speeds calculated via delta tracking of `IOStorageDriverData`

### Network Monitoring (`NetworkMonitor.swift`)
- Tracks per-interface speeds via `if_data` struct
- Calculates upload/download speeds using delta tracking

### Temperature & Fan (`SMCKit.swift`)
- Direct SMC (System Management Controller) communication via IOKit
- Based on implementation from github.com/exelban/stats
- **Critical**: The `SMCKeyData` struct (lines 6-44) must match kernel layout exactly (80 bytes)

### GPU Monitoring (`GPUMonitor.swift`)
- Apple Silicon: Uses Metal API (`MTLCreateSystemDefaultDevice`)
- Reports: GPU utilization, VRAM usage, temperature

## UI Design System

All visual design is centralized in `Theme.swift`:

- **Colors**: Dark theme with vibrant accents (cyan, blue, purple, green, orange, pink)
- **Gradients**: Pre-defined gradients for graphs (cpuGradient, memoryGradient, networkUpGradient, etc.)
- **Typography**: Rounded design for values (`.valueFont` = 22pt bold rounded)
- **Spacing**: `cardPadding: 14`, `cardSpacing: 10`, `panelSpacing: 8`
- **Dimensions**: `panelWidth: 200`, `panelHeight: 340`

## Adding New Monitoring Capabilities

When adding new system metrics:

1. **Create Monitor** in `Services/` - follow pattern of existing monitors (singleton with `getStats()` method)
2. **Update Models** - add struct to `SystemStats.swift` following existing patterns
3. **Register in StatsCollector** - add monitor instance and call in `updateStats()` (line 52-88)
4. **Create History Buffer** (if graphing needed) - add `HistoryBuffer<Double>` property (line 18-24)
5. **Build View** - create panel or component in `Views/`

## History Buffers

Graphs use `HistoryBuffer<T>` (circular buffer with fixed capacity):

```swift
private let cpuHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
```

Access via getters in `StatsCollector`:
- `getCpuHistory()` → `[Double]`
- `getNetworkUpHistory()`, `getDiskReadHistory()`, etc.

## Performance Optimizations

The app implements lazy monitoring to minimize resource usage:

- **Conditional Monitoring**: Only collect data for enabled menu bar items
- **Dynamic History Buffers**: Allocate history buffers on-demand for active metrics
- **Smart Sensor Monitoring**: Temperature/fan sensors only update when popover is open
- **Property Caching**: Static system properties (CPU cores, disk size, network interfaces) are cached
- **Result**: 30-50% CPU reduction and 20-30% memory reduction vs naive polling

### Implementation Details

**StatsCollector** (`Services/StatsCollector.swift`):
- Uses `MenuBarSettings.enabledItems` to determine which monitors to call
- Dynamic `historyBuffers` dictionary with lazy allocation
- `isSensorsEnabled` flag toggled by popover open/close events
- Automatic cleanup of unused buffers when settings change

**AppDelegate** (`App/AppDelegate.swift`):
- Tracks popover visibility via `NSPopover` notifications
- Enables/disables sensor monitoring based on popover state

**Monitors** (`Services/`):
- CPU: Caches `performanceLevels` and `cpuFrequency`
- Disk: Caches `totalDiskSize`
- Network: Caches interface list with 30-second refresh
- Memory: Already cached `physicalMemory` (lazy var)

### Performance Validation

Build in DEBUG mode to see performance logs:
```bash
swift build
swift run
```

Expected log output:
```
[Performance] updateStats(60) took 2.45ms (interval: 1.00s)
[Performance] updateStats(120) took 2.12ms (interval: 1.00s)
```

Target: <5ms per update for typical 3-4 item configuration

## SMC (System Management Controller) Access

Hardware sensors (temperature, fans) require SMC communication:

- **Service**: `"AppleSMC"` via IOServiceMatching
- **Connection**: io_connect_t with `IOServiceOpen()`
- **Keys**: 4-character codes (e.g., `"TC0C"` for CPU temperature)
- **Data Types**: `ui8` (uint8), `ui16` (uint16), `sp78` (fixed-point)

**Important**: SMC calls must run on background queue to avoid blocking UI. See `SMCKit.swift:58` queue dispatch.

## SwiftUI Notes

- **@EnvironmentObject**: All panel views access `StatsCollector` as environment object
- **NSViewRepresentable**: `EffectMaterialView` wraps NSVisualEffectView for macOS material background
- **NSPopover**: Configured in `AppDelegate.swift:54-62` with `.transient` behavior
- **NSStatusItem**: Menu bar integration via variable length with custom image rendering

## File Organization Reference

```
Sources/xStatsMenu/
├── App/
│   ├── AppDelegate.swift       # Menu bar, popover, updateDisplay()
│   └── main.swift              # Entry point
├── Models/
│   ├── SystemStats.swift       # All stat structs
│   ├── MenuBarSettings.swift   # Menu bar config + persistence
│   └── HistoryBuffer.swift     # Circular buffer for graphs
├── Services/
│   ├── StatsCollector.swift    # Main coordinator, singleton
│   ├── CPUMonitor.swift        # Mach API: host_processor_info
│   ├── MemoryMonitor.swift     # Mach API: host_statistics64
│   ├── DiskMonitor.swift       # statfs, IOKit: IOStorageDriverData
│   ├── NetworkMonitor.swift    # if_data struct, delta tracking
│   ├── BatteryMonitor.swift    # IOKit: IOPSPowerSource
│   ├── TemperatureMonitor.swift # SMCKit wrapper
│   ├── FanMonitor.swift        # SMCKit wrapper
│   └── GPUMonitor.swift        # Metal API (Apple Silicon)
├── Views/
│   ├── PopoverView.swift       # Horizontal panel layout
│   ├── SettingsView.swift      # Menu bar configuration UI
│   ├── Panels/                 # CPUPanelView, MemoryPanelView, etc.
│   └── Components/             # Graphs, gauges, charts
└── Utilities/
    ├── SMCKit.swift            # SMC communication (80-byte struct)
    ├── Extensions.swift        # Swift extensions
    └── Theme.swift             # Design system
```
