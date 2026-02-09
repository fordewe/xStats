import Foundation

class CPUMonitor {
    private var prevCPUInfo: processor_info_array_t?
    private var prevNumCpuInfo: mach_msg_type_number_t = 0
    private var prevNumCPUs: natural_t = 0
    private let lock = NSLock()

    // For user/system split
    private var prevTotalUser: Double = 0
    private var prevTotalSystem: Double = 0
    private var prevTotalIdle: Double = 0
    
    // Cached values
    private lazy var cpuFrequency: Int64 = {
        var frequency: Int64 = 0
        var size = MemoryLayout<Int64>.size
        sysctlbyname("hw.cpufrequency", &frequency, &size, nil, 0)
        return frequency
    }()
    private lazy var perfLevels: Int = {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        if sysctlbyname("hw.nperflevels", &value, &size, nil, 0) == 0 {
            return value
        }
        return 1
    }()
    private lazy var efficiencyCoreCount: Int = {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        if sysctlbyname("hw.perflevel0.physicalcpu", &value, &size, nil, 0) == 0 {
            return value
        }
        return 0
    }()

    func getStats() -> CPUStats {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result: kern_return_t = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )

        if result != KERN_SUCCESS {
            return CPUStats.empty()
        }

        lock.lock()
        defer { lock.unlock() }

        var perCoreUsage: [Double] = []
        var totalUser = 0.0
        var totalSystem = 0.0
        var totalIdle = 0.0

        // Check for Apple Silicon hybrid cores
        let hasHybridCores = perfLevels > 1

        for cpu in 0..<Int(numCPUs) {
            let offset = cpu * Int(CPU_STATE_MAX)

            let user = Double(cpuInfo![offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo![offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo![offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo![offset + Int(CPU_STATE_NICE)])

            let inUse = user + system + nice
            let total = inUse + idle

            if let prevInfo = prevCPUInfo, prevNumCpuInfo > 0 {
                let prevUser = Double(prevInfo[offset + Int(CPU_STATE_USER)])
                let prevSystem = Double(prevInfo[offset + Int(CPU_STATE_SYSTEM)])
                let prevIdle = Double(prevInfo[offset + Int(CPU_STATE_IDLE)])
                let prevNice = Double(prevInfo[offset + Int(CPU_STATE_NICE)])

                let prevInUse = prevUser + prevSystem + prevNice
                let prevTotal = prevInUse + prevIdle

                let diffInUse = inUse - prevInUse
                let diffTotal = total - prevTotal

                if diffTotal > 0 {
                    let usage = (diffInUse / diffTotal) * 100
                    perCoreUsage.append(usage)
                } else {
                    perCoreUsage.append(0)
                }
            } else {
                perCoreUsage.append(0)
            }

            totalUser += user
            totalSystem += system
            totalIdle += idle
        }

        var totalUsage = 0.0
        var userUsage: Double = 0
        var systemUsage: Double = 0

        // Calculate user/system split
        if prevTotalUser > 0 || prevTotalSystem > 0 {
            let diffUser = totalUser - prevTotalUser
            let diffSystem = totalSystem - prevTotalSystem
            let diffTotal = (totalUser + totalSystem + totalIdle) - (prevTotalUser + prevTotalSystem + prevTotalIdle)

            if diffTotal > 0 {
                totalUsage = ((diffUser + diffSystem) / diffTotal) * 100
                userUsage = (diffUser / diffTotal) * 100
                systemUsage = (diffSystem / diffTotal) * 100
            }
        }

        // Update previous values
        prevTotalUser = totalUser
        prevTotalSystem = totalSystem
        prevTotalIdle = totalIdle

        // Calculate E/P core usage for Apple Silicon
        var efficiencyCoreUsage: Double?
        var performanceCoreUsage: Double?

        if hasHybridCores && !perCoreUsage.isEmpty {
            let eCoresCount = efficiencyCoreCount
            let pCoresCount = Int(numCPUs) - eCoresCount

            if eCoresCount > 0 && pCoresCount > 0 {
                // First eCoresCount cores are E-cores (typical Apple Silicon layout)
                let eCoreUsages = perCoreUsage.prefix(Int(eCoresCount))
                let pCoreUsages = perCoreUsage.suffix(Int(pCoresCount))

                efficiencyCoreUsage = eCoreUsages.reduce(0, +) / Double(eCoreUsages.count)
                performanceCoreUsage = pCoreUsages.reduce(0, +) / Double(pCoreUsages.count)
            }
        }

        // Store current for next iteration
        if prevCPUInfo != nil {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prevCPUInfo)), vm_size_t(Int(prevNumCpuInfo) * MemoryLayout<integer_t>.size))
        }

        prevNumCPUs = numCPUs
        prevNumCpuInfo = numCpuInfo
        prevCPUInfo = cpuInfo

        return CPUStats(
            totalUsage: totalUsage,
            perCoreUsage: perCoreUsage,
            frequency: cpuFrequency,
            userUsage: userUsage,
            systemUsage: systemUsage,
            efficiencyCoreUsage: efficiencyCoreUsage,
            performanceCoreUsage: performanceCoreUsage,
            temperature: nil
        )
    }
}
