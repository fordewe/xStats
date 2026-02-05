import Foundation
import IOKit

// SMC data types - must match kernel struct exactly (80 bytes total)
// Based on working implementation from github.com/exelban/stats
private struct SMCKeyData {
    typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    
    struct vers_t {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }
    
    struct LimitData_t {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }
    
    struct keyInfo_t {
        var dataSize: UInt32 = 0  // IOByteCount32
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    
    var key: UInt32 = 0
    var vers = vers_t()
    var pLimitData = LimitData_t()
    var keyInfo = keyInfo_t()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private enum SMCSelector: UInt8 {
    case kSMCHandleYPCEvent = 2
    case kSMCReadKey = 5
    case kSMCWriteKey = 6
    case kSMCGetKeyFromIndex = 8
    case kSMCGetKeyInfo = 9
}

class SMCKit {
    static let shared = SMCKit()

    private var conn: io_connect_t = 0
    private let queue = DispatchQueue(label: "com.xstats.smc")
    private var isConnected = false
    private let logger = DebugLogger.shared

    // Cached values
    private var cachedFanCount: Int?

    private init() {
        openConnection()
    }

    deinit {
        closeConnection()
    }

    private func openConnection() {
        guard !isConnected else { return }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))

        guard service != 0 else {
            logger.log("[SMCKit] Cannot find AppleSMC service")
            return
        }

        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)

        if result == KERN_SUCCESS {
            isConnected = true
        } else {
            logger.log("[SMCKit] Failed to open AppleSMC connection: \(result)")
        }
    }

    private func closeConnection() {
        if conn != 0 {
            IOServiceClose(conn)
            conn = 0
            isConnected = false
        }
    }
    
    private func fourCharCodeToString(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
    
    private func stringToFourCharCode(_ str: String) -> UInt32 {
        var code: UInt32 = 0
        for char in str.utf8.prefix(4) {
            code = code << 8 | UInt32(char)
        }
        return code
    }

    private func readSMCKey(_ key: String) -> (bytes: [UInt8], dataType: UInt32, dataSize: UInt32)? {
        guard conn != 0 else { return nil }

        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        inputStruct.key = stringToFourCharCode(key)
        inputStruct.data8 = SMCSelector.kSMCGetKeyInfo.rawValue

        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        // Get key info
        var result = IOConnectCallStructMethod(
            conn,
            UInt32(SMCSelector.kSMCHandleYPCEvent.rawValue),
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result == KERN_SUCCESS else { return nil }

        // Check status and result fields
        guard outputStruct.result == 0 else { return nil }

        let keyInfoDataSize = outputStruct.keyInfo.dataSize
        let keyInfoDataType = outputStruct.keyInfo.dataType

        // Read key data
        inputStruct.keyInfo.dataSize = keyInfoDataSize
        inputStruct.data8 = SMCSelector.kSMCReadKey.rawValue

        result = IOConnectCallStructMethod(
            conn,
            UInt32(SMCSelector.kSMCHandleYPCEvent.rawValue),
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result == KERN_SUCCESS else { return nil }

        // Check status again
        guard outputStruct.result == 0 else { return nil }

        // Extract bytes - read raw memory from outputStruct starting at the bytes field offset
        var bytes: [UInt8] = []

        // Calculate offset of 'bytes' field in SMCKeyData struct
        let bytesOffset = MemoryLayout.offset(of: \SMCKeyData.bytes)!

        // Read raw memory from outputStruct
        withUnsafeBytes(of: outputStruct) { ptr in
            let bytePtr = ptr.baseAddress!.advanced(by: bytesOffset).assumingMemoryBound(to: UInt8.self)
            for i in 0..<32 {
                bytes.append(bytePtr[i])
            }
        }

        // Trim to actual data size
        let actualDataSize = Int(keyInfoDataSize)
        if actualDataSize > 0 && actualDataSize <= bytes.count {
            bytes = Array(bytes.prefix(actualDataSize))
        }

        return (bytes,
                keyInfoDataType,
                keyInfoDataSize)
    }

    func readTemperature(key: String) -> Double? {
        guard let result = readSMCKey(key) else { return nil }

        let bytes = result.bytes
        guard bytes.count >= 2 else { return nil }

        // Most temperatures are stored as sp78 (signed fixed point 7.8)
        // or flt (floating point) or fpe2 (fixed point)
        let typeStr = fourCharCodeToString(result.dataType)

        let temp: Double?
        switch typeStr {
        case "sp78": // Signed fixed point 7.8
            let value = Int16(bytes[0]) << 8 | Int16(bytes[1])
            temp = Double(value) / 256.0

        case "fpe2": // Fixed point with 2 fractional bits
            let value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            temp = Double(value) / 4.0

        case "flt ": // Float (little-endian byte order for Apple Silicon)
            if bytes.count >= 4 {
                // Apple Silicon M1/M2/M3 returns floats in little-endian format
                let value = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
                temp = Double(Float(bitPattern: value))
            } else {
                temp = nil
            }

        default:
            // Try sp78 as default
            let value = Int16(bytes[0]) << 8 | Int16(bytes[1])
            temp = Double(value) / 256.0
        }

        // Validate temperature range
        if let t = temp, t > 0 && t < 150 {
            return t
        }

        return nil
    }

    func readFanSpeed(key: String) -> Int? {
        guard let result = readSMCKey(key) else { return nil }

        let bytes = result.bytes
        guard bytes.count >= 2 else { return nil }

        let typeStr = fourCharCodeToString(result.dataType)

        // Handle different data types for fan speed
        switch typeStr {
        case "fpe2": // Fixed point with 2 fractional bits
            let value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Int(value) / 4 // Divide by 4 for fpe2 (shift right 2 bits)

        case "flt ": // Float
            if bytes.count >= 4 {
                let value = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
                let floatValue = Float(bitPattern: value)
                // Validate: must be non-negative, finite, non-NaN, and within Int range
                guard floatValue >= 0,
                      floatValue <= Float(Int.max),
                      !floatValue.isNaN,
                      !floatValue.isInfinite else {
                    return nil
                }
                return Int(floatValue)
            }
            return nil

        case "ui8 ", "ui16", "ui32": // Unsigned integers
            if bytes.count >= 2 {
                let value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
                return Int(value)
            }
            return nil

        case "sp78": // Some fans use this format
            let value = Int16(bytes[0]) << 8 | Int16(bytes[1])
            return Int(value / 256)

        default:
            // Default: try reading as UInt16
            if bytes.count >= 2 {
                let value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
                // If value looks like fpe2 (has fractional bits), divide by 4
                // Otherwise return as-is
                if value > 10000 {
                    return Int(value) / 4
                }
                return Int(value)
            }
            return nil
        }
    }

    func getFanCount() -> Int {
        if let cached = cachedFanCount {
            return cached
        }

        // Try FNum key first
        if let result = readSMCKey("FNum") {
            let bytes = result.bytes
            if bytes.count >= 1 && bytes[0] > 0 {
                let count = Int(bytes[0])
                // Validate by checking if we can actually read fan speeds
                var validCount = 0
                for i in 0..<count {
                    let key = String(format: "F%dAc", i)
                    if let speed = readFanSpeed(key: key), speed > 0 {
                        validCount += 1
                    }
                }
                // If we found valid fans, use the smaller of FNum or validCount
                if validCount > 0 {
                    cachedFanCount = validCount
                    return cachedFanCount!
                }
            }
        }

        // Fallback: Probe for fans directly and validate they have actual speeds
        var validFans: [Int] = []
        for i in 0..<8 {
            // Try different key patterns
            let patterns = ["F%dAc", "F%dMd", "F%dTg"]
            var foundValid = false

            for pattern in patterns {
                let key = String(format: pattern, i)
                if let speed = readFanSpeed(key: key), speed > 0 {
                    validFans.append(i)
                    foundValid = true
                    break
                }
            }

            if !foundValid {
                // Stop if we didn't find a valid fan
                // But allow gaps (some Macs have non-sequential fan numbers)
                if validFans.isEmpty && i > 1 {
                    // If we haven't found any fans by index 2, probably no fans
                    break
                }
            }
        }

        cachedFanCount = validFans.count
        return cachedFanCount!
    }
    
    // Get all available temperature keys
    func getAvailableTemperatureKeys() -> [String] {
        // Common temperature sensor keys for Apple Silicon and Intel Macs
        let commonKeys = [
            // CPU Temperature keys
            "TC0P", "TC0D", "TC0E", "TC0F", "TC1C", "TC2C", "TC3C", "TC4C",
            "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0b",  // Apple Silicon
            // GPU Temperature keys
            "TG0P", "TG0D", "TG0T", "Tg05", "Tg0D", "Tg0P",
            // Memory
            "Tm0P", "TM0P", "TM0S",
            // Battery
            "TB0T", "TB1T", "TB2T",
            // SSD/Storage
            "TH0P", "TH0a", "TH0b",
            // Ambient
            "TA0P", "TA0S", "TA1P"
        ]
        
        var availableKeys: [String] = []
        for key in commonKeys {
            if readSMCKey(key) != nil {
                availableKeys.append(key)
            }
        }
        return availableKeys
    }
}
