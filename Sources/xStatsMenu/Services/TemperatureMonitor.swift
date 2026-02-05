import Foundation
import IOKit

class TemperatureMonitor {
    private let smc = SMCKit.shared
    private let logger = DebugLogger.shared
    private var cachedCPUKey: String?
    private var cachedGPUKey: String?
    
    // Apple Silicon CPU temperature keys (in order of preference)
    private let applesilIconCPUKeys = [
        // M1 Pro/Max/Ultra specific keys
        "TCGC", "TCXC", "TCXc", "TCSc", "TCSA", "TCXr", "TCXZ",
        // Additional M1/M2 keys
        "TC0C", "TC1C", "TC2C", "TC3C", "TC4C",
        // General Apple Silicon keys
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0b",
        // More potential keys
        "TC0p", "TC1p", "TC2p"
    ]
    // Intel CPU temperature keys
    private let intelCPUKeys = ["TC0P", "TC0D", "TC0E", "TC0F", "TC1C"]
    // GPU temperature keys
    private let gpuKeys = [
        // M1 Pro/Max GPU keys
        "TGDD", "TGDE", "TGDK", "TGDG", "TGHG",
        // Additional GPU keys
        "TG0D", "TG1D", "TG2D",
        // General GPU keys
        "Tg05", "Tg0D", "Tg0P", "TG0P", "TG0D", "TG0T"
    ]
    // Battery temperature keys
    private let batteryKeys = ["TB0T", "TB1T", "TB2T"]
    // Memory/VRM temperature keys
    private let memoryKeys = ["Tm0P", "TM0P", "TM0S", "TM0p", "TM1p", "TMBS"]

    func getStats() -> TemperatureStats? {
        let cpu = getCPUTemperature()
        let gpu = getGPUTemperature()
        let battery = getBatteryTemperature()
        let memory = getMemoryTemperature()

        // Avoid returning synthetic/guessed values.
        // If no real sensor value is available, return nil.
        if cpu == nil && gpu == nil && battery == nil && memory == nil {
            return nil
        }

        return TemperatureStats(
            cpu: cpu,
            gpu: gpu,
            battery: battery,
            memory: memory
        )
    }
    
    private func getCPUTemperature() -> Double? {
        // Use cached key if available
        if let key = cachedCPUKey, let temp = smc.readTemperature(key: key), temp > 0 && temp < 150 {
            return temp
        }

        // Try Apple Silicon keys first
        for key in applesilIconCPUKeys {
            if let temp = smc.readTemperature(key: key), temp > 0 && temp < 150 {
                logger.log("[TempMonitor] Found valid CPU key: \(key) = \(String(format: "%.1f", temp))°C")
                cachedCPUKey = key
                return temp
            }
        }

        // Try Intel keys
        for key in intelCPUKeys {
            if let temp = smc.readTemperature(key: key), temp > 0 && temp < 150 {
                logger.log("[TempMonitor] Found valid Intel CPU key: \(key) = \(String(format: "%.1f", temp))°C")
                cachedCPUKey = key
                return temp
            }
        }

        return nil
    }

    // Public method to get a list of all keys we're trying
    func getDebugKeys() -> (appleSilicon: [String], intel: [String]) {
        return (applesilIconCPUKeys, intelCPUKeys)
    }
    
    private func getGPUTemperature() -> Double? {
        // Use cached key if available
        if let key = cachedGPUKey, let temp = smc.readTemperature(key: key), temp > 0 && temp < 150 {
            return temp
        }
        
        for key in gpuKeys {
            if let temp = smc.readTemperature(key: key), temp > 0 && temp < 150 {
                cachedGPUKey = key
                return temp
            }
        }
        
        return nil
    }
    
    private func getBatteryTemperature() -> Double? {
        for key in batteryKeys {
            if let temp = smc.readTemperature(key: key), temp > 0 && temp < 80 {
                return temp
            }
        }
        return nil
    }

    private func getMemoryTemperature() -> Double? {
        for key in memoryKeys {
            if let temp = smc.readTemperature(key: key), temp > 0 && temp < 120 {
                return temp
            }
        }
        return nil
    }
    
    // Debug: Get all available temperature keys
    func debugAvailableKeys() -> [String: Double] {
        var result: [String: Double] = [:]
        let keys = smc.getAvailableTemperatureKeys()
        for key in keys {
            if let temp = smc.readTemperature(key: key) {
                result[key] = temp
            }
        }
        return result
    }
}
