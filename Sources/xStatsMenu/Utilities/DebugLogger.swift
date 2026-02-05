import Foundation

class DebugLogger {
    static let shared = DebugLogger()

    private let logFile: URL
    private let formatter: DateFormatter

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        logFile = paths[0].appendingPathComponent("xstats_debug.log")

        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        // Clear old log
        try? FileManager.default.removeItem(at: logFile)
    }

    func log(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        // Print to console
        print(logMessage, terminator: "")

        // Write to file
        if let handle = try? FileHandle(forWritingTo: logFile) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8) ?? Data())
        } else {
            try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
        }
    }

    func readLogs() -> String {
        (try? String(contentsOf: logFile)) ?? "No logs available"
    }
}
