import Foundation

/// What is needed to play a result that does not have the best compatibility with Mac.
public enum PlaybackRequirement: Hashable, Sendable {
    /// The result is MKV, which QuickTime does not open.
    case thirdPartyPlayer
    /// AV1 is decoded only by the hardware decoder of M3 and later chips.
    case m3OrLater
}

/// A group of the full Video menu: one video format, one entry per resolution.
public struct VideoFormatGroup: Identifiable, Equatable, Sendable {
    /// "H.264", "VP9", … or the raw codec name.
    public var codec: String
    public var container: Container
    /// `nil`: best compatibility with Mac.
    public var requirement: PlaybackRequirement?
    /// Best first.
    public var formats: [MediaFormat]
    public var id: String { "\(codec)-\(container.rawValue)" }
}

/// A group of the full Audio menu: one audio codec, one entry per language and bitrate.
public struct AudioFormatGroup: Identifiable, Equatable, Sendable {
    public var codec: String
    /// "M4A" for AAC; other codecs have no own container in the result.
    public var containerName: String?
    public var requirement: PlaybackRequirement?
    public var tracks: [AudioTrack]
    public var id: String { codec }
}

/// How well the selected combination plays on a Mac.
public enum Compatibility: Equatable, Sendable {
    case best
    /// The codecs that make the result MKV, e.g. ["VP9", "Opus"].
    case thirdPartyPlayer(codecs: [String])
    case m3OrLater
}

extension FormatCatalog {
    /// The full Video menu grouped by format, best compatibility first.
    public var videoGroups: [VideoFormatGroup] {
        var groups: [String: VideoFormatGroup] = [:]
        var order: [String] = []
        for format in allVideoFormats {
            let codec = Codecs.family(format.videoCodec)
            // Paired with AAC, or with its own audio for combined formats.
            let codecs = [format.videoCodec, format.hasAudio ? format.audioCodec : "mp4a"]
            let container: Container = codecs.allSatisfy(Codecs.fitsMP4) ? .mp4 : .mkv
            let requirement: PlaybackRequirement? = container == .mkv ? .thirdPartyPlayer
                : Codecs.isAV1(format.videoCodec) ? .m3OrLater
                : Codecs.isQuickTimeVideo(format.videoCodec) && (!format.hasAudio || Codecs.isAAC(format.audioCodec)) ? nil
                : .thirdPartyPlayer
            let key = "\(codec)-\(container.rawValue)"
            if groups[key] == nil {
                groups[key] = VideoFormatGroup(codec: codec, container: container, requirement: requirement, formats: [])
                order.append(key)
            }
            // allVideoFormats is sorted best first, so the first entry per resolution wins.
            let resolution = Self.resolutionKey(format)
            if !groups[key]!.formats.contains(where: { Self.resolutionKey($0) == resolution }) {
                groups[key]!.formats.append(format)
            }
        }
        return order.compactMap { groups[$0] }.sorted { a, b in
            if (a.requirement == nil) != (b.requirement == nil) { return a.requirement == nil }
            return (a.formats.first?.height ?? 0) > (b.formats.first?.height ?? 0)
        }
    }

    /// The full Audio menu grouped by codec, AAC first. Audio formats with an
    /// unknown codec are listed only when no other audio exists.
    public var audioGroups: [AudioFormatGroup] {
        let known = allAudioTracks.filter { $0.format.audioCodec != nil }
        let tracks = known.isEmpty ? allAudioTracks : known
        var groups: [String: AudioFormatGroup] = [:]
        var order: [String] = []
        for track in tracks {
            let codec = Codecs.family(track.format.audioCodec)
            let isAAC = Codecs.isAAC(track.format.audioCodec)
            if groups[codec] == nil {
                groups[codec] = AudioFormatGroup(
                    codec: codec,
                    containerName: isAAC ? "M4A" : nil,
                    requirement: isAAC ? nil : .thirdPartyPlayer,
                    tracks: []
                )
                order.append(codec)
            }
            // One entry per language and stream: the regular variant wins over DRC.
            let key = Self.audioKey(track.format)
            if !groups[codec]!.tracks.contains(where: { Self.audioKey($0.format) == key }) {
                groups[codec]!.tracks.append(track)
            }
        }
        return order.compactMap { groups[$0] }.sorted { a, b in
            (a.requirement == nil) && (b.requirement != nil)
        }
    }

    /// Compatibility of the result for the two menu values.
    public func compatibility(video: VideoChoice, audio: AudioChoice) -> Compatibility {
        guard video != .none else { return .best }  // audio only is always M4A/AAC
        guard let plan = plan(video: video, audio: audio), let videoFormat = videoFormat(for: video) else { return .best }
        if plan.container == .mkv {
            var codecs: [String] = []
            if !Codecs.fitsMP4(videoFormat.videoCodec) { codecs.append(Codecs.family(videoFormat.videoCodec)) }
            let audioCodec: String? = videoFormat.hasAudio ? videoFormat.audioCodec
                : { if case .track(let id) = audio { return allAudioTracks.first { $0.id == id }?.format.audioCodec } else { return nil } }()
            if let audioCodec, !Codecs.fitsMP4(audioCodec) { codecs.append(Codecs.family(audioCodec)) }
            return .thirdPartyPlayer(codecs: codecs)
        }
        if Codecs.isAV1(videoFormat.videoCodec) { return .m3OrLater }
        return .best
    }

    /// Which menu lowers compatibility and why. `nil` for a menu whose choice is
    /// fine; both `nil` for the best compatibility (and for audio only, which is
    /// always M4A/AAC).
    public func compatibilityIssues(video: VideoChoice, audio: AudioChoice) -> (video: Compatibility?, audio: Compatibility?) {
        guard video != .none, let videoFormat = videoFormat(for: video) else { return (nil, nil) }
        var videoIssue: Compatibility?
        if !Codecs.fitsMP4(videoFormat.videoCodec) {
            videoIssue = .thirdPartyPlayer(codecs: [Codecs.family(videoFormat.videoCodec)])
        } else if videoFormat.hasAudio, !Codecs.fitsMP4(videoFormat.audioCodec) {
            // A combined format brings its own incompatible audio.
            videoIssue = .thirdPartyPlayer(codecs: [Codecs.family(videoFormat.audioCodec)])
        } else if Codecs.isAV1(videoFormat.videoCodec) {
            videoIssue = .m3OrLater
        }
        var audioIssue: Compatibility?
        if !videoFormat.hasAudio, case .track(let id) = audio,
           let track = allAudioTracks.first(where: { $0.id == id }), !Codecs.fitsMP4(track.format.audioCodec) {
            audioIssue = .thirdPartyPlayer(codecs: [Codecs.family(track.format.audioCodec)])
        }
        return (videoIssue, audioIssue)
    }

    /// Frame rates up to 30 count as one: entries show the rate only above 30, so
    /// 144p at 15 and 30 fps would look like duplicates.
    static func resolutionKey(_ format: MediaFormat) -> String {
        let fps = Int((format.fps ?? 0).rounded())
        return "\(format.height ?? 0)p\(fps > 30 ? fps : 30)"
    }

    static func audioKey(_ format: MediaFormat) -> String {
        var id = format.id
        if id.hasSuffix("-drc") { id.removeLast(4) }
        return "\(format.language ?? "")|\(id)"
    }
}

extension Codecs {
    /// Display name of a codec family.
    static func family(_ codec: String?) -> String {
        guard let codec = codec?.lowercased() else { return "?" }
        let names: [(String, String)] = [
            ("avc", "H.264"), ("hvc1", "HEVC"), ("hev1", "HEVC"), ("vp09", "VP9"), ("vp9", "VP9"), ("vp8", "VP8"),
            ("av01", "AV1"), ("mp4a", "AAC"), ("opus", "Opus"), ("vorbis", "Vorbis"), ("mp3", "MP3"), ("flac", "FLAC"),
            ("ac-3", "AC-3"), ("ec-3", "E-AC-3"),
        ]
        return names.first { codec.hasPrefix($0.0) }?.1 ?? codec
    }
}
