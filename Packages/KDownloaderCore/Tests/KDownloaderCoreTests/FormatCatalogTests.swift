import Foundation
import Testing
@testable import KDownloaderCore

struct FormatCatalogTests {
    private func catalog(_ fixture: String, filter: (MediaFormat) -> Bool = { _ in true }) throws -> FormatCatalog {
        FormatCatalog(formats: try Fixtures.video(fixture).formats.filter(filter))
    }

    // MARK: Compatible video

    @Test func compatibleHeightsSkipVP9AndAV1() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        #expect(catalog.videoPresets.map(\.height) == [1080, 720, 480, 360, 240, 144])
        #expect(catalog.defaultVideoChoice == .bestCompatible)
    }

    @Test func bestCompatiblePrefersDirectH264WithRegularAAC() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        let audio = catalog.defaultAudioChoice(showAll: false)
        #expect(audio == .track("140"))
        let best = try #require(catalog.plan(video: .bestCompatible, audio: audio))
        // 299 is the https H.264 1080p stream; 312 (HLS) has a higher bitrate but is not preferred.
        #expect(best.formatSelector == "299+140")
        #expect(best.container == .mp4)
        #expect(best.estimatedSize == Int64(257_619_653 + 10_271_496))
        #expect(best.arguments == ["-f", "299+140", "--merge-output-format", "mp4"])
        #expect(catalog.plan(video: .height(720), audio: audio)?.formatSelector == "298+140")
    }

    @Test func noCompatibleVideoDefaultsToAudioOnly() throws {
        let catalog = try catalog("youtube-big-buck-bunny") { !Codecs.isH264($0.videoCodec) }
        #expect(catalog.videoPresets.isEmpty)
        #expect(catalog.defaultVideoChoice == .none)
        #expect(catalog.plan(video: .bestCompatible, audio: .track("140")) == nil)
    }

    @Test func combinedFormatsBecomePresets() throws {
        let catalog = try catalog("hls-combined-formats")
        #expect(catalog.videoPresets.map(\.height) == [1080, 720, 480, 288, 184])
        #expect(catalog.compatibleAudioTracks.isEmpty)
        #expect(!catalog.audioMenuEnabled(for: .bestCompatible))
        let best = try #require(catalog.plan(video: .bestCompatible, audio: .none))
        #expect(best.arguments == ["-f", "1080", "--remux-video", "mp4"])
        // Audio is extracted from a combined stream.
        #expect(catalog.supportsAudioOnly)
        #expect(catalog.plan(video: .none, audio: .none)?.extractsAudio == true)
    }

    @Test func unknownCodecsAreNotCompatible() throws {
        let catalog = try catalog("archive-unknown-codecs")
        #expect(catalog.videoPresets.isEmpty)
        #expect(catalog.allVideoFormats.count == 3)
        #expect(FormatCatalog.badges(for: catalog.allVideoFormats[0]).contains(.mayNotOpenInQuickTime))
    }

    // MARK: Audio tracks and languages

    @Test func oneAACTrackPerLanguageWithOriginalFirst() throws {
        let catalog = try catalog("youtube-multi-language")
        let tracks = catalog.compatibleAudioTracks
        #expect(tracks.allSatisfy { Codecs.isAAC($0.format.audioCodec) })
        #expect(Set(tracks.compactMap(\.language)).count == tracks.count)
        #expect(tracks.count == 24)
        #expect(tracks.first?.language == "en-US")
        #expect(tracks.first?.isOriginal == true)
        #expect(tracks.dropFirst().allSatisfy { !$0.isOriginal })
    }

    @Test func originalTrackIsTheDefault() throws {
        let catalog = try catalog("youtube-multi-language")
        #expect(catalog.defaultAudioChoice(showAll: false) == .track("140-23"))
        let allDefault = catalog.defaultAudioChoice(showAll: true)
        guard case .track(let id) = allDefault else {
            Issue.record("expected a track")
            return
        }
        #expect(catalog.allAudioTracks.first { $0.id == id }?.language == "en-US")
    }

    @Test func languageChoiceAppliesToVideoAndAudioOnly() throws {
        let catalog = try catalog("youtube-multi-language")
        let russian = try #require(catalog.compatibleAudioTracks.first { $0.language == "ru" })
        let video = try #require(catalog.plan(video: .bestCompatible, audio: .track(russian.id)))
        #expect(video.formatSelector.hasSuffix("+\(russian.id)"))
        #expect(catalog.plan(video: .none, audio: .track(russian.id)) == DownloadPlan(
            formatSelector: russian.id, container: .m4a, estimatedSize: russian.format.fileSize
        ))
    }

    @Test func tracksWithoutLanguageAreOriginal() throws {
        let catalog = try catalog("youtube-me-at-the-zoo")
        #expect(catalog.compatibleAudioTracks.map(\.id) == ["140"])
        #expect(catalog.compatibleAudioTracks.first?.language == nil)
        #expect(catalog.compatibleAudioTracks.first?.isOriginal == true)
        let allOriginal = catalog.allAudioTracks.allSatisfy(\.isOriginal)
        #expect(allOriginal)
    }

    @Test func singleLanguageIsOriginal() {
        // YouTube reports the video language on every track but marks "original" only with dubs.
        let formats = [
            MediaFormat(id: "140", fileExtension: "m4a", videoCodec: "none", audioCodec: "mp4a.40.2", bitrate: 129, language: "en", languagePreference: -1),
            MediaFormat(id: "251", fileExtension: "webm", videoCodec: "none", audioCodec: "opus", bitrate: 128, language: "en", languagePreference: -1),
        ]
        let catalog = FormatCatalog(formats: formats)
        #expect(catalog.compatibleAudioTracks.map(\.id) == ["140"])
        #expect(catalog.compatibleAudioTracks.first?.language == "en")
        #expect(catalog.compatibleAudioTracks.first?.isOriginal == true)
        #expect(catalog.defaultAudioChoice(showAll: false) == .track("140"))
    }

    @Test func originalFromLanguagePreference() {
        let tracks = [
            MediaFormat(id: "a", fileExtension: "m4a", videoCodec: "none", audioCodec: "mp4a.40.2", language: "de", languagePreference: -1),
            MediaFormat(id: "b", fileExtension: "m4a", videoCodec: "none", audioCodec: "mp4a.40.2", language: "fr", languagePreference: 10),
        ]
        #expect(FormatCatalog.originalLanguage(of: tracks) == "fr")
        #expect(FormatCatalog.originalLanguage(of: [tracks[0]]) == nil)
        let catalog = FormatCatalog(formats: [tracks[0]])
        #expect(catalog.defaultAudioChoice(showAll: false) == .track("a"))
    }

    // MARK: Audio only

    @Test func audioOnlyAACIsNotReencoded() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        let plan = try #require(catalog.plan(video: .none, audio: .track("140")))
        #expect(plan == DownloadPlan(formatSelector: "140", container: .m4a, estimatedSize: 10_271_496))
        #expect(plan.arguments == ["-f", "140"])
    }

    @Test func opusOnlyIsOfferedForConversion() throws {
        let catalog = try catalog("youtube-big-buck-bunny") { !Codecs.isAAC($0.audioCodec) }
        let track = try #require(catalog.compatibleAudioTracks.first)
        #expect(track.id == "251")
        #expect(track.needsConversion)
        #expect(catalog.videoPresets.isEmpty)
        let plan = try #require(catalog.plan(video: .none, audio: catalog.defaultAudioChoice(showAll: false)))
        #expect(plan.arguments == ["-f", "251", "-x", "--audio-format", "m4a"])
    }

    // MARK: All formats

    @Test func vp9AndOpusMergeIntoMKV() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        let plan = try #require(catalog.plan(video: .format("315"), audio: .track("251")))
        #expect(plan.formatSelector == "315+251")
        #expect(plan.container == .mkv)
        #expect(plan.arguments == ["-f", "315+251", "--merge-output-format", "mkv"])
    }

    @Test func av1AndAACStayMP4() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        #expect(catalog.plan(video: .format("401"), audio: .track("140"))?.container == .mp4)
        #expect(FormatCatalog.badges(for: try #require(catalog.videoFormat(for: .format("401")))) == [.hardwareDecodingM3])
    }

    @Test func videoWithoutAudio() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        #expect(catalog.plan(video: .format("299"), audio: .none) == DownloadPlan(
            formatSelector: "299", container: .mp4, estimatedSize: 257_619_653
        ))
    }

    @Test func badgesFlagIncompatibleCodecs() throws {
        let formats = try Fixtures.video("youtube-big-buck-bunny").formats
        func badges(_ id: String) throws -> Set<FormatBadge> {
            FormatCatalog.badges(for: try #require(formats.first { $0.id == id }))
        }
        #expect(try badges("315") == [.mayNotOpenInQuickTime])  // VP9
        #expect(try badges("251") == [.mayNotOpenInQuickTime])  // Opus
        #expect(try badges("299").isEmpty)                      // H.264
        #expect(try badges("140").isEmpty)                      // AAC
    }

    @Test func fullListsAreOrdered() throws {
        let catalog = try catalog("youtube-big-buck-bunny")
        #expect(catalog.allVideoFormats.first?.height == 2160)
        #expect(catalog.allAudioTracks.first?.id == "140")
        #expect(catalog.allAudioTracks.allSatisfy { !$0.format.hasVideo })
    }

    @Test func hev1IsRetaggedWhenMerging() {
        let hevc = MediaFormat(id: "v", fileExtension: "mp4", videoCodec: "hev1.1.6.L93.B0", audioCodec: "none", height: 1080, bitrate: 100)
        let aac = MediaFormat(id: "a", fileExtension: "m4a", videoCodec: "none", audioCodec: "mp4a.40.2", bitrate: 128)
        let plan = FormatCatalog(formats: [hevc, aac]).plan(video: .bestCompatible, audio: .track("a"))
        #expect(plan?.arguments == ["-f", "v+a", "--merge-output-format", "mp4", "--postprocessor-args", "Merger+ffmpeg_o:-tag:v hvc1"])
    }
}
