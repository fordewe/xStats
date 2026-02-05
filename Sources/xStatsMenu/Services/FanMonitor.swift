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

            // Try different key patterns until we find one that works
            for pattern in fanKeyPatterns {
                let key = String(format: pattern, i)
                speed = smc.readFanSpeed(key: key)
                if speed != nil && speed! > 0 {
                    break // Use this value
                }
            }

            // If we got a valid speed, add it
            if let validSpeed = speed, validSpeed > 0 {
                speeds.append(validSpeed)
            } else {
                // Add 0 as placeholder for fans we couldn't read
                speeds.append(0)
            }
        }

        return FanStats(speeds: speeds, count: fanCount)
    }
}
