import KDownloaderCore
import SwiftUI

/// A failed operation: the category, what to do, and the original message.
struct ErrorView: View {
    let error: AppError
    var retry: (() -> Void)?
    /// The browser cookies were read from; picks the Safari-specific message.
    var cookieBrowser: CookieBrowser?
    @Environment(\.openLog) private var openLog
    @State private var showsDetails = false

    private var isSafariCookieAccess: Bool {
        error.category == .cookiesUnavailable && cookieBrowser?.id == "safari"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(isSafariCookieAccess ? "Cannot access Safari cookies" : error.category.title)
                    .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text(isSafariCookieAccess
                 ? "Give kDownloader Full Disk Access in System Settings → Privacy & Security, then try again."
                 : error.category.explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let details = error.details {
                DisclosureGroup("Details", isExpanded: $showsDetails) {
                    Text(details)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .font(.callout)
            }

            HStack {
                if isSafariCookieAccess {
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(PrivacySettings.fullDiskAccess)
                    }
                }
                if let retry, error.category.isRetryable {
                    Button("Retry", action: retry)
                }
                Button("Open Log") { openLog() }
                    .buttonStyle(.link)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Opens the log window.
struct OpenLogAction {
    let action: @MainActor () -> Void

    @MainActor
    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    @Entry var openLog = OpenLogAction {}
}
