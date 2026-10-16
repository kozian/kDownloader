import AppKit
import KDownloaderCore
import SwiftUI

extension CookieBrowser {
    /// Supported browsers installed on this Mac.
    static var installedOnThisMac: [CookieBrowser] {
        installed { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }
}

/// Asked when a video needs sign-in and no browser has been chosen yet.
struct BrowserChoiceSheet: View {
    let choose: (CookieBrowserChoice) -> Void
    private let browsers = CookieBrowser.installedOnThisMac

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use cookies from your browser?")
                .font(.headline)
            Text("This video needs you to be signed in. kDownloader can use the cookies of a browser where you are signed in to the site. Cookies are read only for this download and are never stored.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if browsers.isEmpty {
                Text("No supported browser is installed.")
                    .foregroundStyle(.secondary)
            }
            ForEach(browsers) { browser in
                Button {
                    choose(.browser(browser))
                } label: {
                    HStack {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(browser.displayName)
                        Spacer()
                    }
                }
            }
            HStack {
                Text("You can change this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Don't Use") { choose(.declined) }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

/// Settings window: "Show all formats" and the browser to read cookies from.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var choice: CookieBrowserChoice = .notChosen

    var body: some View {
        @Bindable var app = app
        // Every row: label on the left, control with its explanation on the right.
        Form {
            LabeledContent("Formats:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show all formats", isOn: $app.showAllFormats)
                    SettingNote("Lists every format in the Video and Audio menus, including ones that may not open in QuickTime.")
                }
            }
            .padding(.bottom, 8)
            LabeledContent("Cookies from browser:") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Cookies from browser:", selection: $choice) {
                        Text("Ask when needed").tag(CookieBrowserChoice.notChosen)
                        ForEach(CookieBrowser.installedOnThisMac) { browser in
                            Text(browser.displayName).tag(CookieBrowserChoice.browser(browser))
                        }
                        Text("Don't use").tag(CookieBrowserChoice.declined)
                    }
                    .labelsHidden()
                    .fixedSize()
                    SettingNote("Used only when a video needs signing in, after a first attempt without cookies.")
                }
            }
            .padding(.bottom, 8)
            if let updates = app.updates {
                LabeledContent("yt-dlp:") {
                    YtDlpSettings(app: app, updates: updates)
                }
            }
        }
        .padding(20)
        .frame(width: 500)
        .onAppear { choice = app.settings.cookieBrowser }
        .onChange(of: choice) { _, newValue in app.settings.setCookieBrowser(newValue) }
    }
}

enum PrivacySettings {
    static let fullDiskAccess = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}

/// The secondary explanation under a setting.
private struct SettingNote: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The "yt-dlp" row of Settings: version, source, update actions.
private struct YtDlpSettings: View {
    let app: AppModel
    let updates: UpdatesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let active = app.activeYtDlp {
                Text(active.source == .updated
                     ? "\(active.version.description) (updated)"
                     : "\(active.version.description) (bundled version)")
            }
            status
            // Side by side when they fit; Russian labels are longer and stack.
            ViewThatFits(in: .horizontal) {
                HStack { buttons }
                VStack(alignment: .leading) { buttons }
            }
            if updates.availableVersion != nil, !updates.canInstall, !updates.isInstalling {
                SettingNote("Available after the current download.")
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if updates.availableVersion != nil {
            Button("Install", action: updates.install)
                .disabled(!updates.canInstall)
        }
        Button("Check for Updates", action: updates.checkNow)
            .disabled(updates.isInstalling || updates.status == .checking)
        if app.activeYtDlp?.source == .updated {
            Button("Use Bundled Version", action: updates.useBundledVersion)
                .disabled(updates.isInstalling || app.operationInProgress)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updates.status {
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .installing(let progress):
            ProgressView(value: progress) { Text("Updating yt-dlp…") }
                .frame(maxWidth: 260)
        case .failed(let error):
            Text(error.message)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case .upToDate where updates.availableVersion == nil:
            Label("yt-dlp is up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        default:
            if let version = updates.availableVersion {
                Text("Version \(version.description) is available").foregroundStyle(.tint)
            } else if let lastCheck = updates.lastCheck {
                Text("Last checked \(lastCheck.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
