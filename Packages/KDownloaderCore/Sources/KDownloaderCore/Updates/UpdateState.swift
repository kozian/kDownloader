import Foundation

/// What the app remembers about yt-dlp update checks.
public struct UpdateState: @unchecked Sendable {
    // UserDefaults is thread-safe; it is not marked Sendable on macOS 14.
    private let defaults: UserDefaults
    static let lastCheckKey = "ytDlpLastCheck"
    static let latestKey = "ytDlpLatestVersion"
    static let dismissedKey = "ytDlpDismissedVersion"
    static let checkInterval: TimeInterval = 24 * 60 * 60

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var lastCheck: Date? {
        defaults.object(forKey: Self.lastCheckKey) as? Date
    }

    /// The newest release seen by the last successful check.
    public var latestVersion: YtDlpVersion? {
        defaults.string(forKey: Self.latestKey).flatMap(YtDlpVersion.init)
    }

    public var dismissedVersion: YtDlpVersion? {
        defaults.string(forKey: Self.dismissedKey).flatMap(YtDlpVersion.init)
    }

    /// The automatic check runs at most once every 24 hours.
    public func isCheckDue(now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= Self.checkInterval || now < lastCheck
    }

    public func recordCheck(latest: YtDlpVersion, at date: Date) {
        defaults.set(date, forKey: Self.lastCheckKey)
        defaults.set(latest.description, forKey: Self.latestKey)
    }

    /// Records the time of a failed check so the next automatic one waits a day too.
    public func recordFailedCheck(at date: Date) {
        defaults.set(date, forKey: Self.lastCheckKey)
    }

    /// "Not Now" in the main window.
    public func dismiss(_ version: YtDlpVersion) {
        defaults.set(version.description, forKey: Self.dismissedKey)
    }

    /// A newer release than the active yt-dlp is known.
    public func availableUpdate(active: YtDlpVersion) -> YtDlpVersion? {
        guard let latestVersion, latestVersion > active else { return nil }
        return latestVersion
    }

    /// The main window shows the notice unless the user dismissed this version.
    public func showsNotice(active: YtDlpVersion) -> Bool {
        guard let available = availableUpdate(active: active) else { return false }
        return available != dismissedVersion
    }
}
