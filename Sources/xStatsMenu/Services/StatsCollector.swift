import Foundation

class StatsCollector: ObservableObject {
    static let shared = StatsCollector()

    private let logger = DebugLogger.shared
    private let menuBarSettings = MenuBarSettings.shared
    private var hasLoggedTemp = false
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
        let enabledItems = menuBarSettings.enabledItems
        let enabledTypes = Set(enabledItems.map { $0.type })

        // Initialize stats with empty values
        var stats = SystemStats.empty()

        // CPU monitoring
        if enabledTypes.contains(.cpu) {
            let cpu = cpuMonitor.getStats()
            stats.cpu = cpu
            updateHistory("cpu", value: cpu.totalUsage)
        }

        // Memory monitoring
        if enabledTypes.contains(.memory) {
            let memory = memoryMonitor.getStats()
            stats.memory = memory
            updateHistory("memory", value: memory.usagePercentage)
        }

        // Disk monitoring
        if enabledTypes.contains(.disk) {
            let disk = diskMonitor.getStats()
            stats.disk = disk
            updateHistory("disk_read", value: disk.readSpeed)
            updateHistory("disk_write", value: disk.writeSpeed)
        }

        // Network monitoring
        if enabledTypes.contains(.network) {
            let network = networkMonitor.getStats()
            stats.network = network
            updateHistory("network_up", value: network.uploadSpeed)
            updateHistory("network_down", value: network.downloadSpeed)
        }

        // Battery monitoring (always check - lightweight)
        if enabledTypes.contains(.battery) {
            stats.battery = batteryMonitor.getStats()
        }

        // GPU monitoring
        if enabledTypes.contains(.gpu) {
            let gpu = gpuMonitor.getStats()
            if let gpu = gpu {
                stats.gpu = gpu
                updateHistory("gpu", value: gpu.usage)
            }
        }

        // Temperature monitoring (expensive - only when enabled OR sensors needed)
        let needsTemp = enabledTypes.contains(.temperature) || isSensorsEnabled
        if needsTemp {
            stats.temperature = temperatureMonitor.getStats()
        }

        // Fan monitoring (expensive - only when sensors needed)
        if isSensorsEnabled {
            stats.fan = fanMonitor.getStats()
        }

        // Debug: Log temperature when available (only once when first found)
        if let temperature = stats.temperature, !hasLoggedTemp {
            logger.log("[StatsCollector] Temperature sensors found - CPU: \(temperature.cpu.map { String(format: "%.1f", $0) } ?? "N/A")°C, GPU: \(temperature.gpu.map { String(format: "%.1f", $0) } ?? "N/A")°C")
            hasLoggedTemp = true
        }

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
