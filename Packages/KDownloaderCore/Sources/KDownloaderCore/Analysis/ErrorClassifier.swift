import Foundation

/// Maps yt-dlp error output to a user-facing category.
public enum ErrorClassifier {
    /// Rules are checked in order; the first match wins. More specific
    /// messages come first, e.g. "Private video. Sign in…" before "Sign in".
    /// Regex is not Sendable, so the list is built on each call; it is short.
    static var rules: [(ErrorCategory, Regex<Substring>)] { [
        (.cookiesUnavailable, /(?i)cookies database|Cookies\.binarycookies|failed to load cookies|cannot (?:extract|decrypt) cookies/),
        (.liveStream, /(?i)live event will begin|Premieres in|is_live|currently live|live stream (?:is|has) not (?:started|begun)/),
        (.rateLimited, /(?i)HTTP Error 429|Too Many Requests|confirm you.re not a bot|rate.?limit/),
        (.noNetwork, /(?i)nodename nor servname|Could not resolve host|Network is unreachable|No route to host|Connection refused|Connection reset|timed out|\[Errno (?:8|50|51|54|60|61|65)\]|Internet connection appears to be offline/),
        (.notEnoughDiskSpace, /(?i)No space left on device|\[Errno 28\]|disk quota exceeded/),
        (.cannotWriteDestination, /(?i)Permission denied|\[Errno (?:13|30)\]|Read-only file system|unable to (?:create directory|open for writing)/),
        (.siteNotSupported, /(?i)Unsupported URL/),
        (.privateVideo, /(?i)Private video|This video is private|video is set to private/),
        (.membersOnly, /(?i)members.only|Join this channel|channel.s members|Music Premium|premium.only/),
        (.signInRequired, /(?i)Sign in to confirm your age|age.restricted|Sign in|log(?:ged)?.?in|registered users|account credentials|authentication required/),
        (.notAvailableInRegion, /(?i)available in your country|available from your location|geo.?restrict|blocked it in your country/),
        (.videoUnavailable, /(?i)Video unavailable|video is unavailable|video has been removed|no longer available|does not exist|HTTP Error 404|\bNot found\b|account (?:has been )?terminated/),
        (.processingFailed, /(?i)Postprocessing|Conversion failed|ffmpeg|ffprobe|Merging .* failed/),
    ] }

    /// Classifies the stderr output of a failed yt-dlp run.
    public static func classify(_ standardError: [String]) -> AppError {
        let errorLines = standardError.filter { $0.hasPrefix("ERROR:") }
        let message = errorLines.last ?? standardError.last(where: { !$0.isEmpty })
        guard let message else {
            return AppError(.unknown)
        }
        for (category, pattern) in rules where message.contains(pattern) {
            return AppError(category, details: message)
        }
        return AppError(.unknown, details: message)
    }
}
