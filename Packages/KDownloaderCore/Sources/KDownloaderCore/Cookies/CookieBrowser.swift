import Foundation

/// A browser yt-dlp can read cookies from on macOS.
public struct CookieBrowser: Hashable, Sendable, Identifiable {
    /// Name understood by `--cookies-from-browser`.
    public let id: String
    public let displayName: String
    public let bundleIdentifier: String

    public static let all: [CookieBrowser] = [
        CookieBrowser(id: "safari", displayName: "Safari", bundleIdentifier: "com.apple.Safari"),
        CookieBrowser(id: "chrome", displayName: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        CookieBrowser(id: "firefox", displayName: "Firefox", bundleIdentifier: "org.mozilla.firefox"),
        CookieBrowser(id: "brave", displayName: "Brave", bundleIdentifier: "com.brave.Browser"),
        CookieBrowser(id: "edge", displayName: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        CookieBrowser(id: "chromium", displayName: "Chromium", bundleIdentifier: "org.chromium.Chromium"),
        CookieBrowser(id: "opera", displayName: "Opera", bundleIdentifier: "com.operasoftware.Opera"),
        CookieBrowser(id: "vivaldi", displayName: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi"),
    ]

    public static func named(_ id: String) -> CookieBrowser? {
        all.first { $0.id == id }
    }

    /// Supported browsers for which `isInstalled` returns true, in a fixed order.
    public static func installed(isInstalled: (String) -> Bool) -> [CookieBrowser] {
        all.filter { isInstalled($0.bundleIdentifier) }
    }
}

/// The user's answer to "Which browser should cookies come from?".
public enum CookieBrowserChoice: Hashable, Sendable {
    /// Not asked yet: ask when cookies are needed.
    case notChosen
    /// "Don't use": never retry with cookies.
    case declined
    case browser(CookieBrowser)
}

extension AppSettings {
    static let cookieBrowserKey = "cookieBrowser"
    static let declinedValue = "none"

    public var cookieBrowser: CookieBrowserChoice {
        guard let value = defaults.string(forKey: Self.cookieBrowserKey) else { return .notChosen }
        if value == Self.declinedValue { return .declined }
        return CookieBrowser.named(value).map(CookieBrowserChoice.browser) ?? .notChosen
    }

    public func setCookieBrowser(_ choice: CookieBrowserChoice) {
        switch choice {
        case .notChosen: defaults.removeObject(forKey: Self.cookieBrowserKey)
        case .declined: defaults.set(Self.declinedValue, forKey: Self.cookieBrowserKey)
        case .browser(let browser): defaults.set(browser.id, forKey: Self.cookieBrowserKey)
        }
    }
}
