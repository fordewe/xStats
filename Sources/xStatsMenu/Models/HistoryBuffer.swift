import Foundation

/// Ring buffer for history - O(1) add instead of O(n) removeFirst
class HistoryBuffer<T> {
    private var buffer: [T]
    private let capacity: Int
    private let defaultValue: T
    private var index: Int = 0
    private var isFull: Bool = false

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.defaultValue = defaultValue
        self.buffer = [T](repeating: defaultValue, count: capacity)
    }

    func add(_ value: T) {
        buffer[index] = value
        index = (index + 1) % capacity
        if index == 0 { isFull = true }
    }

    func getValues() -> [T] {
        // Return values in chronological order
        if !isFull {
            return Array(buffer[0..<index]) + Array(repeating: defaultValue, count: capacity - index)
        }
        return Array(buffer[index..<capacity]) + Array(buffer[0..<index])
    }

    func clear() {
        buffer = [T](repeating: defaultValue, count: capacity)
        index = 0
        isFull = false
    }

    var count: Int {
        capacity
    }
}
