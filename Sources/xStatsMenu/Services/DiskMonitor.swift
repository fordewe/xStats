import Foundation
import IOKit
import IOKit.storage

class DiskMonitor {
    private var prevReadBytes: UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var prevTimestamp: CFAbsoluteTime = 0

    func getStats() -> DiskStats {
        var total: UInt64 = 0
        var used: UInt64 = 0
        var free: UInt64 = 0

        // Get root filesystem stats
        var stat = statfs()
        if statfs("/", &stat) == 0 {
            let blockSize = UInt64(stat.f_bsize)
            total = UInt64(stat.f_blocks) * blockSize
            free = UInt64(stat.f_bfree) * blockSize
            used = total - free
        }

        // Get I/O stats
        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0

        getIOStats(readBytes: &readBytes, writeBytes: &writeBytes)

        // Calculate speeds
        let now = CFAbsoluteTimeGetCurrent()
        var readSpeed: Double = 0
        var writeSpeed: Double = 0

        if prevTimestamp > 0 {
            let timeInterval = now - prevTimestamp
            if timeInterval > 0 && readBytes >= prevReadBytes && writeBytes >= prevWriteBytes {
                let readDiff = Double(readBytes - prevReadBytes)
                let writeDiff = Double(writeBytes - prevWriteBytes)

                readSpeed = readDiff / timeInterval
                writeSpeed = writeDiff / timeInterval
            }
        }

        // Update previous values
        prevReadBytes = readBytes
        prevWriteBytes = writeBytes
        prevTimestamp = now

        return DiskStats(
            total: total,
            used: used,
            free: free,
            readBytes: readBytes,
            writeBytes: writeBytes,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed
        )
    }

    private func getIOStats(readBytes: inout UInt64, writeBytes: inout UInt64) {
        // Try multiple IOKit classes for disk I/O statistics
        // Modern macOS uses different class names
        
        // Method 1: Try IOBlockStorageDriver (traditional)
        if tryGetIOStatsFromClass("IOBlockStorageDriver", readBytes: &readBytes, writeBytes: &writeBytes) {
            return
        }
        
        // Method 2: Try IOMedia with leaf nodes
        if tryGetIOStatsFromClass("IOMedia", readBytes: &readBytes, writeBytes: &writeBytes) {
            return
        }
        
        // Method 3: Try AppleAPFSMedia for APFS volumes (Apple Silicon)
        if tryGetIOStatsFromClass("AppleAPFSMedia", readBytes: &readBytes, writeBytes: &writeBytes) {
            return
        }
        
        // Method 4: Try IONVMeController for NVMe drives
        if tryGetIOStatsFromNVMe(readBytes: &readBytes, writeBytes: &writeBytes) {
            return
        }
    }
    
    private func tryGetIOStatsFromClass(_ className: String, readBytes: inout UInt64, writeBytes: inout UInt64) -> Bool {
        let matchingDict = IOServiceMatching(className)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return false
        }

        defer { IOObjectRelease(iterator) }
        
        var foundStats = false
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Check for Statistics dictionary
            if let stats = props["Statistics"] as? [String: Any] {
                if let read = stats["Bytes (Read)"] as? UInt64 ?? stats["BytesRead"] as? UInt64 {
                    readBytes += read
                    foundStats = true
                }
                if let write = stats["Bytes (Write)"] as? UInt64 ?? stats["BytesWritten"] as? UInt64 {
                    writeBytes += write
                    foundStats = true
                }
            }
            
            // Also check for direct properties
            if let read = props["Bytes (Read)"] as? UInt64 {
                readBytes += read
                foundStats = true
            }
            if let write = props["Bytes (Write)"] as? UInt64 {
                writeBytes += write
                foundStats = true
            }
        }
        
        return foundStats
    }
    
    private func tryGetIOStatsFromNVMe(readBytes: inout UInt64, writeBytes: inout UInt64) -> Bool {
        // Search for NVMe drives on Apple Silicon
        let matchingDict = IOServiceMatching("IONVMeController")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return false
        }

        defer { IOObjectRelease(iterator) }
        
        var foundStats = false
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            // Walk children to find block storage
            var childIterator: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &childIterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(childIterator) }
            
            var child = IOIteratorNext(childIterator)
            while child != 0 {
                defer {
                    IOObjectRelease(child)
                    child = IOIteratorNext(childIterator)
                }
                
                var properties: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(child, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let props = properties?.takeRetainedValue() as? [String: Any] else {
                    continue
                }
                
                if let stats = props["Statistics"] as? [String: Any] {
                    if let read = stats["Bytes (Read)"] as? UInt64 ?? stats["BytesRead"] as? UInt64 {
                        readBytes += read
                        foundStats = true
                    }
                    if let write = stats["Bytes (Write)"] as? UInt64 ?? stats["BytesWritten"] as? UInt64 {
                        writeBytes += write
                        foundStats = true
                    }
                }
            }
        }
        
        return foundStats
    }
}
