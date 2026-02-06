import Foundation

class MemoryMonitor {
    // Cache physical memory - it never changes
    private lazy var physicalMemory: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    func getMemoryPressure(free: UInt64, total: UInt64, swapUsed: UInt64, swapTotal: UInt64, compressed: UInt64) -> MemoryStats.MemoryPressure {
        // Calculate memory pressure based on multiple factors
        // This approximates Activity Monitor's memory pressure indicator

        let freePercent = Double(free) / Double(total) * 100

        // Factor 1: Swap usage
        var swapPressure = 0.0
        if swapTotal > 0 {
            let swapPercent = Double(swapUsed) / Double(swapTotal) * 100
            // High swap usage indicates memory pressure
            if swapPercent > 50 {
                swapPressure = 30
            } else if swapPercent > 20 {
                swapPressure = 15
            } else if swapPercent > 5 {
                swapPressure = 5
            }
        }

        // Factor 2: Compressed memory (high compression = pressure)
        var compressedPressure = 0.0
        let compressedPercent = Double(compressed) / Double(total) * 100
        if compressedPercent > 20 {
            compressedPressure = 25
        } else if compressedPercent > 10 {
            compressedPressure = 10
        } else if compressedPercent > 5 {
            compressedPressure = 5
        }

        // Factor 3: Free memory
        var freePressure = 0.0
        if freePercent < 5 {
            freePressure = 40
        } else if freePercent < 10 {
            freePressure = 20
        } else if freePercent < 15 {
            freePressure = 10
        }

        // Calculate total pressure score (0-100)
        let totalPressure = swapPressure + compressedPressure + freePressure

        // Determine pressure level based on total score
        if totalPressure >= 50 {
            return .critical
        } else if totalPressure >= 20 {
            return .warning
        } else {
            return .normal
        }
    }

    func getStats() -> MemoryStats {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryStats.empty()
        }

        // Get page size
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let total = physicalMemory
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        
        // Calculate "used" memory like Activity Monitor:
        // Used = App Memory (internal + purgeable) + Wired + Compressed
        // App Memory ≈ active - purgeable
        let purgeable = UInt64(stats.purgeable_count) * UInt64(pageSize)
        
        // Activity Monitor formula: Used = Active + Wired + Compressed - Purgeable
        let appMemory = active >= purgeable ? (active - purgeable) : 0
        let used = min(appMemory + wired + compressed, total)

        // Get swap info
        let (swapTotal, swapUsed) = getSwapInfo()

        // Calculate memory pressure based on multiple factors
        let memoryPressure = getMemoryPressure(
            free: free,
            total: total,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            compressed: compressed
        )

        return MemoryStats(
            total: total,
            used: used,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired,
            compression: compressed,
            swapTotal: swapTotal,
            swapUsed: swapUsed,
            pressure: memoryPressure
        )
    }



    private func getSwapInfo() -> (total: UInt64, used: UInt64) {
        // Use xsw_usage - the actual macOS struct for vm.swapusage
        // Structure layout:
        // - xsu_total: UInt64 (total swap space)
        // - xsu_avail: UInt64 (available swap)
        // - xsu_used: UInt64 (used swap)
        // - xsu_pagesize: UInt64 (page size)
        // - xsu_encrypted: CBool (encryption status)
        
        var buffer = [UInt64](repeating: 0, count: 5)
        var size = MemoryLayout<UInt64>.size * 5
        
        let result = sysctlbyname("vm.swapusage", &buffer, &size, nil, 0)
        
        if result == 0 {
            let swapTotal = buffer[0]
            let swapUsed = buffer[2]  // Third UInt64 is used
            return (swapTotal, swapUsed)
        }
        
        return (0, 0)
    }
}
