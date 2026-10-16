import Foundation
import Testing
@testable import KDownloaderCore

/// Installs the real latest yt-dlp from GitHub into a temporary folder.
/// Off by default: run with `KD_NETWORK_TESTS=1 swift test --filter LiveUpdateTests`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KD_NETWORK_TESTS"] == "1"))
struct LiveUpdateTests {
    @Test(.timeLimit(.minutes(5)))
    func installsLatestRelease() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "LiveUpdateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let http = URLSessionHTTPClient()
        let release = try await YtDlpReleaseSource(http: http).latest()
        let installer = YtDlpInstaller(root: root, http: http, runner: ToolRunner(log: nil), log: nil)
        let installed = try await installer.install(release)
        #expect(installed.version == release.version)
        #expect(try await installer.version(of: installed.executable) == release.version)
        let framework = installed.directory.appending(path: "_internal/Python.framework/Versions/Current")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: framework.path)) != nil)
    }
}
