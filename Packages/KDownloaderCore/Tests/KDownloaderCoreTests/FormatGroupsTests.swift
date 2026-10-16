import Foundation
import Testing
@testable import KDownloaderCore

struct FormatGroupsTests {
    private func catalog(_ fixture: String) throws -> FormatCatalog {
        FormatCatalog(formats: try Fixtures.video(fixture).formats)
    }

    @Test func groupsBigBuckBunnyByFormat() throws {
        let groups = try catalog("youtube-big-buck-bunny").videoGroups
        #expect(groups.map(\.id) == ["H.264-mp4", "VP9-mkv", "AV1-mp4"])
        #expect(groups.map(\.requirement) == [nil, .thirdPartyPlayer, .m3OrLater])
    }

    @Test func oneEntryPerResolutionPreferringDirectStreams() throws {
        let h264 = try #require(try catalog("youtube-big-buck-bunny").videoGroups.first)
        #expect(h264.formats.map { FormatCatalog.resolutionKey($0) } == ["1080p60", "720p60", "480p30", "360p30", "240p30", "144p30"])
        // 299 (https) wins over 312 (HLS) at 1080p.
        #expect(h264.formats.first?.id == "299")
        #expect(h264.formats.allSatisfy { $0.transferProtocol == "https" })
    }

    @Test func combinedFormatsFormOneGroup() throws {
        let groups = try catalog("hls-combined-formats").videoGroups
        #expect(groups.map(\.id) == ["H.264-mp4"])
        #expect(groups.first?.formats.count == 5)
    }

    @Test func audioGroupsDropDRCAndUnknownHLS() throws {
        let groups = try catalog("youtube-big-buck-bunny").audioGroups
        #expect(groups.map(\.codec) == ["AAC", "Opus"])
        #expect(groups.first?.containerName == "M4A")
        #expect(groups.first?.tracks.map(\.id) == ["140", "139"])
        #expect(groups.last?.requirement == .thirdPartyPlayer)
        #expect(groups.last?.tracks.map(\.id) == ["251", "250", "249"])
    }

    @Test func multiLanguageAudioHasOneEntryPerLanguageAndStream() throws {
        let aac = try #require(try catalog("youtube-multi-language").audioGroups.first)
        #expect(aac.codec == "AAC")
        let keys = aac.tracks.map { FormatCatalog.audioKey($0.format) }
        #expect(Set(keys).count == keys.count)
        #expect(aac.tracks.first?.isOriginal == true)
    }

    @Test func compatibilityOfSelections() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        #expect(catalog.compatibility(video: .bestCompatible, audio: .track("140")) == .best)
        #expect(catalog.compatibility(video: .format("315"), audio: .track("251")) == .thirdPartyPlayer(codecs: ["VP9", "Opus"]))
        #expect(catalog.compatibility(video: .format("299"), audio: .track("251")) == .thirdPartyPlayer(codecs: ["Opus"]))
        #expect(catalog.compatibility(video: .format("401"), audio: .track("140")) == .m3OrLater)
        #expect(catalog.compatibility(video: .none, audio: .track("251")) == .best)
    }

    @Test func issuesPointAtTheMenuThatLowersCompatibility() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        func issues(_ video: VideoChoice, _ audio: AudioChoice) -> [Compatibility?] {
            let result = catalog.compatibilityIssues(video: video, audio: audio)
            return [result.video, result.audio]
        }
        #expect(issues(.bestCompatible, .track("140")) == [nil, nil])
        #expect(issues(.format("299"), .track("251")) == [nil, .thirdPartyPlayer(codecs: ["Opus"])])
        #expect(issues(.format("315"), .track("251")) == [.thirdPartyPlayer(codecs: ["VP9"]), .thirdPartyPlayer(codecs: ["Opus"])])
        #expect(issues(.format("315"), .track("140")) == [.thirdPartyPlayer(codecs: ["VP9"]), nil])
        #expect(issues(.format("401"), .track("140")) == [.m3OrLater, nil])
        #expect(issues(.none, .track("251")) == [nil, nil])
    }

    @Test func lowFrameRatesShareOneEntry() throws {
        let vp9 = try #require(try catalog("youtube-big-buck-bunny").videoGroups.first { $0.codec == "VP9" })
        let heights = vp9.formats.map { $0.height ?? 0 }
        #expect(Set(heights).count == heights.count)
        // 278 (https, 30 fps) wins over 602 (HLS, 15 fps) at 144p.
        #expect(vp9.formats.last?.id == "278")
    }
}
