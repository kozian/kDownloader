import Foundation
import Testing
@testable import KDownloaderCore

struct ErrorClassifierTests {
    @Test(arguments: [
        ("unsupported-url", ErrorCategory.siteNotSupported),
        ("video-unavailable", .videoUnavailable),
        ("video-removed", .videoUnavailable),
        ("vimeo-login-required", .signInRequired),
        ("private-video", .privateVideo),
        ("age-restricted", .signInRequired),
        ("not-a-bot", .rateLimited),
        ("members-only", .membersOnly),
        ("geo-restricted", .notAvailableInRegion),
        ("geo-restricted-generic", .notAvailableInRegion),
        ("rate-limited", .rateLimited),
        ("no-network", .noNetwork),
        ("no-network-curl", .noNetwork),
        ("disk-full", .notEnoughDiskSpace),
        ("permission-denied", .cannotWriteDestination),
        ("processing-failed", .processingFailed),
        ("upcoming-live", .liveStream),
        ("cookies-safari", .cookiesUnavailable),
        ("cookies-missing", .cookiesUnavailable),
        ("unknown", .unknown),
    ])
    func classifiesFixture(name: String, expected: ErrorCategory) throws {
        let lines = try Fixtures.text("errors/\(name).txt").split(separator: "\n").map(String.init)
        let error = ErrorClassifier.classify(lines)
        #expect(error.category == expected)
        #expect(error.details?.hasPrefix("ERROR:") == true)
    }

    @Test func usesTheLastErrorLine() {
        let error = ErrorClassifier.classify([
            "[youtube] abc: Downloading webpage",
            "ERROR: [youtube] abc: Private video",
            "ERROR: Unsupported URL: https://example.com",
        ])
        #expect(error == AppError(.siteNotSupported, details: "ERROR: Unsupported URL: https://example.com"))
    }

    @Test func fallsBackToLastLineWithoutErrorPrefix() {
        let error = ErrorClassifier.classify(["Traceback (most recent call last):", "OSError: [Errno 28] No space left on device"])
        #expect(error.category == .notEnoughDiskSpace)
    }

    @Test func emptyOutputIsUnknown() {
        #expect(ErrorClassifier.classify([]) == AppError(.unknown))
    }

    @Test func accessCategoriesMayNeedCookies() {
        let categories = ErrorCategory.allCases.filter(\.mayNeedCookies)
        #expect(Set(categories) == [.signInRequired, .privateVideo, .membersOnly, .rateLimited])
    }
}

struct LinkRulesTests {
    @Test func acceptsRegularVideo() throws {
        let result = LinkRules.video(from: try Fixtures.analysis("youtube-me-at-the-zoo"))
        #expect(try result.get().id == "jNQXAC9IVRw")
    }

    @Test func acceptsVideoInsidePlaylist() throws {
        let result = LinkRules.video(from: try Fixtures.analysis("youtube-video-in-playlist"))
        #expect(try result.get().id == "jNQXAC9IVRw")
    }

    @Test(arguments: ["youtube-playlist", "youtube-channel"])
    func rejectsPlaylistsAndChannels(name: String) throws {
        let result = LinkRules.video(from: try Fixtures.analysis(name))
        #expect(throws: AppError.self) { try result.get() }
        if case .failure(let error) = result {
            #expect(error.category == .playlistsAndChannels)
        }
    }

    @Test func rejectsLiveStream() throws {
        let result = LinkRules.video(from: try Fixtures.analysis("youtube-live"))
        if case .failure(let error) = result {
            #expect(error.category == .liveStream)
        } else {
            Issue.record("expected a live stream error")
        }
    }

    @Test func rejectsUpcomingStream() {
        let response = AnalysisResponse(kind: .video(VideoInfo(id: "x", title: "x", liveStatus: "is_upcoming", formats: [])))
        #expect(throws: AppError(.liveStream, details: "live_status: is_upcoming")) { try LinkRules.video(from: response).get() }
    }
}
