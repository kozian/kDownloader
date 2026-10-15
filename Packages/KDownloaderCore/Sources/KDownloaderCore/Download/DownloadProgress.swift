import Foundation

/// Progress of a running download as shown in the window.
public struct DownloadProgress: Sendable, Equatable {
    public enum Stage: Sendable, Equatable {
        case preparing
        case downloadingVideo
        case downloadingAudio
        case processing
    }

    public var stage: Stage
    public var downloadedBytes: Int64?
    public var totalBytes: Int64?
    /// Bytes per second.
    public var speed: Double?
    public var remainingTime: TimeInterval?

    public init(
        stage: Stage,
        downloadedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        speed: Double? = nil,
        remainingTime: TimeInterval? = nil
    ) {
        self.stage = stage
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speed = speed
        self.remainingTime = remainingTime
    }

    /// 0…1, or `nil` when the size is unknown.
    public var fraction: Double? {
        guard let downloadedBytes, let totalBytes, totalBytes > 0 else { return nil }
        return min(Double(downloadedBytes) / Double(totalBytes), 1)
    }

    public static let preparing = DownloadProgress(stage: .preparing)
}

/// One meaningful line of yt-dlp download output.
public enum DownloadOutput: Sendable, Equatable {
    case progress(DownloadProgress)
    case processing
    case finishedFile(String)
}

/// Parses the stdout of `yt-dlp` started with `DownloadOutputParser.arguments`.
public enum DownloadOutputParser {
    static let progressPrefix = "KDPROGRESS "
    static let filePrefix = "KDFILE "

    /// Options that make yt-dlp print machine-readable progress and the final path.
    public static var arguments: [String] {
        [
            "--newline", "--progress", "--no-quiet",
            "--progress-template",
            "download:\(progressPrefix)%(progress.status)s %(progress.downloaded_bytes)s %(progress.total_bytes)s "
                + "%(progress.total_bytes_estimate)s %(progress.speed)s %(progress.eta)s %(info.vcodec)s",
            "--print", "after_move:\(filePrefix)%(filepath)s",
            "--no-simulate",
        ]
    }

    /// Post-processors that run after the streams are downloaded.
    static let processingPrefixes = [
        "[Merger]", "[ExtractAudio]", "[VideoRemuxer]", "[VideoConvertor]", "[FixupM3u8]",
        "[FixupM4a]", "[FixupStretched]", "[FixupDuplicateMoov]", "[FixupTimestamp]", "[FixupDuration]",
    ]

    public static func parse(_ line: String) -> DownloadOutput? {
        if line.hasPrefix(filePrefix) {
            return .finishedFile(String(line.dropFirst(filePrefix.count)))
        }
        if processingPrefixes.contains(where: line.hasPrefix) {
            return .processing
        }
        guard line.hasPrefix(progressPrefix) else { return nil }

        let fields = line.dropFirst(progressPrefix.count).split(separator: " ").map(String.init)
        guard fields.count >= 7 else { return nil }
        func number(_ index: Int) -> Double? { Double(fields[index]) }

        let stage: DownloadProgress.Stage = fields[6] == "none" ? .downloadingAudio : .downloadingVideo
        return .progress(DownloadProgress(
            stage: stage,
            downloadedBytes: number(1).map { Int64($0) },
            totalBytes: (number(2) ?? number(3)).map { Int64($0) },
            speed: number(4),
            remainingTime: number(5)
        ))
    }
}
