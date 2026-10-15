import Foundation

/// Runs the bundled yt-dlp with fixed, deterministic options.
public struct YtDlpClient: Sendable {
    private let tools: ToolLocator
    private let runner: ToolRunner
    private let cacheDirectory: URL

    public init(tools: ToolLocator, runner: ToolRunner, cacheDirectory: URL = YtDlpClient.defaultCacheDirectory) {
        self.tools = tools
        self.runner = runner
        self.cacheDirectory = cacheDirectory
    }

    public static var defaultCacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Caches/kDownloader/yt-dlp")
    }

    /// Options passed to every invocation: ignore user configs, never expand
    /// playlists, use only the bundled tools, keep the cache in our own folder.
    func commonArguments(cookiesFromBrowser browser: String?) -> [String] {
        var arguments = [
            "--ignore-config",
            "--no-playlist",
            "--ffmpeg-location", tools.ffmpeg.path,
            "--js-runtimes", "deno:\(tools.deno.path)",
            "--cache-dir", cacheDirectory.path,
            "-v",
        ]
        if let browser {
            arguments += ["--cookies-from-browser", browser]
        }
        return arguments
    }

    /// Analyzes a link. Throws `AppError` when the link cannot be downloaded
    /// and `CancellationError` when the task is cancelled.
    public func analyze(_ url: URL, cookiesFromBrowser browser: String? = nil) async throws -> VideoInfo {
        let invocation = ToolInvocation(
            executable: tools.ytDlp,
            arguments: commonArguments(cookiesFromBrowser: browser) + ["--flat-playlist", "-J", "--", url.absoluteString],
            standardOutputLogging: .none
        )

        var output = Data()
        var errors: [String] = []
        var status: Int32 = -1
        do {
            for try await event in runner.run(invocation) {
                switch event {
                case .standardOutput(let line):
                    output.append(Data(line.utf8))
                    output.append(0x0A)
                case .standardError(let line):
                    errors.append(line)
                case .exited(let code):
                    status = code
                }
            }
        } catch is ToolRunnerError {
            throw AppError(.unknown, details: "yt-dlp could not be started")
        }
        try Task.checkCancellation()

        guard status == 0 else {
            throw ErrorClassifier.classify(errors)
        }
        let response: AnalysisResponse
        do {
            response = try AnalysisResponse.decode(output)
        } catch {
            throw AppError(.unknown, details: "Unexpected yt-dlp output: \(error)")
        }
        return try LinkRules.video(from: response).get()
    }

    /// Downloads `url` with `plan` into `directory` as `<baseName>.<ext>`.
    /// Temporary and partial files are written next to the result and are not
    /// removed on failure or cancellation. The stream fails with `AppError`;
    /// cancelling the consuming task interrupts yt-dlp.
    public func download(
        _ url: URL,
        plan: DownloadPlan,
        to directory: URL,
        baseName: String,
        cookiesFromBrowser browser: String? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        let template = directory.appending(path: baseName.replacingOccurrences(of: "%", with: "%%")).path + ".%(ext)s"
        let invocation = ToolInvocation(
            executable: tools.ytDlp,
            arguments: commonArguments(cookiesFromBrowser: browser)
                + plan.arguments
                + DownloadOutputParser.arguments
                + ["-o", template, "--", url.absoluteString],
            standardOutputLogging: .excludingPrefix(DownloadOutputParser.progressPrefix)
        )
        let runner = runner

        return AsyncThrowingStream { continuation in
            let task = Task {
                var errors: [String] = []
                var file: URL?
                do {
                    continuation.yield(.progress(.preparing))
                    for try await event in runner.run(invocation) {
                        switch event {
                        case .standardOutput(let line):
                            switch DownloadOutputParser.parse(line) {
                            case .progress(let progress): continuation.yield(.progress(progress))
                            case .processing: continuation.yield(.progress(DownloadProgress(stage: .processing)))
                            case .finishedFile(let path): file = URL(filePath: path)
                            case nil: break
                            }
                        case .standardError(let line):
                            errors.append(line)
                        case .exited(let status):
                            if status == 0, let file {
                                continuation.yield(.finished(file))
                                continuation.finish()
                            } else if status == 0 {
                                continuation.finish(throwing: AppError(.unknown, details: "yt-dlp did not report the downloaded file"))
                            } else {
                                continuation.finish(throwing: ErrorClassifier.classify(errors))
                            }
                        }
                    }
                } catch is ToolRunnerError {
                    continuation.finish(throwing: AppError(.unknown, details: "yt-dlp could not be started"))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Output of a running download.
public enum DownloadEvent: Sendable, Equatable {
    case progress(DownloadProgress)
    case finished(URL)
}
