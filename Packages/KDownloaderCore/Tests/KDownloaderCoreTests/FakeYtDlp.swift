import Foundation
@testable import KDownloaderCore

/// A shell script standing in for yt-dlp. It records its arguments and runs
/// the given body.
struct FakeYtDlp {
    let directory: URL
    let argumentsFile: URL
    let tools: ToolLocator

    init(body: String) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "FakeYtDlp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        argumentsFile = directory.appending(path: "arguments")
        let script = directory.appending(path: "yt-dlp")
        let header = "#!/bin/sh\nfor a in \"$@\"; do printf '%s\\n' \"$a\"; done > '\(argumentsFile.path)'\n"
        try (header + body).write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        tools = ToolLocator(
            ytDlp: script,
            ffmpeg: directory.appending(path: "ffmpeg"),
            ffprobe: directory.appending(path: "ffprobe"),
            deno: directory.appending(path: "deno")
        )
    }

    var client: YtDlpClient {
        YtDlpClient(tools: tools, runner: ToolRunner(log: nil), cacheDirectory: directory.appending(path: "cache"))
    }

    func recordedArguments() throws -> [String] {
        try String(contentsOf: argumentsFile, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    static func fixturePath(_ path: String) throws -> String {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url.path
    }
}
