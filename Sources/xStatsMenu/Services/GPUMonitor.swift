import Foundation
import Metal
import IOKit

class GPUMonitor {
    private var fallbackDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

    func getStats() -> GPUStats? {
        // Primary source: IOAccelerator PerformanceStatistics (real GPU utilization on macOS).
        if let ioStats = getIOAcceleratorStats() {
            return ioStats
        }

        // Fallback: Metal memory stats only (usage unavailable -> 0).
        return getMetalFallbackStats()
    }

    private func getIOAcceleratorStats() -> GPUStats? {
        let classNames = ["IOAccelerator", "AGXAccelerator"]
        for className in classNames {
            if let stats = readStats(fromClass: className) {
                return stats
            }
        }
        return nil
    }

    private func readStats(fromClass className: String) -> GPUStats? {
        let matchingDict = IOServiceMatching(className)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service,
                &properties,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            guard let perf = props["PerformanceStatistics"] as? [String: Any] else {
                continue
            }

            let usage = firstDouble(
                in: perf,
                keys: [
                    "Device Utilization %",
                    "GPU Activity(%)",
                    "GPU Activity",
                    "GPU Busy"
                ]
            ) ?? max(
                firstDouble(in: perf, keys: ["Renderer Utilization %"]) ?? 0,
                firstDouble(in: perf, keys: ["Tiler Utilization %"]) ?? 0
            )

            let memoryUsed = firstUInt64(
                in: perf,
                keys: ["In use system memory", "In use system memory (driver)"]
            )
            let memoryTotal = firstUInt64(in: perf, keys: ["Alloc system memory"])

            return GPUStats(
                usage: min(max(usage, 0), 100),
                temperature: nil,
                memoryUsed: memoryUsed,
                memoryTotal: memoryTotal,
                frequency: nil
            )
        }

        return nil
    }

    private func getMetalFallbackStats() -> GPUStats? {
        guard let device = fallbackDevice ?? MTLCreateSystemDefaultDevice() else {
            return nil
        }
        fallbackDevice = device

        let memoryUsed = device.currentAllocatedSize > 0 ? UInt64(device.currentAllocatedSize) : nil
        let memoryTotal = device.recommendedMaxWorkingSetSize > 0 ? UInt64(device.recommendedMaxWorkingSetSize) : nil

        return GPUStats(
            usage: 0,
            temperature: nil,
            memoryUsed: memoryUsed,
            memoryTotal: memoryTotal,
            frequency: nil
        )
    }

    private func firstDouble(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let raw = dictionary[key] else { continue }
            if let number = raw as? NSNumber {
                return number.doubleValue
            }
            if let value = raw as? Double {
                return value
            }
            if let value = raw as? Int {
                return Double(value)
            }
            if let text = raw as? String, let parsed = Double(text) {
                return parsed
            }
        }
        return nil
    }

    private func firstUInt64(in dictionary: [String: Any], keys: [String]) -> UInt64? {
        for key in keys {
            guard let raw = dictionary[key] else { continue }
            if let number = raw as? NSNumber {
                let value = number.int64Value
                return value >= 0 ? UInt64(value) : nil
            }
            if let value = raw as? UInt64 {
                return value
            }
            if let value = raw as? Int {
                return value >= 0 ? UInt64(value) : nil
            }
            if let text = raw as? String, let parsed = UInt64(text) {
                return parsed
            }
        }
        return nil
    }
}
