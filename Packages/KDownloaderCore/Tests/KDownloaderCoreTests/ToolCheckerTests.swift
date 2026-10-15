import Foundation
import Testing
@testable import KDownloaderCore

struct ToolCheckerTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ToolCheckerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makeTool(_ name: String, body: String) throws -> URL {
        let url = directory.appending(path: name)
        try ("#!/bin/sh\n" + body).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func makeLocator(ffmpegBody: String? = "echo 'ffmpeg version 9.0.2 Copyright (c) 2000-2026'") throws -> ToolLocator {
        let ffmpeg = directory.appending(path: "ffmpeg")
        if let ffmpegBody {
            _ = try makeTool("ffmpeg", body: ffmpegBody)
        }
        return ToolLocator(
            ytDlp: try makeTool("yt-dlp", body: "echo 2026.08.19"),
            ffmpeg: ffmpeg,
            ffprobe: try makeTool("ffprobe", body: "echo 'ffprobe version 9.0.2 Copyright'"),
            deno: try makeTool("deno", body: "echo 'deno 2.9.7 (stable, release, aarch64-apple-darwin)'")
        )
    }

    @Test func reportsVersionsWhenAllToolsRun() async throws {
        let checker = ToolChecker(locator: try makeLocator(), runner: ToolRunner(log: nil))
        let result = await checker.check()
        #expect(result == .ready(versions: [.ytDlp: "2026.08.19", .ffmpeg: "9.0.2", .ffprobe: "9.0.2", .deno: "2.9.7"]))
    }

    @Test func reportsMissingTool() async throws {
        let checker = ToolChecker(locator: try makeLocator(ffmpegBody: nil), runner: ToolRunner(log: nil))
        guard case .broken(let tool, let reason) = await checker.check() else {
            Issue.record("expected a broken result")
            return
        }
        #expect(tool == .ffmpeg)
        #expect(reason.contains("missing"))
    }

    @Test func reportsFailingTool() async throws {
        let checker = ToolChecker(locator: try makeLocator(ffmpegBody: "exit 1"), runner: ToolRunner(log: nil))
        #expect(await checker.check() == .broken(tool: .ffmpeg, reason: "exited with code 1"))
    }

    @Test func reportsHangingTool() async throws {
        let locator = try makeLocator(ffmpegBody: "while true; do sleep 0.05; done")
        let checker = ToolChecker(
            locator: locator,
            runner: ToolRunner(log: nil, interruptGracePeriod: .milliseconds(100)),
            timeout: .milliseconds(1500)
        )
        #expect(await checker.check() == .broken(tool: .ffmpeg, reason: "did not respond in time"))
    }

    @Test func locatesToolsInAppBundle() {
        let locator = ToolLocator(appBundle: URL(filePath: "/Applications/kDownloader.app"))
        #expect(locator.ytDlp.path == "/Applications/kDownloader.app/Contents/Resources/yt-dlp/yt-dlp_macos")
        #expect(locator.ffmpeg.path == "/Applications/kDownloader.app/Contents/Helpers/ffmpeg")
    }

    @Test(arguments: [
        ("2026.08.19", "2026.08.19"),
        ("ffmpeg version 9.0.2 Copyright (c) 2000-2026", "9.0.2"),
        ("deno 2.9.7 (stable, release, aarch64-apple-darwin)", "2.9.7"),
    ])
    func parsesVersion(line: String, expected: String) {
        #expect(ToolChecker.parseVersion(line) == expected)
    }
}
