import Foundation

/// Container of the downloaded file.
public enum Container: String, Sendable, Equatable {
    case mp4, mkv, m4a
}

/// What exactly to ask yt-dlp for.
public struct DownloadPlan: Sendable, Equatable {
    /// Concrete format IDs, e.g. `299+140`.
    public var formatSelector: String
    public var container: Container
    /// Audio has to be converted to AAC (`-x --audio-format m4a`).
    public var extractsAudio: Bool
    /// The video stream is HEVC tagged `hev1`, which QuickTime only plays when
    /// re-tagged as `hvc1`.
    public var retagsHEVC: Bool
    /// Sum of the known stream sizes in bytes.
    public var estimatedSize: Int64?

    public init(
        formatSelector: String,
        container: Container,
        extractsAudio: Bool = false,
        retagsHEVC: Bool = false,
        estimatedSize: Int64? = nil
    ) {
        self.formatSelector = formatSelector
        self.container = container
        self.extractsAudio = extractsAudio
        self.retagsHEVC = retagsHEVC
        self.estimatedSize = estimatedSize
    }

    /// yt-dlp options that produce this plan.
    public var arguments: [String] {
        var arguments = ["-f", formatSelector]
        if extractsAudio {
            arguments += ["-x", "--audio-format", "m4a"]
        } else if formatSelector.contains("+") {
            arguments += ["--merge-output-format", container.rawValue]
            if retagsHEVC {
                arguments += ["--postprocessor-args", "Merger+ffmpeg_o:-tag:v hvc1"]
            }
        } else if container != .m4a {
            arguments += ["--remux-video", container.rawValue]
        }
        return arguments
    }
}
