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
