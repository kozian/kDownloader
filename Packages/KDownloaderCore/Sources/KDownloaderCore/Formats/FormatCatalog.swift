import Foundation

/// The value of the Video menu.
public enum VideoChoice: Hashable, Sendable {
    /// "Best compatible": the highest compatible height.
    case bestCompatible
    /// A compatible height.
    case height(Int)
    /// A concrete format from the full list.
    case format(String)
    /// "No video (audio only)".
    case none
}

/// The value of the Audio menu.
public enum AudioChoice: Hashable, Sendable {
    /// An audio-only format, by format ID.
    case track(String)
    /// "No audio" (full list only).
    case none
}

/// Notes shown next to a format.
public enum FormatBadge: Hashable, Sendable {
    case mayNotOpenInQuickTime
    case hardwareDecodingM3
}

/// An entry of the Audio menu.
public struct AudioTrack: Sendable, Equatable, Identifiable {
    public let format: MediaFormat
    /// Marked as the original language by the site, or the video has at most
    /// one language.
    public let isOriginal: Bool
    /// Audio-only downloads convert it to AAC.
    public var needsConversion: Bool { !Codecs.isAAC(format.audioCodec) }
    public var id: String { format.id }
    public var language: String? { format.language }
}

/// Builds the menu entries and download plans from the formats of a video.
public struct FormatCatalog: Sendable, Equatable {
    public struct VideoPreset: Sendable, Equatable, Identifiable {
        public var height: Int
        /// H.264/HEVC stream; may already contain AAC audio.
        public var video: MediaFormat
        public var id: Int { height }
    }

    /// Compatible heights, highest first.
    public let videoPresets: [VideoPreset]
    /// Compatible Audio menu: one AAC track per language (original first).
    /// Without any AAC track, the best track per language, to be converted.
    public let compatibleAudioTracks: [AudioTrack]
    /// Full Video menu, best first.
    public let allVideoFormats: [MediaFormat]
    /// Full Audio menu (audio-only formats), original language first, then best first.
    public let allAudioTracks: [AudioTrack]

    public init(formats: [MediaFormat]) {
        let audioOnly = formats.filter(\.isAudioOnly)
        let originalLanguage = Self.originalLanguage(of: audioOnly)
        // With at most one language there are no dubs: every track is the original
        // audio (YouTube marks "original" only when dubbed tracks exist).
        let singleLanguage = Set(audioOnly.map(\.language)).count <= 1
        func track(_ format: MediaFormat) -> AudioTrack {
            AudioTrack(
                format: format,
                isOriginal: singleLanguage || (originalLanguage != nil && format.language == originalLanguage)
            )
        }

        let aac = audioOnly.filter { Codecs.isAAC($0.audioCodec) }
        let compatibleAudio = Self.bestPerLanguage(aac.isEmpty ? audioOnly : aac, originalLanguage: originalLanguage)
        compatibleAudioTracks = compatibleAudio.map(track)
        allAudioTracks = audioOnly
            .sorted { a, b in
                let originalA = a.language == originalLanguage, originalB = b.language == originalLanguage
                if originalA != originalB { return originalA }
                return Self.audioPreference(a, b)
            }
            .map(track)

        var bestPerHeight: [Int: MediaFormat] = [:]
        for format in formats where format.hasVideo && Codecs.isQuickTimeVideo(format.videoCodec) {
            guard let height = format.height else { continue }
            if format.hasAudio {
                guard Codecs.isAAC(format.audioCodec) else { continue }
            } else {
                guard !aac.isEmpty else { continue }
            }
            if let current = bestPerHeight[height],
               !Self.videoScore(current).lexicographicallyPrecedes(Self.videoScore(format)) {
                continue
            }
            bestPerHeight[height] = format
        }
        videoPresets = bestPerHeight
            .map { VideoPreset(height: $0.key, video: $0.value) }
            .sorted { $0.height > $1.height }

        allVideoFormats = formats.filter(\.hasVideo).sorted(by: Self.videoPreference)
        hasCombinedAudioOnly = audioOnly.isEmpty && formats.contains { $0.hasVideo && $0.hasAudio }
        bestCombined = formats.filter { $0.hasVideo && $0.hasAudio }.sorted(by: Self.videoPreference).first
    }

    /// No audio-only formats exist, but audio can be extracted from a combined one.
    private let hasCombinedAudioOnly: Bool
    private let bestCombined: MediaFormat?

    // MARK: Defaults

    /// "Best compatible" when there is compatible video, otherwise audio only.
    public var defaultVideoChoice: VideoChoice {
        videoPresets.isEmpty ? .none : .bestCompatible
    }

    /// The original track, otherwise the first one.
    public func defaultAudioChoice(showAll: Bool) -> AudioChoice {
        let tracks = showAll ? allAudioTracks : compatibleAudioTracks
        guard let track = tracks.first(where: \.isOriginal) ?? tracks.first else { return .none }
        return .track(track.id)
    }

    /// Whether "No video (audio only)" can produce anything.
    public var supportsAudioOnly: Bool {
        !allAudioTracks.isEmpty || hasCombinedAudioOnly
    }

    // MARK: Plans

    /// The video format a menu value stands for.
    public func videoFormat(for choice: VideoChoice) -> MediaFormat? {
        switch choice {
        case .bestCompatible: videoPresets.first?.video
        case .height(let height): videoPresets.first { $0.height == height }?.video
        case .format(let id): allVideoFormats.first { $0.id == id }
        case .none: nil
        }
    }

    /// The Audio menu is disabled when the chosen video already has sound.
    public func audioMenuEnabled(for video: VideoChoice) -> Bool {
        videoFormat(for: video)?.hasAudio != true
    }

    /// What to download for the two menu values.
    public func plan(video: VideoChoice, audio: AudioChoice) -> DownloadPlan? {
        let audioFormat: MediaFormat? = switch audio {
        case .track(let id): (allAudioTracks.first { $0.id == id })?.format
        case .none: nil
        }

        guard video != .none else {
            if let audioFormat {
                if Codecs.isAAC(audioFormat.audioCodec) {
                    return DownloadPlan(formatSelector: audioFormat.id, container: .m4a, estimatedSize: audioFormat.fileSize)
                }
                return DownloadPlan(formatSelector: audioFormat.id, container: .m4a, extractsAudio: true)
            }
            if hasCombinedAudioOnly, let combined = bestCombined {
                return DownloadPlan(formatSelector: combined.id, container: .m4a, extractsAudio: true)
            }
            return nil
        }

        guard let videoFormat = videoFormat(for: video) else { return nil }
        switch video {
        case .bestCompatible, .height:
            // Compatible choices pair only with AAC.
            let aacTrack = audioFormat.flatMap { Codecs.isAAC($0.audioCodec) ? $0 : nil }
            if !videoFormat.hasAudio, aacTrack == nil { return nil }
            return Self.plan(video: videoFormat, audio: aacTrack)
        case .format, .none:
            return Self.plan(video: videoFormat, audio: audioFormat)
        }
    }

    /// Plan for a video format and an optional separate audio format. `audio`
    /// is ignored when the video format already carries audio.
    public static func plan(video: MediaFormat, audio: MediaFormat?) -> DownloadPlan {
        let audio = video.hasAudio ? nil : audio
        let codecs = [video.videoCodec] + (video.hasAudio ? [video.audioCodec] : []) + (audio.map { [$0.audioCodec] } ?? [])
        let container: Container = codecs.allSatisfy(Codecs.fitsMP4) ? .mp4 : .mkv
        if let audio {
            return DownloadPlan(
                formatSelector: "\(video.id)+\(audio.id)",
                container: container,
                retagsHEVC: container == .mp4 && Codecs.isHEV1(video.videoCodec),
                estimatedSize: sum(video.fileSize, audio.fileSize)
            )
        }
        return DownloadPlan(formatSelector: video.id, container: container, estimatedSize: video.fileSize)
    }

    public static func badges(for format: MediaFormat) -> Set<FormatBadge> {
        var badges: Set<FormatBadge> = []
        if format.hasVideo {
            if Codecs.isAV1(format.videoCodec) {
                badges.insert(.hardwareDecodingM3)
            } else if !Codecs.isQuickTimeVideo(format.videoCodec) {
                badges.insert(.mayNotOpenInQuickTime)
            }
        }
        if format.hasAudio, !Codecs.isAAC(format.audioCodec) {
            badges.insert(.mayNotOpenInQuickTime)
        }
        return badges
    }

    // MARK: Languages

    /// The language the site marks as original: the highest positive
    /// `language_preference`, or "original" in the format note.
    static func originalLanguage(of tracks: [MediaFormat]) -> String? {
        if let marked = tracks.first(where: { $0.note?.localizedCaseInsensitiveContains("original") == true && $0.language != nil }) {
            return marked.language
        }
        let preferred = tracks.filter { ($0.languagePreference ?? 0) > 0 && $0.language != nil }
        return preferred.max { ($0.languagePreference ?? 0) < ($1.languagePreference ?? 0) }?.language
    }

    /// One best track per language: original first, then by language code.
    /// Tracks without a language form one group.
    static func bestPerLanguage(_ tracks: [MediaFormat], originalLanguage: String?) -> [MediaFormat] {
        var best: [String: MediaFormat] = [:]
        for track in tracks {
            let key = track.language ?? ""
            if let current = best[key], audioPreference(current, track) { continue }
            best[key] = track
        }
        return best.values.sorted { a, b in
            let originalA = a.language == originalLanguage, originalB = b.language == originalLanguage
            if originalA != originalB { return originalA }
            return (a.language ?? "") < (b.language ?? "")
        }
    }

    // MARK: Ordering

    /// Direct downloads before HLS, then higher bitrate, then H.264.
    private static func videoScore(_ format: MediaFormat) -> [Double] {
        [
            format.isHLS ? 0 : 1,
            format.bitrate ?? 0,
            Codecs.isH264(format.videoCodec) ? 1 : 0,
        ]
    }

    private static func videoPreference(_ a: MediaFormat, _ b: MediaFormat) -> Bool {
        let heightA = a.height ?? 0, heightB = b.height ?? 0
        if heightA != heightB { return heightA > heightB }
        return videoScore(b).lexicographicallyPrecedes(videoScore(a))
    }

    /// Regular before DRC variants, direct before HLS, then higher bitrate.
    static func audioPreference(_ a: MediaFormat, _ b: MediaFormat) -> Bool {
        func score(_ format: MediaFormat) -> [Double] {
            [format.isDRC ? 0 : 1, format.isHLS ? 0 : 1, format.bitrate ?? 0]
        }
        return score(b).lexicographicallyPrecedes(score(a))
    }

    private static func sum(_ a: Int64?, _ b: Int64?) -> Int64? {
        guard let a, let b else { return nil }
        return a + b
    }
}

extension MediaFormat {
    var isAudioOnly: Bool { hasAudio && !hasVideo }
    var isHLS: Bool { transferProtocol?.hasPrefix("m3u8") == true }
    var isDRC: Bool { id.hasSuffix("-drc") || note?.contains("DRC") == true }
}

/// Codec checks by the RFC 6381 codec string prefix.
enum Codecs {
    static func isH264(_ codec: String?) -> Bool { has(codec, ["avc1", "avc3"]) }
    static func isHEV1(_ codec: String?) -> Bool { has(codec, ["hev1"]) }
    static func isAV1(_ codec: String?) -> Bool { has(codec, ["av01"]) }
    static func isAAC(_ codec: String?) -> Bool { has(codec, ["mp4a"]) }

    /// H.264 or HEVC: plays in QuickTime on every Apple Silicon Mac.
    static func isQuickTimeVideo(_ codec: String?) -> Bool { has(codec, ["avc1", "avc3", "hvc1", "hev1"]) }

    /// Can be stored in MP4 (the "none" of a missing stream fits trivially).
    static func fitsMP4(_ codec: String?) -> Bool {
        codec == "none" || has(codec, ["avc1", "avc3", "hvc1", "hev1", "av01", "mp4a"])
    }

    private static func has(_ codec: String?, _ prefixes: [String]) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        return prefixes.contains { codec.hasPrefix($0) }
    }
}
