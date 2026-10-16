import Foundation
import Testing
@testable import KDownloaderCore

struct YtDlpReleaseSourceTests {
    let latestURL = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
    let sumsURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/SHA2-256SUMS")!

    private func fake() throws -> FakeHTTPClient {
        let http = FakeHTTPClient()
        http.respond(to: latestURL, with: try Fixtures.data("updates/github-latest.json"))
        http.respond(to: sumsURL, with: try Fixtures.data("updates/SHA2-256SUMS"))
        return http
    }

    @Test func findsArchiveAndChecksum() async throws {
        let release = try await YtDlpReleaseSource(http: try fake()).latest()
        #expect(release.version == YtDlpVersion("2026.08.19"))
        #expect(release.archiveURL.absoluteString == "https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp_macos.zip")
        #expect(release.sha256 == "07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8")
    }

    @Test func networkFailureIsReported() async throws {
        let http = FakeHTTPClient()
        http.fail(latestURL, with: .network("offline"))
        await #expect(throws: UpdateError.network("offline")) {
            try await YtDlpReleaseSource(http: http).latest()
        }
    }

    @Test func garbageIsAnUnexpectedResponse() async throws {
        let http = FakeHTTPClient()
        http.respond(to: latestURL, with: Data("<html>rate limited</html>".utf8))
        do {
            _ = try await YtDlpReleaseSource(http: http).latest()
            Issue.record("expected an error")
        } catch let error as UpdateError {
            guard case .unexpectedResponse = error else {
                Issue.record("unexpected \(error)")
                return
            }
        }
    }

    @Test func missingChecksumIsRejected() async throws {
        let http = try fake()
        http.respond(to: sumsURL, with: Data("0f19  yt-dlp_macos\n".utf8))
        await #expect(throws: UpdateError.unexpectedResponse("no checksum for yt-dlp_macos.zip")) {
            try await YtDlpReleaseSource(http: http).latest()
        }
    }

    @Test func parsesChecksumLines() {
        let list = "aa  other\n07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8 *yt-dlp_macos.zip\n"
        #expect(YtDlpReleaseSource.checksum(for: "yt-dlp_macos.zip", in: list) == "07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8")
        #expect(YtDlpReleaseSource.checksum(for: "yt-dlp_macos", in: list) == nil)
    }
}
