import KDownloaderCore
import SwiftUI

extension UpdateError {
    var message: LocalizedStringKey {
        switch self {
        case .network: "Could not reach GitHub. Check your internet connection and try again."
        case .unexpectedResponse: "GitHub sent an unexpected answer. Try again later."
        case .damagedDownload: "The download is damaged. Try again later."
        case .invalidUpdate: "The new version does not work on this Mac. The current one stays in use."
        case .installFailed: "The update could not be installed. The current version stays in use."
        case .busy: "Available after the current download."
        }
    }
}

/// The only trace of updates in the main window: an icon between the link field
/// and "Analyze". The tooltip names the version; a click opens Settings, where
/// everything about updates happens.
struct UpdateIcon: View {
    let updates: UpdatesModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let text = tooltip {
            Button {
                openSettings()
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .help(text)
            .accessibilityLabel(text)
        }
    }

    private var tooltip: String? {
        if updates.isInstalling {
            return String(localized: "Updating yt-dlp… Open Settings for details")
        }
        if let version = updates.availableVersion {
            return String(localized: "yt-dlp \(version.description) is available — open Settings to install")
        }
        return nil
    }
}
