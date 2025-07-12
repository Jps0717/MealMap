import Foundation

// MARK: - Enhanced Debug Logging
func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = DateFormatter.debugTimestamp.string(from: Date())
    print("🐛 [\(timestamp)] [\(fileName):\(line)] \(function): \(message)")
    #endif
}

func debugError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = DateFormatter.debugTimestamp.string(from: Date())
    let errorDetail = error?.localizedDescription ?? ""
    print("❌ [\(timestamp)] [\(fileName):\(line)] \(function): \(message) \(errorDetail)")
    #endif
}

func debugSuccess(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let timestamp = DateFormatter.debugTimestamp.string(from: Date())
    print("✅ [\(timestamp)] [\(fileName):\(line)] \(function): \(message)")
    #endif
}

extension DateFormatter {
    static let debugTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}