import Foundation

/// A bundled external tool.
public enum Tool: String, CaseIterable, Sendable {
    case ytDlp = "yt-dlp"
    case ffmpeg
    case ffprobe
    case deno

    var versionArguments: [String] {
        switch self {
        case .ytDlp, .deno: ["--version"]
        case .ffmpeg, .ffprobe: ["-version"]
        }
    }
}

/// Paths of the bundled tools inside the app bundle.
public struct ToolLocator: Sendable {
    public let ytDlp: URL
    public let ffmpeg: URL
    public let ffprobe: URL
    public let deno: URL

    public init(ytDlp: URL, ffmpeg: URL, ffprobe: URL, deno: URL) {
        self.ytDlp = ytDlp
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe
        self.deno = deno
    }

    /// Layout produced by the "Embed Tools" build phase.
    public init(appBundle: URL) {
        let contents = appBundle.appending(path: "Contents")
        let helpers = contents.appending(path: "Helpers")
        self.init(
            ytDlp: contents.appending(path: "Resources/yt-dlp/yt-dlp_macos"),
            ffmpeg: helpers.appending(path: "ffmpeg"),
            ffprobe: helpers.appending(path: "ffprobe"),
            deno: helpers.appending(path: "deno")
        )
    }

    public func url(for tool: Tool) -> URL {
        switch tool {
        case .ytDlp: ytDlp
        case .ffmpeg: ffmpeg
        case .ffprobe: ffprobe
        case .deno: deno
        }
    }
}

/// Outcome of the launch-time check.
public enum ToolCheckResult: Equatable, Sendable {
    case ready(versions: [Tool: String])
    case broken(tool: Tool, reason: String)
}

/// Verifies at launch that every bundled tool exists and runs.
public struct ToolChecker: Sendable {
    private let locator: ToolLocator
    private let runner: ToolRunner
    private let timeout: Duration

    public init(locator: ToolLocator, runner: ToolRunner, timeout: Duration = .seconds(10)) {
        self.locator = locator
        self.runner = runner
        self.timeout = timeout
    }

    public func check() async -> ToolCheckResult {
        let results = await withTaskGroup(of: (Tool, Result<String, ToolCheckFailure>).self) { group in
            for tool in Tool.allCases {
                group.addTask { (tool, await self.version(of: tool)) }
            }
            var results: [Tool: Result<String, ToolCheckFailure>] = [:]
            for await (tool, result) in group {
                results[tool] = result
            }
            return results
        }

        var versions: [Tool: String] = [:]
        for tool in Tool.allCases {
            switch results[tool] {
            case .success(let version):
                versions[tool] = version
            case .failure(let failure):
                return .broken(tool: tool, reason: failure.reason)
            case nil:
                return .broken(tool: tool, reason: "not checked")
            }
        }
        return .ready(versions: versions)
    }

    private func version(of tool: Tool) async -> Result<String, ToolCheckFailure> {
        let url = locator.url(for: tool)
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            return .failure(ToolCheckFailure(reason: "missing or not executable: \(url.path)"))
        }

        let invocation = ToolInvocation(executable: url, arguments: tool.versionArguments)
        let run = Task { () -> Result<String, ToolCheckFailure> in
            var firstLine: String?
            do {
                for try await event in runner.run(invocation) {
                    switch event {
                    case .standardOutput(let line):
                        if firstLine == nil { firstLine = line }
                    case .standardError:
                        break
                    case .exited(let status):
                        guard status == 0 else {
                            return .failure(ToolCheckFailure(reason: "exited with code \(status)"))
                        }
                    }
                }
            } catch {
                return .failure(ToolCheckFailure(reason: "failed to launch: \(error)"))
            }
            if Task.isCancelled {
                return .failure(ToolCheckFailure(reason: "did not respond in time"))
            }
            guard let line = firstLine else {
                return .failure(ToolCheckFailure(reason: "printed no version"))
            }
            return .success(Self.parseVersion(line))
        }

        let watchdog = Task {
            try await Task.sleep(for: timeout)
            run.cancel()
        }
        let result = await run.value
        watchdog.cancel()
        return result
    }

    /// Extracts the version number from the first line of the version output,
    /// e.g. `ffmpeg version 9.0.2 Copyright…` → `9.0.2`.
    static func parseVersion(_ line: String) -> String {
        if let match = line.firstMatch(of: /\d+(\.\d+)+/) {
            return String(match.output.0)
        }
        return line
    }
}

struct ToolCheckFailure: Error {
    let reason: String
}
