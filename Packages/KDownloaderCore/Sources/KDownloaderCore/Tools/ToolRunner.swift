import Foundation

/// A single run of an external tool.
public struct ToolInvocation: Sendable {
    public var executable: URL
    public var arguments: [String]
    /// The complete environment of the process; nothing is inherited.
    public var environment: [String: String]
    /// Which stdout lines go to the log; stderr is always logged.
    public var standardOutputLogging: OutputLogging

    public init(
        executable: URL,
        arguments: [String],
        environment: [String: String] = ToolInvocation.defaultEnvironment,
        standardOutputLogging: OutputLogging = .all
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.standardOutputLogging = standardOutputLogging
    }

    public enum OutputLogging: Sendable {
        case all
        /// For commands that print large payloads.
        case none
        /// For frequent machine-readable lines such as progress.
        case excludingPrefix(String)

        func includes(_ line: String) -> Bool {
            switch self {
            case .all: true
            case .none: false
            case .excludingPrefix(let prefix): !line.hasPrefix(prefix)
            }
        }
    }

    /// A minimal, predictable environment that does not depend on the user's shell.
    public static var defaultEnvironment: [String: String] {
        [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
            "TMPDIR": FileManager.default.temporaryDirectory.path,
        ]
    }

    /// The command line as shown in the log.
    public var commandLine: String {
        ([executable.path] + arguments).map(Self.quoted).joined(separator: " ")
    }

    private static func quoted(_ argument: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./:=,+@%"))
        if !argument.isEmpty, argument.unicodeScalars.allSatisfy(safe.contains) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Output of a running tool, in the order it arrives.
public enum ToolEvent: Sendable, Equatable {
    case standardOutput(String)
    case standardError(String)
    /// Always the last event of a run that was not cancelled.
    case exited(Int32)
}

public enum ToolRunnerError: Error, Equatable {
    case launchFailed(String)
}

/// Runs external tools and streams their output line by line.
public struct ToolRunner: Sendable {
    private let log: LogStore?
    private let interruptGracePeriod: Duration

    /// - Parameter interruptGracePeriod: how long a cancelled process gets to
    ///   exit after SIGINT before it receives SIGTERM.
    public init(log: LogStore?, interruptGracePeriod: Duration = .seconds(5)) {
        self.log = log
        self.interruptGracePeriod = interruptGracePeriod
    }

    /// Starts the tool. Cancelling the consuming task (or dropping the stream)
    /// interrupts the process.
    public func run(_ invocation: ToolInvocation) -> AsyncThrowingStream<ToolEvent, Error> {
        let log = log
        let gracePeriod = interruptGracePeriod
        let category = invocation.executable.deletingPathExtension().lastPathComponent

        return AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = invocation.executable
            process.arguments = invocation.arguments
            process.environment = invocation.environment
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = FileHandle.nullDevice

            let box = ProcessBox(process)
            let exited = AsyncStream.makeStream(of: Int32.self)
            process.terminationHandler = { finished in
                exited.continuation.yield(finished.terminationStatus)
                exited.continuation.finish()
            }

            continuation.onTermination = { termination in
                if case .cancelled = termination {
                    box.interrupt(after: gracePeriod)
                }
            }

            let task = Task {
                let start = ContinuousClock.now
                await log?.write("$ \(invocation.commandLine)", category: category)
                do {
                    try process.run()
                } catch {
                    await log?.write("launch failed: \(error.localizedDescription)", category: category)
                    continuation.finish(throwing: ToolRunnerError.launchFailed(error.localizedDescription))
                    return
                }

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await line in Self.lines(of: stdout.fileHandleForReading) {
                            if invocation.standardOutputLogging.includes(line) {
                                await log?.write(line, category: category)
                            }
                            continuation.yield(.standardOutput(line))
                        }
                    }
                    group.addTask {
                        for await line in Self.lines(of: stderr.fileHandleForReading) {
                            await log?.write(line, category: "\(category):stderr")
                            continuation.yield(.standardError(line))
                        }
                    }
                }

                var status: Int32 = -1
                for await code in exited.stream {
                    status = code
                }
                let elapsed = ContinuousClock.now - start
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                await log?.write(String(format: "exit code %d after %.1f s", status, seconds), category: category)
                continuation.yield(.exited(status))
                continuation.finish()
            }
            _ = task
        }
    }

    /// Splits the output of a pipe into lines without the trailing newline.
    static func lines(of handle: FileHandle) -> AsyncStream<String> {
        AsyncStream { continuation in
            let splitter = LineSplitter()
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    if let rest = splitter.flush() {
                        continuation.yield(rest)
                    }
                    continuation.finish()
                    return
                }
                for line in splitter.append(chunk) {
                    continuation.yield(line)
                }
            }
        }
    }
}

/// Accumulates bytes and cuts them into lines. `readabilityHandler` calls are
/// serialized, so the buffer is never accessed concurrently.
final class LineSplitter: @unchecked Sendable {
    private var buffer = Data()

    func append(_ chunk: Data) -> [String] {
        buffer.append(chunk)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = buffer[buffer.startIndex..<newline]
            if line.last == 0x0D {
                line = line.dropLast()
            }
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    func flush() -> String? {
        defer { buffer.removeAll() }
        return buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self)
    }
}

/// Lets the cancellation handler signal the process from any thread.
private final class ProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func interrupt(after gracePeriod: Duration) {
        guard process.isRunning else { return }
        process.interrupt()
        let process = process
        Task.detached { [process] in
            try? await Task.sleep(for: gracePeriod)
            if process.isRunning {
                process.terminate()
            }
        }
    }
}
