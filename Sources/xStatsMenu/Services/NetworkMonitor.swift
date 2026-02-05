import Foundation
import Darwin

class NetworkMonitor {
    private var prevUpload: UInt64 = 0
    private var prevDownload: UInt64 = 0
    private var prevTimestamp: CFAbsoluteTime = 0

    func getStats() -> NetworkStats {
        var upload: UInt64 = 0
        var download: UInt64 = 0
        var totalUpload: UInt64 = 0
        var totalDownload: UInt64 = 0
        var ipv4Candidate: (interface: String, address: String, score: Int)?
        var ipv6Candidate: (interface: String, address: String, score: Int)?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            return NetworkStats.empty()
        }

        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            let interface = current.pointee
            guard let addr = interface.ifa_addr else { continue }
            let addrFamily = addr.pointee.sa_family
            guard let namePtr = interface.ifa_name else { continue }
            let name = String(cString: namePtr)

            if addrFamily == UInt8(AF_LINK) {
                // Skip loopback
                if name == "lo0" { continue }

                if let data = interface.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    upload += UInt64(stats.ifi_obytes)
                    download += UInt64(stats.ifi_ibytes)
                }
                continue
            }

            // Collect active IP information (prefer IPv4).
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                if name == "lo0" { continue }

                let flags = Int32(interface.ifa_flags)
                let isUp = (flags & Int32(IFF_UP)) != 0
                let isRunning = (flags & Int32(IFF_RUNNING)) != 0
                let isLoopback = (flags & Int32(IFF_LOOPBACK)) != 0

                if isLoopback || !isUp {
                    continue
                }

                guard let ip = ipAddressString(from: addr) else { continue }
                var score = interfacePriority(name: name)
                if isRunning { score += 10 }

                if addrFamily == UInt8(AF_INET) {
                    if ip.hasPrefix("169.254.") || ip.hasPrefix("127.") { continue }
                    if ipv4Candidate == nil || score > ipv4Candidate!.score {
                        ipv4Candidate = (name, ip, score)
                    }
                } else {
                    if ip == "::1" || ip.hasPrefix("fe80:") { continue }
                    if ipv6Candidate == nil || score > ipv6Candidate!.score {
                        ipv6Candidate = (name, ip, score)
                    }
                }
            }
        }

        totalUpload = upload
        totalDownload = download

        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0
        let now = CFAbsoluteTimeGetCurrent()

        if prevTimestamp > 0 {
            let timeDiff = now - prevTimestamp
            // Interface counters can reset on sleep/wake or network changes.
            // Guard to avoid UInt64 underflow traps.
            if timeDiff > 0 && upload >= prevUpload && download >= prevDownload {
                let uploadDiff = Double(upload - prevUpload)
                let downloadDiff = Double(download - prevDownload)
                uploadSpeed = uploadDiff / timeDiff
                downloadSpeed = downloadDiff / timeDiff
            }
        }

        prevUpload = upload
        prevDownload = download
        prevTimestamp = now

        let preferredIP = ipv4Candidate ?? ipv6Candidate
        return NetworkStats(
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            totalUpload: totalUpload,
            totalDownload: totalDownload,
            ipAddress: preferredIP?.address,
            interfaceName: preferredIP?.interface
        )
    }

    private func ipAddressString(from sockaddrPtr: UnsafePointer<sockaddr>) -> String? {
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let addrLen: socklen_t

        switch Int32(sockaddrPtr.pointee.sa_family) {
        case AF_INET:
            addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        case AF_INET6:
            addrLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
        default:
            return nil
        }

        let result = getnameinfo(
            sockaddrPtr,
            addrLen,
            &hostBuffer,
            socklen_t(hostBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }

        return String(cString: hostBuffer)
    }

    private func interfacePriority(name: String) -> Int {
        if name == "en0" { return 100 }      // Common Wi-Fi on Mac
        if name == "en1" { return 90 }
        if name.hasPrefix("bridge") { return 80 }
        if name.hasPrefix("pdp_ip") { return 70 } // USB/iPhone tethering
        if name.hasPrefix("utun") { return 60 }   // VPN
        return 50
    }
}
