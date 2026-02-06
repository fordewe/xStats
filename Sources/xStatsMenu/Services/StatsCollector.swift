import Foundation

class StatsCollector: ObservableObject {
    static let shared = StatsCollector()

    private let logger = DebugLogger.shared
    private let menuBarSettings = MenuBarSettings.shared
    private var hasLoggedTemp = false
    #if DEBUG
    private var lastUpdateTime: Date = Date()
    private var updateCount: Int = 0
    #endif
    @Published private(set) var currentStats: SystemStats = .empty()

    // Monitor services
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let temperatureMonitor = TemperatureMonitor()
    private let fanMonitor = FanMonitor()
    private let gpuMonitor = GPUMonitor()

    // Dynamic history buffers (only allocate for enabled metrics)
    private var historyBuffers: [String: HistoryBuffer<Double>] = [:]
    private let historyQueue = DispatchQueue(label: "com.xstats.history", qos: .utility)

    private let historyKeyMapping: [MenuBarItemType: [String]] = [
        .cpu: ["cpu"],
        .memory: ["memory"],
        .network: ["network_up", "network_down"],
        .disk: ["disk_read", "disk_write"],
        .gpu: ["gpu"]
    ]

    private func getHistoryBuffer(for type: String) -> HistoryBuffer<Double> {
        if let existing = historyBuffers[type] {
            return existing
        }
        let buffer = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
        historyBuffers[type] = buffer
        return buffer
    }

    private func updateHistory(_ key: String, value: Double) {
        historyQueue.async { [weak self] in
            self?.getHistoryBuffer(for: key).add(value)
        }
    }

    private var isRunning = false
    var onUpdate: ((SystemStats) -> Void)?
    private var isSensorsEnabled = false

    private init() {
        setupSettingsObserver()
    }

    func startMonitoring() {
        isRunning = true
        scheduleNextUpdate()
    }

    func stopMonitoring() {
        isRunning = false
    }

    private func scheduleNextUpdate() {
        guard isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.updateStats()
            self.scheduleNextUpdate()
        }
    }

    private func updateStats() {
        #if DEBUG
        let startTime = Date()
        #endif

        let enabledItems = menuBarSettings.enabledItems
        let enabledTypes = Set(enabledItems.map { $0.type })

        // Always collect all stats for popover (popover shows all panels)
        let stats = SystemStats(
            cpu: cpuMonitor.getStats(),
            memory: memoryMonitor.getStats(),
            disk: diskMonitor.getStats(),
            network: networkMonitor.getStats(),
            gpu: gpuMonitor.getStats(),
            battery: batteryMonitor.getStats(),
            temperature: isSensorsEnabled ? temperatureMonitor.getStats() : nil,
            fan: isSensorsEnabled ? fanMonitor.getStats() : nil
        )

        // Only update history buffers for menu bar enabled items (optimization)
        if enabledTypes.contains(.cpu) {
            updateHistory("cpu", value: stats.cpu.totalUsage)
        }

        if enabledTypes.contains(.memory) {
            updateHistory("memory", value: stats.memory.usagePercentage)
        }

        if enabledTypes.contains(.disk) {
            updateHistory("disk_read", value: stats.disk.readSpeed)
            updateHistory("disk_write", value: stats.disk.writeSpeed)
        }

        if enabledTypes.contains(.network) {
            updateHistory("network_up", value: stats.network.uploadSpeed)
            updateHistory("network_down", value: stats.network.downloadSpeed)
        }

        if enabledTypes.contains(.gpu), let gpu = stats.gpu {
            updateHistory("gpu", value: gpu.usage)
        }

        // Debug: Log temperature when available (only once when first found)
        if let temperature = stats.temperature, !hasLoggedTemp {
            logger.log("[StatsCollector] Temperature sensors found - CPU: \(temperature.cpu.map { String(format: "%.1f", $0) } ?? "N/A")°C, GPU: \(temperature.gpu.map { String(format: "%.1f", $0) } ?? "N/A")°C")
            hasLoggedTemp = true
        }

        #if DEBUG
        let elapsed = Date().timeIntervalSince(startTime)
        let interval = Date().timeIntervalSince(lastUpdateTime)
        lastUpdateTime = Date()
        updateCount += 1

        // Log every 60 updates (1 minute) or if update is slow
        if updateCount % 60 == 0 || elapsed > 0.1 {
            logger.log("[Performance] updateStats(\(updateCount)) took \(String(format: "%.2f", elapsed * 1000))ms (interval: \(String(format: "%.2f", interval))s)")
        }
        #endif

        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentStats = stats
            // Call the callback if set
            self?.onUpdate?(stats)
        }
    }

    // History getters
    func getCpuHistory() -> [Double] {
        getHistoryBuffer(for: "cpu").getValues()
    }

    func getMemoryHistory() -> [Double] {
        getHistoryBuffer(for: "memory").getValues()
    }

    func getNetworkUpHistory() -> [Double] {
        getHistoryBuffer(for: "network_up").getValues()
    }

    func getNetworkDownHistory() -> [Double] {
        getHistoryBuffer(for: "network_down").getValues()
    }

    func getDiskReadHistory() -> [Double] {
        getHistoryBuffer(for: "disk_read").getValues()
    }

    func getDiskWriteHistory() -> [Double] {
        getHistoryBuffer(for: "disk_write").getValues()
    }

    func getGpuHistory() -> [Double] {
        getHistoryBuffer(for: "gpu").getValues()
    }

    func getCurrentStats() -> SystemStats {
        return currentStats
    }

    // MARK: - Settings Management

    func setupSettingsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .menuBarSettingsChanged,
            object: nil
        )
    }

    @objc private func settingsChanged() {
        // Clean up unused history buffers
        let enabledItems = MenuBarSettings.shared.enabledItems
        let enabledTypes = Set(enabledItems.map { $0.type })

        var validKeys: Set<String> = []
        for type in enabledTypes {
            if let keys = historyKeyMapping[type] {
                validKeys.formUnion(keys)
            }
        }

        let bufferKeys = Set(historyBuffers.keys)
        let keysToRemove = bufferKeys.subtracting(validKeys)

        for key in keysToRemove {
            historyQueue.async { [weak self] in
                self?.historyBuffers.removeValue(forKey: key)
            }
        }
    }

    func setSensorsEnabled(_ enabled: Bool) {
        isSensorsEnabled = enabled
    }
}
