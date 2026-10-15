import Foundation
import Testing
@testable import KDownloaderCore

struct YtDlpAnalyzeTests {
    let url = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw")!

    @Test func returnsVideoAndPassesFixedOptions() async throws {
        let fixture = try FakeYtDlp.fixturePath("analysis/youtube-me-at-the-zoo.json")
        let fake = try FakeYtDlp(body: "cat '\(fixture)'\n")

        let video = try await fake.client.analyze(url)

        #expect(video.title == "Me at the zoo")
        let arguments = try fake.recordedArguments()
        for flag in ["--ignore-config", "--no-playlist", "--flat-playlist", "-J"] {
            #expect(arguments.contains(flag), "missing \(flag)")
        }
        #expect(arguments.contains(fake.tools.ffmpeg.path))
        #expect(arguments.contains("deno:\(fake.tools.deno.path)"))
        #expect(arguments.contains("--cache-dir"))
        #expect(!arguments.contains("--cookies-from-browser"))
        #expect(arguments.suffix(2) == ["--", url.absoluteString])
    }

    @Test func passesCookiesBrowserWhenAsked() async throws {
        let fixture = try FakeYtDlp.fixturePath("analysis/youtube-me-at-the-zoo.json")
        let fake = try FakeYtDlp(body: "cat '\(fixture)'\n")
        _ = try await fake.client.analyze(url, cookiesFromBrowser: "safari")
        let arguments = try fake.recordedArguments()
        let index = try #require(arguments.firstIndex(of: "--cookies-from-browser"))
        #expect(arguments[index + 1] == "safari")
    }

    @Test func classifiesErrors() async throws {
        let fake = try FakeYtDlp(body: "echo '[debug] noise' >&2\necho 'ERROR: [youtube] x: Private video' >&2\nexit 1\n")
        await #expect(throws: AppError(.privateVideo, details: "ERROR: [youtube] x: Private video")) {
            try await fake.client.analyze(url)
        }
    }

    @Test(arguments: [("youtube-playlist", ErrorCategory.playlistsAndChannels), ("youtube-channel", .playlistsAndChannels), ("youtube-live", .liveStream)])
    func rejectsUnsupportedLinkTypes(fixture: String, expected: ErrorCategory) async throws {
        let path = try FakeYtDlp.fixturePath("analysis/\(fixture).json")
        let fake = try FakeYtDlp(body: "cat '\(path)'\n")
        do {
            _ = try await fake.client.analyze(url)
            Issue.record("expected an error")
        } catch let error as AppError {
            #expect(error.category == expected)
        }
    }

    @Test func reportsGarbageOutputAsUnknown() async throws {
        let fake = try FakeYtDlp(body: "echo 'not json'\n")
        do {
            _ = try await fake.client.analyze(url)
            Issue.record("expected an error")
        } catch let error as AppError {
            #expect(error.category == .unknown)
        }
    }

    @Test func cancellationThrowsCancellationError() async throws {
        let fake = try FakeYtDlp(body: "trap 'exit 130' INT\nwhile true; do sleep 0.05; done\n")
        let task = Task { try await fake.client.analyze(url) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
