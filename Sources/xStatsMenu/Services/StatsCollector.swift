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

    // History buffers (60 samples = 60 seconds at 1s interval)
    private let cpuHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let memoryHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let networkUpHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let networkDownHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let diskReadHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let diskWriteHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)
    private let gpuHistory = HistoryBuffer<Double>(capacity: 60, defaultValue: 0)

    private var isRunning = false
    var onUpdate: ((SystemStats) -> Void)?

    private init() {
        // StatsCollector initialized
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
        cpuHistory.add(cpu.totalUsage)
        memoryHistory.add(memory.usagePercentage)
        networkUpHistory.add(network.uploadSpeed)
        networkDownHistory.add(network.downloadSpeed)
        diskReadHistory.add(disk.readSpeed)
        diskWriteHistory.add(disk.writeSpeed)
        gpuHistory.add(gpu?.usage ?? 0)

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
        cpuHistory.getValues()
    }

    func getMemoryHistory() -> [Double] {
        memoryHistory.getValues()
    }

    func getNetworkUpHistory() -> [Double] {
        networkUpHistory.getValues()
    }

    func getNetworkDownHistory() -> [Double] {
        networkDownHistory.getValues()
    }

    func getDiskReadHistory() -> [Double] {
        diskReadHistory.getValues()
    }

    func getDiskWriteHistory() -> [Double] {
        diskWriteHistory.getValues()
    }

    func getGpuHistory() -> [Double] {
        gpuHistory.getValues()
    }

    func getCurrentStats() -> SystemStats {
        return currentStats
    }
}
