import Foundation
import IOKit.ps

class BatteryMonitor {
    // Cache cycle count - only update every 60 seconds
    private var cachedCycleCount: Int = 0
    private var lastCycleCountUpdate: CFAbsoluteTime = 0
    private let cycleCountUpdateInterval: CFAbsoluteTime = 60
    
    func getStats() -> BatteryStats? {
        // First try IOPMPowerSource for basic info
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Only process batteries
            guard let type = description[kIOPSTypeKey as String] as? String,
                  type == kIOPSInternalBatteryType as String else {
                continue
            }

            let level = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSource = description[kIOPSPowerSourceStateKey as String] as? String ?? ""
            let isPlugged = powerSource == (kIOPSACPowerValue as String)
            let health = description[kIOPSBatteryHealthKey as String] as? String ?? ""

            var timeRemaining: Int?
            if isCharging {
                if let time = description[kIOPSTimeToFullChargeKey as String] as? Int, time > 0 {
                    timeRemaining = time
                }
            } else {
                if let time = description[kIOPSTimeToEmptyKey as String] as? Int, time > 0 {
                    timeRemaining = time
                }
            }
            
            // Get cycle count from IOKit (cached, updates every 60s)
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastCycleCountUpdate > cycleCountUpdateInterval {
                cachedCycleCount = fetchBatteryCycleCount()
                lastCycleCountUpdate = now
            }
            let cycleCount = cachedCycleCount
            
            return BatteryStats(
                level: level,
                isCharging: isCharging,
                isPlugged: isPlugged,
                timeRemaining: timeRemaining,
                health: healthPercentage(from: health),
                cycleCount: cycleCount
            )
        }

        return nil
    }
    
    // Fetch battery cycle count from IOKit
    private func fetchBatteryCycleCount() -> Int {
        var iterator: io_iterator_t = 0
        
        let matchDict = IOServiceMatching("AppleSmartBattery")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            var props: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
            
            guard result == KERN_SUCCESS,
                  let properties = props?.takeRetainedValue() as? [String: Any] else {
                continue
            }
            
            // Try different keys for cycle count
            if let cycles = properties["CycleCount"] as? Int {
                return cycles
            }
            
            if let cycles = properties["BatteryCycleCount"] as? Int {
                return cycles
            }
        }
        
        return 0
    }

    private func healthPercentage(from health: String) -> Int {
        switch health {
        case "Good":
            return 100
        case "Fair":
            return 60
        case "Poor":
            return 30
        default:
            return 100
        }
    }
}
