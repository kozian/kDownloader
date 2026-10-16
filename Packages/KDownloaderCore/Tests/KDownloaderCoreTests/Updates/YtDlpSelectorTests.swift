import Foundation
import Testing
@testable import KDownloaderCore

struct YtDlpSelectorTests {
    let root: URL
    let bundled: URL
    let bundledVersion = YtDlpVersion("2026.08.19")!

    init() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "YtDlpSelectorTests-\(UUID().uuidString)")
        root = directory.appending(path: "install")
        bundled = directory.appending(path: "bundled/yt-dlp_macos")
        try FileManager.default.createDirectory(at: bundled.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.script(at: bundled, body: "echo 2026.08.19")
    }

    static func script(at url: URL, body: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func install(_ version: String, body: String? = nil) throws {
        try Self.script(at: root.appending(path: "\(version)/yt-dlp_macos"), body: body ?? "echo \(version)")
    }

    private var selector: YtDlpSelector {
        YtDlpSelector(installer: YtDlpInstaller(root: root, http: FakeHTTPClient(), runner: ToolRunner(log: nil), log: nil), log: nil)
    }

    @Test func usesBundledWithoutUpdates() async {
        let active = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active == ActiveYtDlp(version: bundledVersion, executable: bundled, source: .bundled))
    }

    @Test func usesNewestWorkingUpdate() async throws {
        try install("2026.09.01")
        try install("2026.10.01")
        let active = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active.source == .updated)
        #expect(active.version == YtDlpVersion("2026.10.01"))
    }

    @Test func skipsBrokenUpdate() async throws {
        try install("2026.09.01")
        try install("2026.10.01", body: "exit 1")
        let active = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active.version == YtDlpVersion("2026.09.01"))
        #expect(active.source == .updated)
    }

    @Test func fallsBackToBundledWhenAllUpdatesAreBroken() async throws {
        try install("2026.10.01", body: "echo 2026.01.01")
        let active = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active.source == .bundled)
    }

    @Test func bundledNewerThanUpdateWins() async throws {
        try install("2026.07.01")
        let active = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active.source == .bundled)
    }

    @Test func revertRemovesUpdates() async throws {
        try install("2026.10.01")
        let active = try await selector.revertToBundled(bundled: bundled, bundledVersion: bundledVersion)
        #expect(active.source == .bundled)
        let again = await selector.choose(bundled: bundled, bundledVersion: bundledVersion)
        #expect(again.source == .bundled)
    }
}
