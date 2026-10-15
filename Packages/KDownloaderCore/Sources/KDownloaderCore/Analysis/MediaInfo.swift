import Foundation

/// A single video as reported by `yt-dlp -J`.
public struct VideoInfo: Sendable, Equatable {
    public var id: String
    public var title: String
    /// Channel name, or the uploader when the site has no channels.
    public var author: String?
    public var duration: TimeInterval?
    public var thumbnail: URL?
    public var webpageURL: URL?
    public var liveStatus: String?
    public var formats: [MediaFormat]

    public init(
        id: String,
        title: String,
        author: String? = nil,
        duration: TimeInterval? = nil,
        thumbnail: URL? = nil,
        webpageURL: URL? = nil,
        liveStatus: String? = nil,
        formats: [MediaFormat]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.thumbnail = thumbnail
        self.webpageURL = webpageURL
        self.liveStatus = liveStatus
        self.formats = formats
    }
}

/// One downloadable format of a video.
public struct MediaFormat: Sendable, Equatable, Identifiable {
    public var id: String
    public var note: String?
    public var fileExtension: String
    public var transferProtocol: String?
    /// Codec of the video stream: `nil` if the site did not say, `"none"` for audio-only formats.
    public var videoCodec: String?
    /// Codec of the audio stream: `nil` if the site did not say, `"none"` for video-only formats.
    public var audioCodec: String?
    public var width: Int?
    public var height: Int?
    public var fps: Double?
    /// Total bitrate in kbit/s.
    public var bitrate: Double?
    /// Exact or approximate size in bytes.
    public var fileSize: Int64?
    /// Language of the audio, e.g. `en-US`, when the site reports it.
    public var language: String?
    /// Higher is preferred; YouTube marks the original track with 10.
    public var languagePreference: Int?

    public init(
        id: String,
        note: String? = nil,
        fileExtension: String,
        transferProtocol: String? = nil,
        videoCodec: String?,
        audioCodec: String?,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        bitrate: Double? = nil,
        fileSize: Int64? = nil,
        language: String? = nil,
        languagePreference: Int? = nil
    ) {
        self.id = id
        self.note = note
        self.fileExtension = fileExtension
        self.transferProtocol = transferProtocol
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
        self.fileSize = fileSize
        self.language = language
        self.languagePreference = languagePreference
    }

    public var hasVideo: Bool { videoCodec != "none" }
    public var hasAudio: Bool { audioCodec != "none" }
}

/// The raw top-level answer of `yt-dlp -J --flat-playlist`.
public struct AnalysisResponse: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case video(VideoInfo)
        /// A playlist, a channel or a channel tab.
        case playlist(id: String, title: String?)
    }

    public var kind: Kind

    public static func decode(_ data: Data) throws -> AnalysisResponse {
        let raw = try JSONDecoder().decode(RawInfo.self, from: data)
        if raw.type == "playlist" || raw.type == "multi_video" {
            return AnalysisResponse(kind: .playlist(id: raw.id, title: raw.title))
        }
        let video = VideoInfo(
            id: raw.id,
            title: raw.title ?? raw.id,
            author: raw.channel ?? raw.uploader,
            duration: raw.duration,
            thumbnail: raw.thumbnail.flatMap(URL.init(string:)),
            webpageURL: raw.webpageURL.flatMap(URL.init(string:)),
            liveStatus: raw.liveStatus ?? (raw.isLive == true ? "is_live" : nil),
            formats: (raw.formats ?? []).map(\.format)
        )
        return AnalysisResponse(kind: .video(video))
    }
}

private struct RawInfo: Decodable {
    var type: String?
    var id: String
    var title: String?
    var uploader: String?
    var channel: String?
    var duration: Double?
    var thumbnail: String?
    var webpageURL: String?
    var liveStatus: String?
    var isLive: Bool?
    var formats: [RawFormat]?

    enum CodingKeys: String, CodingKey {
        case type = "_type"
        case id, title, uploader, channel, duration, thumbnail, formats
        case webpageURL = "webpage_url"
        case liveStatus = "live_status"
        case isLive = "is_live"
    }
}

private struct RawFormat: Decodable {
    var formatID: String
    var formatNote: String?
    var ext: String?
    var `protocol`: String?
    var vcodec: String?
    var acodec: String?
    var width: Int?
    var height: Int?
    var fps: Double?
    var tbr: Double?
    var filesize: Int64?
    var filesizeApprox: Int64?
    var language: String?
    var languagePreference: Int?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case formatNote = "format_note"
        case ext, `protocol`, vcodec, acodec, width, height, fps, tbr, filesize, language
        case filesizeApprox = "filesize_approx"
        case languagePreference = "language_preference"
    }

    var format: MediaFormat {
        MediaFormat(
            id: formatID,
            note: formatNote,
            fileExtension: ext ?? "",
            transferProtocol: `protocol`,
            videoCodec: vcodec,
            audioCodec: acodec,
            width: width,
            height: height,
            fps: fps,
            bitrate: tbr,
            fileSize: filesize ?? filesizeApprox,
            language: language,
            languagePreference: languagePreference
        )
    }
}
