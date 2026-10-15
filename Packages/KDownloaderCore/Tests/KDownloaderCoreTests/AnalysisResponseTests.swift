import Foundation
import Testing
@testable import KDownloaderCore

struct AnalysisResponseTests {
    @Test func decodesYouTubeVideo() throws {
        let video = try Fixtures.video("youtube-me-at-the-zoo")
        #expect(video.id == "jNQXAC9IVRw")
        #expect(video.title == "Me at the zoo")
        #expect(video.author == "jawed")
        #expect(video.duration == 19)
        #expect(video.thumbnail != nil)
        #expect(video.liveStatus == "not_live")

        let audio = try #require(video.formats.first { $0.id == "140" })
        #expect(audio.hasAudio && !audio.hasVideo)
        #expect(audio.audioCodec == "mp4a.40.2")
        #expect(audio.fileSize == 309288)

        let videoOnly = try #require(video.formats.first { $0.id == "134" })
        #expect(videoOnly.hasVideo && !videoOnly.hasAudio)
        #expect(videoOnly.height == 240)
        #expect(videoOnly.transferProtocol == "https")
    }

    @Test func decodesCombinedFormats() throws {
        let video = try Fixtures.video("hls-combined-formats")
        let best = try #require(video.formats.first { $0.id == "1080" })
        #expect(best.hasVideo && best.hasAudio)
        #expect(best.videoCodec == "avc1.640028")
        #expect(best.audioCodec == "mp4a.40.2")
        #expect(video.author == nil)
    }

    @Test func keepsUnknownCodecsAsNil() throws {
        let video = try Fixtures.video("archive-unknown-codecs")
        let mp4 = try #require(video.formats.first { $0.fileExtension == "mp4" })
        #expect(mp4.videoCodec == nil && mp4.audioCodec == nil)
        #expect(mp4.hasVideo && mp4.hasAudio)
    }

    @Test func decodesVideoInsidePlaylistAsVideo() throws {
        let video = try Fixtures.video("youtube-video-in-playlist")
        #expect(video.id == "jNQXAC9IVRw")
    }

    @Test(arguments: ["youtube-playlist", "youtube-channel"])
    func decodesPlaylistLikeResults(name: String) throws {
        guard case .playlist = try Fixtures.analysis(name).kind else {
            Issue.record("expected a playlist for \(name)")
            return
        }
    }

    @Test func decodesLiveStatus() throws {
        #expect(try Fixtures.video("youtube-live").liveStatus == "is_live")
    }

    @Test func decodesAudioLanguages() throws {
        let video = try Fixtures.video("youtube-multi-language")
        let original = try #require(video.formats.first { $0.id == "140-23" })
        #expect(original.language == "en-US")
        #expect(original.languagePreference == 10)
        let russian = try #require(video.formats.first { $0.id == "140-14" })
        #expect(russian.language == "ru")
        #expect(russian.languagePreference == -1)
        #expect(try Fixtures.video("hls-combined-formats").formats.allSatisfy { $0.language == nil })
    }
}
