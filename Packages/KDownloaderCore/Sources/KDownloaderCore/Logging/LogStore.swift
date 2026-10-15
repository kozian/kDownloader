import Foundation

/// Writes the app log: one file per launch, keeping only the most recent files.
public actor LogStore {
    public nonisolated let fileURL: URL

    private let handle: FileHandle
    private let clock: @Sendable () -> Date
    private let formatter: DateFormatter
    private var subscribers: [UUID: AsyncStream<String>.Continuation] = [:]

    /// Creates a new log file in `directory` and deletes the oldest files so that
    /// at most `maxFiles` remain, including the new one.
    public init(
        directory: URL,
        maxFiles: Int = 10,
        clock: @escaping @Sendable () -> Date = Date.init
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let existing = try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(Self.filePrefix) && $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in existing.dropLast(max(maxFiles - 1, 0)) {
            try? fileManager.removeItem(at: file)
        }

        let nameFormatter = DateFormatter()
        nameFormatter.locale = Locale(identifier: "en_US_POSIX")
        nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        var url = directory.appending(path: "\(Self.filePrefix)\(nameFormatter.string(from: clock())).log")
        var suffix = 2
        while fileManager.fileExists(atPath: url.path) {
            url = directory.appending(path: "\(Self.filePrefix)\(nameFormatter.string(from: clock()))-\(suffix).log")
            suffix += 1
        }
        fileManager.createFile(atPath: url.path, contents: nil)

        self.fileURL = url
        self.handle = try FileHandle(forWritingTo: url)
        self.clock = clock
        self.formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    /// The default log directory, `~/Library/Logs/kDownloader`.
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/kDownloader")
    }

    static let filePrefix = "kDownloader-"

    /// Appends a timestamped entry. Multi-line text produces one entry per line.
    public func write(_ text: String, category: String = "app") {
        let timestamp = formatter.string(from: clock())
        var output = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let entry = "\(timestamp) [\(category)] \(line)"
            output += entry + "\n"
            for continuation in subscribers.values {
                continuation.yield(entry)
            }
        }
        handle.write(Data(output.utf8))
    }

    /// The full contents of the current log file.
    public func contents() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// A stream of entries written after the call.
    public func subscribe() -> AsyncStream<String> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        subscribers[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.unsubscribe(id) }
        }
        return stream
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }
}
