import Foundation

/// Appends to the file named by ZONELY_DEBUG_LOG. No-op when unset.
enum DebugLog {
    private static let path = ProcessInfo.processInfo.environment["ZONELY_DEBUG_LOG"]
    private static let queue = DispatchQueue(label: "zonely.debuglog")

    static var isEnabled: Bool { path != nil }

    static func write(_ message: String) {
        guard let path else { return }
        queue.async {
            let stamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(stamp) \(message)\n"
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: URL(fileURLWithPath: path))
            }
        }
    }
}

/// True while the app is rendering itself to a PNG rather than to the screen.
enum SnapshotMode {
    static let isActive = ProcessInfo.processInfo.environment["ZONELY_SNAPSHOT"] != nil
}
