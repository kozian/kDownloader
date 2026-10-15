import KDownloaderCore
import SwiftUI

extension ErrorCategory {
    var title: LocalizedStringKey {
        switch self {
        case .invalidLink: "Invalid link"
        case .siteNotSupported: "Site not supported"
        case .playlistsAndChannels: "Playlists and channels are not supported"
        case .liveStream: "Live streams are not supported"
        case .videoUnavailable: "Video unavailable or removed"
        case .privateVideo: "Private video"
        case .signInRequired: "Sign-in required"
        case .membersOnly: "Members only"
        case .notAvailableInRegion: "Not available in your region"
        case .rateLimited: "Site is rate limiting requests"
        case .noNetwork: "No network connection"
        case .notEnoughDiskSpace: "Not enough disk space"
        case .cannotWriteDestination: "Cannot write to the destination folder"
        case .processingFailed: "Video processing failed"
        case .unknown: "Unknown error"
        case .cookiesUnavailable: "Cannot access browser cookies"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .invalidLink: "Check the link and try again."
        case .siteNotSupported: "Videos from this site cannot be downloaded."
        case .playlistsAndChannels: "Paste a link to a single video."
        case .liveStream: "Try again after the stream has ended."
        case .videoUnavailable: "The video may have been deleted or made unavailable."
        case .privateVideo: "Only people the owner shared it with can watch this video."
        case .signInRequired: "The site requires signing in to watch this video."
        case .membersOnly: "This video is available only to channel members or subscribers."
        case .notAvailableInRegion: "The owner has not made this video available in your region."
        case .rateLimited: "The site has temporarily limited requests. Wait a while and try again."
        case .noNetwork: "Check your internet connection and try again."
        case .notEnoughDiskSpace: "Free up some space or choose another folder."
        case .cannotWriteDestination: "Choose another folder or check its permissions."
        case .processingFailed: "The downloaded streams could not be processed."
        case .unknown: "Something went wrong. The log has the details."
        case .cookiesUnavailable: "kDownloader could not read cookies from the selected browser."
        }
    }

    /// Whether trying the same operation again can help.
    var isRetryable: Bool {
        switch self {
        case .invalidLink, .siteNotSupported, .playlistsAndChannels: false
        default: true
        }
    }
}
