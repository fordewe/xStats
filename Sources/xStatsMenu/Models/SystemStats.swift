import Foundation

struct SystemStats {
    var cpu: CPUStats
    var memory: MemoryStats
    var disk: DiskStats
    var network: NetworkStats
    var gpu: GPUStats?
    var battery: BatteryStats?
    var temperature: TemperatureStats?
    var fan: FanStats?

    static func empty() -> SystemStats {
        SystemStats(
            cpu: CPUStats.empty(),
            memory: MemoryStats.empty(),
            disk: DiskStats.empty(),
            network: NetworkStats.empty(),
            gpu: nil,
            battery: nil,
            temperature: nil,
            fan: nil
        )
    }
}

struct CPUStats {
    var totalUsage: Double
    var perCoreUsage: [Double]
    var frequency: Int64

    // NEW FIELDS
    var userUsage: Double           // User-space CPU usage
    var systemUsage: Double         // Kernel/system CPU usage
    var efficiencyCoreUsage: Double? // E-core usage (Apple Silicon)
    var performanceCoreUsage: Double? // P-core usage (Apple Silicon)
    var temperature: Double?        // CPU temperature in Celsius

    static func empty() -> CPUStats {
        CPUStats(
            totalUsage: 0,
            perCoreUsage: [],
            frequency: 0,
            userUsage: 0,
            systemUsage: 0,
            efficiencyCoreUsage: nil,
            performanceCoreUsage: nil,
            temperature: nil
        )
    }
}

struct MemoryStats {
    var total: UInt64
    var used: UInt64
    var free: UInt64
    var active: UInt64
    var inactive: UInt64
    var wired: UInt64
    var compression: UInt64
    var swapTotal: UInt64
    var swapUsed: UInt64

    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var pressure: MemoryPressure {
        let freePercent = Double(free) / Double(total) * 100
        if freePercent < 10 { return .critical }
        if freePercent < 20 { return .warning }
        return .normal
    }

    enum MemoryPressure {
        case normal, warning, critical
    }

    static func empty() -> MemoryStats {
        MemoryStats(
            total: 0, used: 0, free: 0, active: 0,
            inactive: 0, wired: 0, compression: 0,
            swapTotal: 0, swapUsed: 0
        )
    }
}

struct DiskStats {
    var total: UInt64
    var used: UInt64
    var free: UInt64
    var readBytes: UInt64
    var writeBytes: UInt64
    var readSpeed: Double      // Bytes/second
    var writeSpeed: Double     // Bytes/second

    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    static func empty() -> DiskStats {
        DiskStats(
            total: 0,
            used: 0,
            free: 0,
            readBytes: 0,
            writeBytes: 0,
            readSpeed: 0,
            writeSpeed: 0
        )
    }
}

struct NetworkStats {
    var uploadSpeed: Double
    var downloadSpeed: Double
    var totalUpload: UInt64
    var totalDownload: UInt64
    var ipAddress: String?
    var interfaceName: String?

    static func empty() -> NetworkStats {
        NetworkStats(
            uploadSpeed: 0,
            downloadSpeed: 0,
            totalUpload: 0,
            totalDownload: 0,
            ipAddress: nil,
            interfaceName: nil
        )
    }
}

struct BatteryStats {
    var level: Int
    var isCharging: Bool
    var isPlugged: Bool
    var timeRemaining: Int?
    var health: Int
    var cycleCount: Int
}

struct TemperatureStats {
    var cpu: Double?
    var gpu: Double?
    var battery: Double?
    var memory: Double?
}

struct FanStats {
    var speeds: [Int]
    var count: Int
}

struct GPUStats {
    var usage: Double
    var temperature: Double?
    var memoryUsed: UInt64?
    var memoryTotal: UInt64?
    var frequency: Int64?

    static func empty() -> GPUStats {
        GPUStats(
            usage: 0,
            temperature: nil,
            memoryUsed: nil,
            memoryTotal: nil,
            frequency: nil
        )
    }
}
