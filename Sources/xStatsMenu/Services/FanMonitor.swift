import Foundation

class FanMonitor {
    private let smc = SMCKit.shared

    // Common fan speed key patterns to try
    // Different Mac models use different key formats
    private let fanKeyPatterns = ["F%dAc", "F%dMd", "F%dTg", "F%d"] // Actual, Manual, Target, Basic

    func getStats() -> FanStats? {
        let fanCount = smc.getFanCount()

        guard fanCount > 0 else {
            return nil
        }

        var speeds: [Int] = []
        speeds.reserveCapacity(fanCount)

        for i in 0..<fanCount {
            var speed: Int?

            // Try different key patterns until we find a readable one
            for pattern in fanKeyPatterns {
                let key = String(format: pattern, i)
                if let readSpeed = smc.readFanSpeed(key: key) {
                    speed = readSpeed
                    // If we got a non-zero speed, use it; otherwise keep trying other patterns
                    if readSpeed > 0 {
                        break
                    }
                }
            }

            // Use the speed we found, or 0 if fan is idle / unreadable
            speeds.append(speed ?? 0)
        }

        return FanStats(speeds: speeds, count: fanCount)
    }
}
