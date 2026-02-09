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

    private var isRunning = false
    var onUpdate: ((SystemStats) -> Void)?

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

        // Always collect all stats for popover (popover shows all panels)
        // Note: Temperature/Fan always collected to avoid 0-values on first popover open
        var cpuStats = cpuMonitor.getStats()
        var gpuStats = gpuMonitor.getStats()
        let tempStats = temperatureMonitor.getStats()

        // Inject temperature from single TemperatureMonitor read (avoids 3x redundant SMC calls)
        if let temps = tempStats {
            cpuStats.temperature = temps.cpu
            gpuStats?.temperature = temps.gpu
        }

        let stats = SystemStats(
            cpu: cpuStats,
            memory: memoryMonitor.getStats(),
            disk: diskMonitor.getStats(),
            network: networkMonitor.getStats(),
            gpu: gpuStats,
            battery: batteryMonitor.getStats(),
            temperature: tempStats,
            fan: fanMonitor.getStats()
        )

        // Batch all history buffer updates in a single dispatch
        let gpuUsage = stats.gpu?.usage
        historyQueue.async { [weak self] in
            guard let self = self else { return }
            self.getHistoryBuffer(for: "cpu").add(stats.cpu.totalUsage)
            self.getHistoryBuffer(for: "memory").add(stats.memory.usagePercentage)
            self.getHistoryBuffer(for: "disk_read").add(stats.disk.readSpeed)
            self.getHistoryBuffer(for: "disk_write").add(stats.disk.writeSpeed)
            self.getHistoryBuffer(for: "network_up").add(stats.network.uploadSpeed)
            self.getHistoryBuffer(for: "network_down").add(stats.network.downloadSpeed)
            if let gpuUsage = gpuUsage {
                self.getHistoryBuffer(for: "gpu").add(gpuUsage)
            }
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

    // History getters (synchronized with historyQueue for thread safety)
    func getCpuHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "cpu").getValues() }
    }

    func getMemoryHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "memory").getValues() }
    }

    func getNetworkUpHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "network_up").getValues() }
    }

    func getNetworkDownHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "network_down").getValues() }
    }

    func getDiskReadHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "disk_read").getValues() }
    }

    func getDiskWriteHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "disk_write").getValues() }
    }

    func getGpuHistory() -> [Double] {
        historyQueue.sync { getHistoryBuffer(for: "gpu").getValues() }
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

}
