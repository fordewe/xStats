import Foundation

class StatsCollector: ObservableObject {
    static let shared = StatsCollector()

    private let logger = DebugLogger.shared
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
        // Get real stats from monitors
        let cpu = cpuMonitor.getStats()
        let memory = memoryMonitor.getStats()
        let disk = diskMonitor.getStats()
        let network = networkMonitor.getStats()
        let battery = batteryMonitor.getStats()
        let temperature = temperatureMonitor.getStats()
        let fan = fanMonitor.getStats()
        let gpu = gpuMonitor.getStats()

        // Debug: Log temperature when available (only once when first found)
        if temperature != nil, !hasLoggedTemp {
            if let t = temperature {
                logger.log("[StatsCollector] Temperature sensors found - CPU: \(t.cpu.map { String(format: "%.1f", $0) } ?? "N/A")°C, GPU: \(t.gpu.map { String(format: "%.1f", $0) } ?? "N/A")°C")
                hasLoggedTemp = true
            }
        }

        // Update history buffers
        updateHistory("cpu", cpu.totalUsage)
        updateHistory("memory", memory.usagePercentage)
        updateHistory("network_up", network.uploadSpeed)
        updateHistory("network_down", network.downloadSpeed)
        updateHistory("disk_read", disk.readSpeed)
        updateHistory("disk_write", disk.writeSpeed)
        updateHistory("gpu", gpu?.usage ?? 0)

        let stats = SystemStats(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            gpu: gpu,
            battery: battery,
            temperature: temperature,
            fan: fan
        )

        // Update on main thread
        DispatchQueue.main.async {
            self.currentStats = stats
            // Call the callback if set
            self.onUpdate?(stats)
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
        let enabledTypes = MenuBarSettings.shared.enabledItems.map { "\($0.type)" }
        let bufferKeys = Array(historyBuffers.keys)

        for key in bufferKeys {
            if !enabledTypes.contains(key) {
                historyQueue.async { [weak self] in
                    self?.historyBuffers.removeValue(forKey: key)
                }
            }
        }
    }

    func setSensorsEnabled(_ enabled: Bool) {
        isSensorsEnabled = enabled
    }
}
