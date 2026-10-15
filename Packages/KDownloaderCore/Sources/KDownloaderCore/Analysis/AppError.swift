import Foundation

/// The fixed list of user-facing error categories.
public enum ErrorCategory: String, CaseIterable, Sendable {
    case invalidLink
    case siteNotSupported
    case playlistsAndChannels
    case liveStream
    case videoUnavailable
    case privateVideo
    case signInRequired
    case membersOnly
    case notAvailableInRegion
    case rateLimited
    case noNetwork
    case notEnoughDiskSpace
    case cannotWriteDestination
    case processingFailed
    case unknown
    /// Internal: browser cookies could not be read. Shown as its own message.
    case cookiesUnavailable

    /// Errors that a retry with browser cookies may fix.
    public var mayNeedCookies: Bool {
        switch self {
        case .signInRequired, .privateVideo, .membersOnly, .rateLimited: true
        default: false
        }
    }
}

/// An error shown to the user: a category plus the original tool output.
public struct AppError: Error, Equatable, Sendable {
    public var category: ErrorCategory
    /// The original message, shown untranslated under "Details".
    public var details: String?

    public init(_ category: ErrorCategory, details: String? = nil) {
        self.category = category
        self.details = details
    }
}
